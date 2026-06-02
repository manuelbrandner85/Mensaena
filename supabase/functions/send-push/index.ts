// send-push v22 — user_notification_prefs Filter + 4-Channel-Routing
//
// Liest user_notification_prefs (enabled, type-toggles, quiet-hours,
// allow-critical) und routet zum passenden Android-NotificationChannel
// via android.notification.channel_id (mensaena_chat / _social / _system
// / _crisis / _calls / _default).
//
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.45.4'

const ALLOWED_ORIGINS = ['https://mensaena.de', 'https://www.mensaena.de']
function corsHeaders(o) {
  const a = o && ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': a,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, X-Webhook-Secret',
    'Access-Control-Max-Age': '86400',
  }
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

let cachedConfig = null
async function loadConfig() {
  if (cachedConfig) return cachedConfig
  const { data, error } = await adminClient.rpc('get_push_config')
  if (error || !data) throw new Error('cfg load: ' + (error?.message ?? 'no rows'))
  const cfg = {}
  for (const r of data) cfg[r.key] = r.value
  cachedConfig = {
    webhookSecret: cfg.push_webhook_secret || '',
    fcmProjectId: cfg.fcm_project_id || '',
    fcmServiceAccountJson: cfg.fcm_service_account_json || '',
  }
  return cachedConfig
}

let cachedFcmToken = null
let cachedFcmTokenExp = 0

function b64u(b) {
  const x = b instanceof Uint8Array ? b : new Uint8Array(b)
  let s = ''
  for (const v of x) s += String.fromCharCode(v)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pem2buf(p) {
  const b = p.replace(/-----BEGIN [^-]+-----/g, '').replace(/-----END [^-]+-----/g, '').replace(/\s+/g, '')
  const bin = atob(b)
  const u = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i)
  return u.buffer
}

async function signJwtRS256(h, c, k) {
  const a = b64u(new TextEncoder().encode(JSON.stringify(h)))
  const b = b64u(new TextEncoder().encode(JSON.stringify(c)))
  const u = `${a}.${b}`
  const kd = pem2buf(k)
  const ck = await crypto.subtle.importKey('pkcs8', kd, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', ck, new TextEncoder().encode(u))
  return `${u}.${b64u(sig)}`
}

async function getFcmAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000)
  if (cachedFcmToken && now < cachedFcmTokenExp - 60) return cachedFcmToken
  const jwt = await signJwtRS256(
    { alg: 'RS256', typ: 'JWT', kid: sa.private_key_id },
    {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now, exp: now + 3600,
    },
    sa.private_key,
  )
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  })
  const d = await r.json()
  if (!r.ok || !d.access_token) throw new Error('OAuth2: ' + JSON.stringify(d))
  cachedFcmToken = d.access_token
  cachedFcmTokenExp = now + (d.expires_in ?? 3600)
  return cachedFcmToken
}

// Channel-Routing nach category + priority.
function channelFor(category, priority, type) {
  if (type === 'incoming_call') return 'mensaena_calls'
  if (category === 'crisis' || priority === 'high') return 'mensaena_crisis'
  if (category === 'chat') return 'mensaena_chat'
  if (category === 'system') return 'mensaena_system'
  if (category === 'events' || category === 'marketplace') return 'mensaena_social'
  if (category === 'social') return 'mensaena_social'
  return 'mensaena_default'
}

async function sendFcm(projectId, accessToken, fcmToken, title, body, url, tag, type, metadata, channelId) {
  const isCall = type === 'incoming_call'
  const data = { url: url || '/dashboard/notifications', tag: tag || 'mensaena', type: type || 'notification', title: title || 'Mensaena', body: body || '' }
  if (metadata && typeof metadata === 'object') {
    for (const [k, v] of Object.entries(metadata)) {
      if (v != null) data[k] = String(v)
    }
  }
  const payload = {
    message: {
      token: fcmToken,
      ...(isCall ? {} : { notification: { title: title || 'Mensaena', body: body || '' } }),
      data,
      android: {
        priority: 'HIGH',
        ...(isCall
          ? { ttl: '45s' }
          : {
              notification: {
                title: title || 'Mensaena',
                body: body || '',
                channel_id: channelId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                sound: 'default',
                default_sound: true,
                default_vibrate_timings: true,
              },
            }),
      },
    },
  }
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  return { ok: r.ok, status: r.status, body: await r.text() }
}

// Quiet-Hours-Check (basiert auf Server-UTC + DACH-Heuristik UTC+1).
function inQuietHours(prefs) {
  if (!prefs?.quiet_hours_enabled) return false
  const h = new Date().getUTCHours()
  const localH = (h + 1) % 24
  const s = prefs.quiet_start_hour
  const e = prefs.quiet_end_hour
  if (s === e) return false
  if (s < e) return localH >= s && localH < e
  return localH >= s || localH < e
}

function filterByPrefs(prefs, category, priority) {
  if (!prefs) return { allowed: true }
  if (!prefs.enabled) return { allowed: false, reason: 'master_off' }
  const cat = category || 'social'
  if (cat === 'chat' && !prefs.chat) return { allowed: false, reason: 'chat_off' }
  if (cat === 'social' && !prefs.social) return { allowed: false, reason: 'social_off' }
  if (cat === 'system' && !prefs.system) return { allowed: false, reason: 'system_off' }
  if (cat === 'crisis' && !prefs.crisis) return { allowed: false, reason: 'crisis_off' }
  if (cat === 'marketplace' && !prefs.marketplace) return { allowed: false, reason: 'marketplace_off' }
  if (cat === 'events' && !prefs.events) return { allowed: false, reason: 'events_off' }
  if (inQuietHours(prefs)) {
    const critical = priority === 'high' || cat === 'crisis'
    if (!critical || !prefs.quiet_allow_critical) {
      return { allowed: false, reason: 'quiet_hours' }
    }
  }
  return { allowed: true }
}

serve(async (req) => {
  const origin = req.headers.get('origin')
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(origin) })
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  let config
  try { config = await loadConfig() } catch (e) {
    return new Response(JSON.stringify({ error: 'Config load', details: String(e) }), {
      status: 500, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  if (config.webhookSecret) {
    const p = req.headers.get('x-webhook-secret') ?? ''
    if (p !== config.webhookSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }
  }

  try {
    const { user_id, title, body, url, tag, type, metadata, category, priority } = await req.json()
    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id required' }), {
        status: 400, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }

    // 1) Prefs lesen
    let prefs = null
    try {
      const { data } = await adminClient.from('user_notification_prefs').select('*').eq('user_id', user_id).maybeSingle()
      prefs = data
    } catch (_) {}

    // 2) Filter anwenden
    const f = filterByPrefs(prefs, category, priority)
    if (!f.allowed) {
      return new Response(JSON.stringify({ skipped: true, reason: f.reason, fcm: { sent: 0 } }), {
        status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }

    // 3) Channel routen
    const channelId = channelFor(category, priority, type)

    let fcmSent = 0, fcmFailed = 0, fcmStale = 0, fcmDebug = ''
    if (!config.fcmProjectId || !config.fcmServiceAccountJson) {
      fcmDebug = 'fcm config missing'
    } else {
      try {
        const sa = typeof config.fcmServiceAccountJson === 'string'
          ? JSON.parse(config.fcmServiceAccountJson)
          : config.fcmServiceAccountJson
        const { data: tokens } = await adminClient.from('fcm_tokens').select('id, token').eq('user_id', user_id).eq('active', true)
        if (!tokens?.length) fcmDebug = 'no active fcm tokens'
        else {
          const accessToken = await getFcmAccessToken(sa)
          const stale = []
          await Promise.all(tokens.map(async (row) => {
            const r = await sendFcm(config.fcmProjectId, accessToken, row.token, title, body, url, tag, type, metadata, channelId)
            if (r.ok) fcmSent++
            else {
              fcmFailed++
              if (r.status === 404 || r.body?.includes('UNREGISTERED')) stale.push(row.id)
            }
          }))
          if (stale.length) {
            await adminClient.from('fcm_tokens').update({ active: false }).in('id', stale)
            fcmStale = stale.length
          }
        }
      } catch (e) {
        fcmDebug = String(e)
        fcmFailed = Math.max(fcmFailed, 1)
      }
    }

    return new Response(JSON.stringify({ fcm: { sent: fcmSent, failed: fcmFailed, stale: fcmStale }, channel: channelId, fcm_debug: fcmDebug || undefined }), {
      status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Internal', details: String(e) }), {
      status: 500, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }
})
