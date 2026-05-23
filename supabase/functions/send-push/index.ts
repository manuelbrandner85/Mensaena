// Deploy marker 2026-05-23T21:00Z – Web-Push (VAPID) re-aktiviert
/* ═══════════════════════════════════════════════════════════════════════
   SEND PUSH – Supabase Edge Function (FCM + Web-Push)

   Sendet sowohl:
   - FCM HTTP v1 (Capacitor-APK / native Flutter) — Tabelle `fcm_tokens`
   - Web-Push (VAPID, RFC-8030) fuer Browser — Tabelle `push_subscriptions`

   Web-Push ist via native Web-Crypto-API umgesetzt (KEIN npm:web-push,
   das Boot-Errors verursacht hat). VAPID-JWT wird in Deno selbst
   signiert (ES256/P-256 via crypto.subtle).

   Runtime config wird beim Cold-Start aus private.push_config geladen
   via SECURITY DEFINER RPC get_push_config(). Nur SUPABASE_URL und
   SUPABASE_SERVICE_ROLE_KEY werden aus Deno.env gelesen.
   ═══════════════════════════════════════════════════════════════════════ */

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// ── CORS ────────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  'https://mensaena.de',
  'https://www.mensaena.de',
]

function corsHeaders(origin) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, X-Webhook-Secret',
    'Access-Control-Max-Age': '86400',
  }
}

// ── Runtime config (loaded once per cold start) ─────────────────────

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

let cachedConfig = null
async function loadConfig() {
  if (cachedConfig) return cachedConfig
  const { data, error } = await adminClient.rpc('get_push_config')
  if (error || !data) {
    throw new Error('Failed to load push config: ' + (error?.message ?? 'no rows'))
  }
  const cfg = {}
  for (const row of data) cfg[row.key] = row.value
  cachedConfig = {
    webhookSecret: cfg.push_webhook_secret || '',
    fcmProjectId: cfg.fcm_project_id || '',
    fcmServiceAccountJson: cfg.fcm_service_account_json || '',
    vapidPublicKey: cfg.vapid_public_key || '',
    vapidPrivateKey: cfg.vapid_private_key || '',
    vapidSubject: cfg.vapid_subject || 'mailto:hello@mensaena.de',
  }
  return cachedConfig
}

// ── FCM HTTP v1 helpers ─────────────────────────────────────────────

let cachedFcmToken = null
let cachedFcmTokenExp = 0

function base64UrlEncode(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf)
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToArrayBuffer(pem) {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

async function signJwtRS256(header, claims, privateKeyPem) {
  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)))
  const claimsB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(claims)))
  const unsigned = `${headerB64}.${claimsB64}`

  const keyData = pemToArrayBuffer(privateKeyPem)
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  )
  return `${unsigned}.${base64UrlEncode(sig)}`
}

async function getFcmAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000)
  if (cachedFcmToken && now < cachedFcmTokenExp - 60) {
    return cachedFcmToken
  }

  const jwt = await signJwtRS256(
    { alg: 'RS256', typ: 'JWT', kid: serviceAccount.private_key_id },
    {
      iss:   serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud:   'https://oauth2.googleapis.com/token',
      iat:   now,
      exp:   now + 3600,
    },
    serviceAccount.private_key,
  )

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  })
  const data = await res.json()
  if (!res.ok || !data.access_token) {
    throw new Error('FCM OAuth2 exchange failed: ' + JSON.stringify(data))
  }
  cachedFcmToken = data.access_token
  cachedFcmTokenExp = now + (data.expires_in ?? 3600)
  return cachedFcmToken
}

async function sendFcm(projectId, accessToken, fcmToken, title, body, url, tag, type, metadata) {
  const isCall = type === 'incoming_call'

  const dataFields = {
    url: url || '/dashboard/notifications',
    tag: tag || 'mensaena-notification',
    type: type || 'notification',
    // title+body IMMER in data — Android-Background-Handler liest sie zuverlässig,
    // notification.title wird vom System teils ueberschrieben.
    title: title || 'Mensaena',
    body:  body  || '',
  }
  if (metadata && typeof metadata === 'object') {
    for (const [k, v] of Object.entries(metadata)) {
      if (v !== null && v !== undefined) dataFields[k] = String(v)
    }
  }

  const payload = {
    message: {
      token: fcmToken,
      // CALLS: data-only (kein notification field), HIGH priority, TTL 45s.
      // Ermöglicht onMessageReceived() auch wenn App geschlossen ist.
      ...(isCall ? {} : { notification: { title: title || 'Mensaena', body: body || '' } }),
      data: dataFields,
      android: {
        priority: 'HIGH',
        ...(isCall
          ? { ttl: '45s' }
          : {
              // android.notification.title MUSS explizit gesetzt sein,
              // sonst zeigt Android nur den App-Namen "Mensaena".
              notification: {
                title: title || 'Mensaena',
                body:  body  || '',
                channel_id: 'mensaena_default',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                sound: 'default',
                default_sound: true,
                default_vibrate_timings: true,
              },
            }),
      },
    },
  }

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
  )
  const text = await res.text()
  return { ok: res.ok, status: res.status, body: text }
}

// ── Web-Push (VAPID, RFC-8030) helpers ──────────────────────────────

function urlBase64Decode(s) {
  const padded = s.replace(/-/g, '+').replace(/_/g, '/').padEnd(s.length + (4 - s.length % 4) % 4, '=')
  const bin = atob(padded)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

async function importVapidKey(privateKeyB64) {
  // VAPID-Privatschluessel ist eine 32-Byte-EC-Skalar im RAW-Format.
  // Wir brauchen aber JWK fuer Web-Crypto.
  const dRaw = urlBase64Decode(privateKeyB64)
  if (dRaw.length !== 32) throw new Error('VAPID private key must be 32 bytes')
  // JWK braucht x + y des Public-Keys — wir leiten sie via Point-Multiplikation ab.
  // Einfacher Weg: import als PKCS8 nicht moeglich ohne Public-Key.
  // Daher: hier ist ein vereinfachter Approach mit ES256-JWT-Signierung.
  // Wir erzeugen ein Public-Key-Pair aus dem Privatschluessel.
  // Stattdessen: nutze den raw d und derive public point.
  const d = dRaw
  // Public-Key Derivation: P-256 (secp256r1)
  // Verwendet das in Deno via crypto.subtle.importKey
  // → wir setzen y=0,x=0 als Platzhalter da wir kein eigenes EC-Arithmetik haben.
  // Best practice: User soll Public-Key + Private-Key separat in cfg speichern.
  // Wir nehmen `vapidPublicKey` (cfg.vapid_public_key) als Pendant.
  return d
}

async function signVapidJwt(audOrigin, expSeconds, subject, privateKeyB64, publicKeyB64) {
  const header = { typ: 'JWT', alg: 'ES256' }
  const claims = {
    aud: audOrigin,
    exp: Math.floor(Date.now() / 1000) + expSeconds,
    sub: subject,
  }
  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)))
  const claimsB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(claims)))
  const unsigned = `${headerB64}.${claimsB64}`

  const d = urlBase64Decode(privateKeyB64)
  const publicKey = urlBase64Decode(publicKeyB64) // 65 Bytes: 0x04 || x(32) || y(32)
  if (publicKey.length !== 65 || publicKey[0] !== 0x04) {
    throw new Error('VAPID public key must be uncompressed 65 bytes (0x04 prefix)')
  }
  const x = publicKey.slice(1, 33)
  const y = publicKey.slice(33, 65)

  const jwk = {
    kty: 'EC',
    crv: 'P-256',
    d: base64UrlEncode(d),
    x: base64UrlEncode(x),
    y: base64UrlEncode(y),
    ext: true,
  }
  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(unsigned),
  )
  return `${unsigned}.${base64UrlEncode(sig)}`
}

async function sendWebPush(subscription, payload, vapid) {
  try {
    const endpoint = new URL(subscription.endpoint)
    const audOrigin = `${endpoint.protocol}//${endpoint.host}`
    const jwt = await signVapidJwt(audOrigin, 12 * 3600, vapid.subject, vapid.privateKey, vapid.publicKey)
    // Web-Push ohne Encryption (NUR fuer text-Payloads ueber HTTPS) ist NICHT
    // mehr unterstuetzt. Browser fordern Encryption. Da Encryption mit
    // Web-Crypto in Deno zu komplex ist (ECDH+HKDF+AES-GCM), senden wir
    // einen leeren Payload und packen alle Daten in den Service-Worker
    // via "push" Event ohne Body (Topic-Header trigger).
    // Browser zeigen dann generic Notification, Service-Worker fetched
    // dann eigene Daten via Background-Sync.
    const res = await fetch(subscription.endpoint, {
      method: 'POST',
      headers: {
        Authorization: `vapid t=${jwt}, k=${vapid.publicKey}`,
        TTL: '60',
        // KEIN Content-Encoding/Encryption (Payload-less Push).
      },
    })
    return { ok: res.status >= 200 && res.status < 300, status: res.status }
  } catch (err) {
    return { ok: false, status: 0, error: String(err) }
  }
}

// ── Main handler ────────────────────────────────────────────────────

serve(async (req) => {
  const origin = req.headers.get('origin')

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(origin) })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  let config
  try {
    config = await loadConfig()
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Config load failed', details: String(err) }), {
      status: 500,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  // Shared-secret check
  if (config.webhookSecret) {
    const provided = req.headers.get('x-webhook-secret') ?? ''
    if (provided !== config.webhookSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }
  }

  try {
    const { user_id, title, body, url, tag, type, metadata } = await req.json()
    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id required' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }

    let fcmSent = 0, fcmFailed = 0, fcmStale = 0
    let fcmDebug = ''

    // ── FCM (Capacitor APK) ─────────────────────────────────────────
    if (!config.fcmProjectId) {
      fcmDebug = 'skipped: fcm_project_id empty in push_config'
    } else if (!config.fcmServiceAccountJson) {
      fcmDebug = 'skipped: fcm_service_account_json empty'
    } else {
      try {
        let serviceAccount
        try {
          serviceAccount = typeof config.fcmServiceAccountJson === 'string'
            ? JSON.parse(config.fcmServiceAccountJson)
            : config.fcmServiceAccountJson
        } catch (e) {
          fcmDebug = 'service-account JSON not parseable: ' + String(e)
          throw new Error('bad service account json')
        }
        if (serviceAccount.type !== 'service_account') {
          fcmDebug = `service-account wrong type: "${serviceAccount.type}"`
          throw new Error('wrong JSON type')
        }
        if (!serviceAccount.private_key || !serviceAccount.client_email) {
          fcmDebug = 'service-account missing private_key / client_email'
          throw new Error('incomplete SA')
        }

        const { data: fcmTokens } = await adminClient
          .from('fcm_tokens')
          .select('id, token')
          .eq('user_id', user_id)
          .eq('active', true)

        if (!fcmTokens?.length) {
          fcmDebug = fcmDebug || 'no active fcm_tokens for user_id'
        } else {
          let accessToken
          try {
            accessToken = await getFcmAccessToken(serviceAccount)
          } catch (e) {
            fcmDebug = 'OAuth2 exchange failed: ' + String(e)
            throw e
          }
          const staleIds = []
          const failDetails = []

          await Promise.all(
            fcmTokens.map(async (row) => {
              const result = await sendFcm(
                config.fcmProjectId,
                accessToken,
                row.token,
                title,
                body,
                url,
                tag,
                type,
                metadata,
              )
              if (result.ok) {
                fcmSent++
              } else {
                fcmFailed++
                failDetails.push(`HTTP ${result.status}: ${result.body?.substring(0, 200)}`)
                if (result.status === 404 || result.body?.includes('UNREGISTERED')) {
                  staleIds.push(row.id)
                }
              }
            }),
          )

          if (staleIds.length) {
            await adminClient.from('fcm_tokens').update({ active: false }).in('id', staleIds)
            fcmStale = staleIds.length
          }
          if (failDetails.length) {
            fcmDebug = failDetails[0]
          }
        }
      } catch (err) {
        if (!fcmDebug) fcmDebug = 'catch: ' + String(err)
        fcmFailed = Math.max(fcmFailed, 1)
      }
    }

    // ── Web-Push (VAPID, RFC-8030) ──────────────────────────────────
    let webSent = 0, webFailed = 0, webStale = 0
    let webDebug = ''

    if (!config.vapidPublicKey || !config.vapidPrivateKey) {
      webDebug = 'skipped: vapid_public_key/private_key not in push_config'
    } else {
      try {
        const { data: webSubs } = await adminClient
          .from('push_subscriptions')
          .select('id, endpoint, p256dh, auth')
          .eq('user_id', user_id)
          .eq('active', true)

        if (!webSubs?.length) {
          webDebug = webDebug || 'no active web push_subscriptions for user_id'
        } else {
          const vapid = {
            publicKey: config.vapidPublicKey,
            privateKey: config.vapidPrivateKey,
            subject: config.vapidSubject,
          }
          const staleIds = []
          await Promise.all(webSubs.map(async (sub) => {
            const result = await sendWebPush(sub, { title, body, url, tag, type, metadata }, vapid)
            if (result.ok) {
              webSent++
            } else {
              webFailed++
              // 404/410 → endpoint gone, deactivate
              if (result.status === 404 || result.status === 410) {
                staleIds.push(sub.id)
              }
              if (!webDebug) webDebug = `web: HTTP ${result.status}`
            }
          }))
          if (staleIds.length) {
            await adminClient.from('push_subscriptions').update({ active: false }).in('id', staleIds)
            webStale = staleIds.length
          }
        }
      } catch (err) {
        if (!webDebug) webDebug = 'web catch: ' + String(err)
        webFailed = Math.max(webFailed, 1)
      }
    }

    const responsePayload = {
      web: { sent: webSent, failed: webFailed, stale: webStale },
      fcm: { sent: fcmSent, failed: fcmFailed, stale: fcmStale },
    }
    if (fcmDebug) responsePayload.fcm_debug = fcmDebug
    if (webDebug) responsePayload.web_debug = webDebug

    return new Response(
      JSON.stringify(responsePayload),
      { status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Internal error', details: String(err) }),
      { status: 500, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  }
})
