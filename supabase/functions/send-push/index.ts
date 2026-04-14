/* ═══════════════════════════════════════════════════════════════════════
   SEND PUSH – Supabase Edge Function
   Sends Web Push notifications to a user's subscriptions using VAPID.

   Runtime config (VAPID keys, subject, shared webhook secret) is loaded
   on cold start from the private.push_config table via the
   SECURITY DEFINER RPC get_push_config() so that no dashboard secrets
   need to be set manually. Only SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
   (both injected automatically by the Edge Function runtime) are
   read from Deno.env.
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
    vapidPublic: cfg.vapid_public_key || '',
    vapidPrivate: cfg.vapid_private_key || '',
    vapidSubject: cfg.vapid_subject || 'mailto:support@mensaena.de',
    webhookSecret: cfg.push_webhook_secret || '',
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

  // Shared-secret check: only the DB trigger (or an operator) may fire.
  if (config.webhookSecret) {
    const provided = req.headers.get('x-webhook-secret') ?? ''
    if (provided !== config.webhookSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }
  }

  if (!config.vapidPublic || !config.vapidPrivate) {
    return new Response(JSON.stringify({ error: 'VAPID keys not configured' }), {
      status: 500,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  try {
    const { user_id, title, body, url, tag } = await req.json()

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id required' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }

    const { data: subscriptions, error: subError } = await adminClient
      .from('push_subscriptions')
      .select('id, endpoint, p256dh, auth')
      .eq('user_id', user_id)
      .eq('active', true)

    if (subError || !subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, message: 'No active subscriptions' }),
        { status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
      )
    }

    const payload = JSON.stringify({
      title: title || 'Mensaena',
      body: body || '',
      icon: '/icons/icon-192x192.png',
      badge: '/icons/icon-72x72.png',
      url: url || '/dashboard/notifications',
      tag: tag || 'mensaena-notification',
    })

    let sent = 0
    let failed = 0
    const staleIds = []

    await Promise.all(
      subscriptions.map(async (sub) => {
        try {
          await webpush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
            payload,
            { TTL: 86400 },
          )
          sent++
        } catch (err) {
          const status = err?.statusCode ?? 0
          if (status === 404 || status === 410) {
            staleIds.push(sub.id)
          }
          failed++
        }
      }),
    )

    if (staleIds.length > 0) {
      await adminClient
        .from('push_subscriptions')
        .update({ active: false })
        .in('id', staleIds)
    }

    return new Response(
      JSON.stringify({ sent, failed, stale: staleIds.length }),
      { status: 200, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Internal error', details: String(err) }),
      { status: 500, headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' } },
    )
  }
})
