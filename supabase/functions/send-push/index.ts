/* ═══════════════════════════════════════════════════════════════════════
   SEND PUSH – Supabase Edge Function
   Sends notifications via TWO channels:

   1. Web Push (VAPID) – for browser + PWA users
      → reads `push_subscriptions` table
      → uses `web-push` library
   2. FCM HTTP v1 – for Capacitor-APK users
      → reads `fcm_tokens` table
      → signs JWT with service account, exchanges for OAuth2 access token,
        posts to fcm.googleapis.com/v1/projects/{id}/messages:send

   Runtime config is loaded on cold start from the private.push_config
   table via the SECURITY DEFINER RPC get_push_config(). Only SUPABASE_URL
   and SUPABASE_SERVICE_ROLE_KEY are read from Deno.env.
   ═══════════════════════════════════════════════════════════════════════ */

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import webpush from 'npm:web-push@3.6.7'

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
    vapidPublic:  cfg.vapid_public_key || '',
    vapidPrivate: cfg.vapid_private_key || '',
    vapidSubject: cfg.vapid_subject || 'mailto:support@mensaena.de',
    webhookSecret: cfg.push_webhook_secret || '',
    fcmProjectId: cfg.fcm_project_id || '',
    fcmServiceAccountJson: cfg.fcm_service_account_json || '',
  }
  if (cachedConfig.vapidPublic && cachedConfig.vapidPrivate) {
    webpush.setVapidDetails(
      cachedConfig.vapidSubject,
      cachedConfig.vapidPublic,
      cachedConfig.vapidPrivate,
    )
  }
  return cachedConfig
}

// ── FCM HTTP v1 helpers ─────────────────────────────────────────────

// OAuth2 access token cache (gültig ~1h)
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

async function sendFcm(projectId, accessToken, fcmToken, title, body, url, tag) {
  const payload = {
    message: {
      token: fcmToken,
      notification: { title: title || 'Mensaena', body: body || '' },
      data: {
        url: url || '/dashboard/notifications',
        tag: tag || 'mensaena-notification',
      },
      android: {
        priority: 'HIGH',
        notification: {
          channel_id: 'mensaena_default',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default',
        },
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
    const { user_id, title, body, url, tag } = await req.json()
    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id required' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }

    let webSent = 0, webFailed = 0, webStale = 0
    let fcmSent = 0, fcmFailed = 0, fcmStale = 0

    // ── 1. Web Push (VAPID) ─────────────────────────────────────────
    if (config.vapidPublic && config.vapidPrivate) {
      const { data: subscriptions } = await adminClient
        .from('push_subscriptions')
        .select('id, endpoint, p256dh, auth')
        .eq('user_id', user_id)
        .eq('active', true)

      if (subscriptions?.length) {
        const webPayload = JSON.stringify({
          title: title || 'Mensaena',
          body:  body || '',
          icon:  '/icons/icon-192x192.png',
          badge: '/icons/icon-72x72.png',
          url:   url || '/dashboard/notifications',
          tag:   tag || 'mensaena-notification',
        })

        const staleIds = []
        await Promise.all(
          subscriptions.map(async (sub) => {
            try {
              await webpush.sendNotification(
                { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
                webPayload,
                { TTL: 86400 },
              )
              webSent++
            } catch (err) {
              const status = err?.statusCode ?? 0
              if (status === 404 || status === 410) staleIds.push(sub.id)
              webFailed++
            }
          }),
        )
        if (staleIds.length) {
          await adminClient.from('push_subscriptions').update({ active: false }).in('id', staleIds)
          webStale = staleIds.length
        }
      }
    }

    // ── 2. FCM (Capacitor APK) ──────────────────────────────────────
    if (config.fcmProjectId && config.fcmServiceAccountJson) {
      try {
        const serviceAccount = typeof config.fcmServiceAccountJson === 'string'
          ? JSON.parse(config.fcmServiceAccountJson)
          : config.fcmServiceAccountJson

        const { data: fcmTokens } = await adminClient
          .from('fcm_tokens')
          .select('id, token')
          .eq('user_id', user_id)
          .eq('active', true)

        if (fcmTokens?.length) {
          const accessToken = await getFcmAccessToken(serviceAccount)
          const staleIds = []

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
              )
              if (result.ok) {
                fcmSent++
              } else {
                fcmFailed++
                // 404/UNREGISTERED → Token abgelaufen, deaktivieren
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
        }
      } catch (err) {
        // FCM-Fehler sollen Web Push nicht down-fallen lassen
        fcmFailed++
      }
    }

    return new Response(
      JSON.stringify({
        web: { sent: webSent, failed: webFailed, stale: webStale },
        fcm: { sent: fcmSent, failed: fcmFailed, stale: fcmStale },
      }),
      { status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Internal error', details: String(err) }),
      { status: 500, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  }
})
