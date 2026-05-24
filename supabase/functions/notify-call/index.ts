// notify-call — Database Webhook target for INSERT on dm_calls (status='ringing').
// Reads caller display_name + callee FCM-tokens, sends data-only high-priority
// FCM push so app wakes up on lock-screen via fullScreenIntent.
//
// Trigger: pg_net.http_post in trigger `notify_call_on_dm_calls_insert`
// (siehe Migration calls_livestream_infrastructure_webhook).
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const ADMIN = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);

// FCM HTTP v1 OAuth2 token cache
let fcmAccessToken: string | null = null;
let fcmAccessTokenExp = 0;

interface CallRow {
  id: string;
  caller_id: string;
  callee_id: string;
  conversation_id: string;
  room_name: string;
  status: string;
}

function b64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

async function signJwtRS256(
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
  pem: string,
): Promise<string> {
  const headerB64 = b64url(new TextEncoder().encode(JSON.stringify(header)));
  const claimsB64 = b64url(new TextEncoder().encode(JSON.stringify(claims)));
  const unsigned = `${headerB64}.${claimsB64}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(pem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${b64url(new Uint8Array(sig))}`;
}

async function getFcmAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  private_key_id: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (fcmAccessToken && now < fcmAccessTokenExp - 60) return fcmAccessToken;
  const jwt = await signJwtRS256(
    { alg: 'RS256', typ: 'JWT', kid: serviceAccount.private_key_id },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.private_key,
  );
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error('FCM OAuth2 exchange failed: ' + JSON.stringify(data));
  }
  fcmAccessToken = data.access_token;
  fcmAccessTokenExp = now + (data.expires_in ?? 3600);
  return fcmAccessToken;
}

async function loadPushConfig() {
  const { data, error } = await ADMIN.rpc('get_push_config');
  if (error || !data) throw new Error('get_push_config failed: ' + (error?.message ?? ''));
  const cfg: Record<string, string> = {};
  for (const row of data as Array<{ key: string; value: string }>) {
    cfg[row.key] = row.value;
  }
  return cfg;
}

async function sendCallFcm(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  callerName: string,
  call: CallRow,
) {
  const payload = {
    message: {
      token: fcmToken,
      data: {
        type: 'incoming_call',
        call_id: call.id,
        room_name: call.room_name,
        caller_name: callerName,
        caller_id: call.caller_id,
        conversation_id: call.conversation_id,
        title: 'Eingehender Anruf',
        body: `${callerName} ruft dich an`,
      },
      android: {
        priority: 'HIGH',
        ttl: '45s',
      },
    },
  };
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    },
  );
  const text = await res.text();
  return { ok: res.ok, status: res.status, body: text };
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: { type?: string; record?: CallRow };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'bad_body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Database-Webhook payload shape: { type: 'INSERT', table: 'dm_calls', record: {...}, ... }
  const call = body.record;
  if (!call || call.status !== 'ringing') {
    return new Response(
      JSON.stringify({ skipped: true, reason: 'not_ringing_or_no_record' }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  }

  try {
    const cfg = await loadPushConfig();
    if (!cfg.fcm_project_id || !cfg.fcm_service_account_json) {
      return new Response(
        JSON.stringify({ error: 'fcm_not_configured' }),
        { status: 503, headers: { 'Content-Type': 'application/json' } },
      );
    }
    const serviceAccount =
      typeof cfg.fcm_service_account_json === 'string'
        ? JSON.parse(cfg.fcm_service_account_json)
        : cfg.fcm_service_account_json;

    // Caller display name
    const { data: caller } = await ADMIN
      .from('profiles')
      .select('display_name, name, nickname')
      .eq('id', call.caller_id)
      .maybeSingle();
    const callerName =
      (caller?.display_name as string | undefined) ??
      (caller?.name as string | undefined) ??
      (caller?.nickname as string | undefined) ??
      'Nachbar:in';

    // Callee FCM tokens
    const { data: tokens } = await ADMIN
      .from('fcm_tokens')
      .select('id, token')
      .eq('user_id', call.callee_id)
      .eq('active', true);
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: 'no_active_tokens' }),
        { headers: { 'Content-Type': 'application/json' } },
      );
    }

    const accessToken = await getFcmAccessToken(serviceAccount);

    let sent = 0;
    let failed = 0;
    const staleIds: string[] = [];
    const errors: string[] = [];
    await Promise.all(
      tokens.map(async (row: { id: string; token: string }) => {
        const r = await sendCallFcm(
          cfg.fcm_project_id,
          accessToken,
          row.token,
          callerName,
          call,
        );
        if (r.ok) {
          sent++;
        } else {
          failed++;
          if (r.status === 404 || r.body.includes('UNREGISTERED')) {
            staleIds.push(row.id);
          } else {
            errors.push(`HTTP ${r.status}: ${r.body.substring(0, 120)}`);
          }
        }
      }),
    );

    if (staleIds.length > 0) {
      await ADMIN
        .from('fcm_tokens')
        .update({ active: false })
        .in('id', staleIds);
    }

    return new Response(
      JSON.stringify({
        sent,
        failed,
        stale: staleIds.length,
        errors: errors.length > 0 ? errors.slice(0, 3) : undefined,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
