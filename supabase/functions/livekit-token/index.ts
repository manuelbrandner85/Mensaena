// LiveKit Token Edge Function v8 — nutzt public.get_livekit_creds()-RPC
// (SECURITY DEFINER) statt direktem private-Schema-Zugriff (REST API
// exposed 'private' nicht). Fallback: Env-Secrets.

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const ANON_KEY     = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

let cached: { url: string; key: string; secret: string } | null = null;

async function loadCreds(): Promise<{ url: string; key: string; secret: string }> {
  if (cached) return cached;
  // 1) Env-Secrets bevorzugt.
  const envUrl    = Deno.env.get('LIVEKIT_SELF_URL')    ?? '';
  const envKey    = Deno.env.get('LIVEKIT_SELF_KEY')    ?? '';
  const envSecret = Deno.env.get('LIVEKIT_SELF_SECRET') ?? '';
  if (envUrl && envKey && envSecret) {
    cached = { url: envUrl, key: envKey, secret: envSecret };
    return cached;
  }
  // 2) Fallback: public.get_livekit_creds() RPC (SECURITY DEFINER).
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    throw new Error('Weder Env-Secrets noch SERVICE_ROLE konfiguriert');
  }
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });
  const { data, error } = await admin.rpc('get_livekit_creds');
  if (error) {
    throw new Error('RPC get_livekit_creds fehlgeschlagen: ' + error.message);
  }
  const url    = (data?.url as string)    ?? '';
  const key    = (data?.key as string)    ?? '';
  const secret = (data?.secret as string) ?? '';
  if (!url || !key || !secret) {
    throw new Error('LiveKit-Credentials in push_config leer');
  }
  cached = { url, key, secret };
  return cached;
}

function b64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function hmacSha256(key: string, msg: string): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw', enc.encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(msg));
  return new Uint8Array(sig);
}

async function createToken(creds: { key: string; secret: string }, opts: {
  identity: string;
  name?: string;
  metadata?: string;
  roomName: string;
  canPublish: boolean;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const ttl = 4 * 3600;
  const headerB64 = b64url(
    new TextEncoder().encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })),
  );
  const payload: Record<string, any> = {
    iss: creds.key,
    sub: opts.identity,
    iat: now,
    exp: now + ttl,
    video: {
      roomJoin: true,
      room: opts.roomName,
      canPublish: opts.canPublish,
      canSubscribe: true,
      canPublishData: true,
    },
  };
  if (opts.name)     payload.name     = opts.name;
  if (opts.metadata) payload.metadata = opts.metadata;
  const payloadB64 = b64url(new TextEncoder().encode(JSON.stringify(payload)));
  const sigInput = `${headerB64}.${payloadB64}`;
  const sigBytes = await hmacSha256(creds.secret, sigInput);
  return `${sigInput}.${b64url(sigBytes)}`;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  }

  let creds: { url: string; key: string; secret: string };
  try {
    creds = await loadCreds();
  } catch (e) {
    return new Response(
      JSON.stringify({ error: 'LiveKit nicht konfiguriert: ' + ((e as Error)?.message ?? '') }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  const auth = req.headers.get('Authorization') ?? '';
  const supabase = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  }

  let body: any;
  try { body = await req.json(); } catch {
    return new Response(JSON.stringify({ error: 'Ungültiger Body' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  }
  const roomName    = typeof body.roomName === 'string'    ? body.roomName    : '';
  const displayName = typeof body.displayName === 'string' ? body.displayName : 'Mitglied';
  const canPublish  = body.canPublish !== false;
  if (!roomName) {
    return new Response(JSON.stringify({ error: 'roomName fehlt' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();
  const metadata = JSON.stringify({ role: (profile as any)?.role ?? 'user' });

  try {
    const token = await createToken(creds, {
      identity: user.id,
      name: displayName,
      metadata,
      roomName,
      canPublish,
    });
    return new Response(JSON.stringify({ token, url: creds.url }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error)?.message ?? 'Token-Erstellung fehlgeschlagen' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }
});
