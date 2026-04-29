// Deploy marker 2026-04-29T19:30Z – BOOT_ERROR fix: web-push entfernt
/* ═══════════════════════════════════════════════════════════════════════
   SEND PUSH – Supabase Edge Function (FCM-only)

   Sendet ausschliesslich FCM HTTP v1 für Capacitor-APK Nutzer.
   Web-Push (VAPID) wurde entfernt da:
   - npm:web-push verursacht BOOT_ERROR im Edge-Runtime (Deno)
   - User hat ausdrücklich nur native APK gewünscht
   - send-push wird automatisch via DB-Trigger gerufen → wenn Function
     crasht, kommt NICHTS auf dem Handy an

   FCM HTTP v1: signiert JWT mit service-account.private_key, tauscht
   gegen OAuth2-Token, postet an fcm.googleapis.com.

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
  }
  if (metadata && typeof metadata === 'object') {
    for (const [k, v] of Object.entries(metadata)) {
      if (v !== null && v !== undefined) dataFields[k] = String(v)
    }
  }

  if (isCall) {
    dataFields.title = title || 'Anruf'
    dataFields.body  = body  || 'Eingehender Anruf'
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
              notification: {
                channel_id: 'mensaena_default',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                sound: 'default',
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

    const responsePayload = {
      web: { sent: 0, failed: 0, stale: 0 },
      fcm: { sent: fcmSent, failed: fcmFailed, stale: fcmStale },
    }
    if (fcmDebug) responsePayload.fcm_debug = fcmDebug

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
