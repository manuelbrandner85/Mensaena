// LiveKit Token Edge Function — Server-Side JWT für Audio/Video-Rooms.
// Spiegel von /src/app/api/live-room/token/route.ts mit HMAC-SHA256.
//
// POST { roomName, displayName?, canPublish? } → { token, url }
//
// Secrets (Supabase Dashboard → Edge Function Secrets):
//   LIVEKIT_SELF_URL   — wss://livekit.mensaena.de
//   LIVEKIT_SELF_KEY   — API-Key
//   LIVEKIT_SELF_SECRET — API-Secret

// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SELF_URL    = Deno.env.get('LIVEKIT_SELF_URL')    ?? '';
const SELF_KEY    = Deno.env.get('LIVEKIT_SELF_KEY')    ?? '';
const SELF_SECRET = Deno.env.get('LIVEKIT_SELF_SECRET') ?? '';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function b64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function hmacSha256(key: string, msg: string): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    enc.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(msg));
  return new Uint8Array(sig);
}

async function createToken(opts: {
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
    iss: SELF_KEY,
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
  const sigBytes = await hmacSha256(SELF_SECRET, sigInput);
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

  if (!SELF_URL || !SELF_KEY || !SELF_SECRET) {
    return new Response(
      JSON.stringify({ error: 'LiveKit nicht konfiguriert (LIVEKIT_SELF_URL/KEY/SECRET fehlt im Supabase-Secret)' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  // Auth via Supabase
  const auth = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: auth } } },
  );
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

  // Role-Metadata mitsenden (1:1 zu Web)
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();
  const metadata = JSON.stringify({ role: (profile as any)?.role ?? 'user' });

  try {
    const token = await createToken({
      identity: user.id,
      name: displayName,
      metadata,
      roomName,
      canPublish,
    });
    return new Response(JSON.stringify({ token, url: SELF_URL }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error)?.message ?? 'Token-Erstellung fehlgeschlagen' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }
});
