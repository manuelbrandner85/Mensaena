/* ═══════════════════════════════════════════════════════════════════════
   SEND PUSH – Supabase Edge Function
   Sends Web Push notifications to a user's subscriptions using VAPID.

   Uses the `web-push` npm package (loaded via Deno's npm: specifier) so
   that the VAPID JWT signing and payload encryption are handled
   correctly per RFC 8291 / RFC 8292 — the previous "plain POST" path
   could never reach real push services (FCM / Mozilla / Apple).

   Invocation:
     POST /functions/v1/send-push
     Header:  X-Webhook-Secret: <PUSH_WEBHOOK_SECRET>  (from the trigger)
     Body:    { user_id, title, body, url?, tag? }

   Env (set via `supabase secrets set` or the Functions dashboard):
     VAPID_PUBLIC_KEY    – base64url uncompressed EC P-256 public key (65B)
     VAPID_PRIVATE_KEY   – base64url EC P-256 private scalar (32B)
     VAPID_SUBJECT       – mailto:support@mensaena.de (or https:// URL)
     PUSH_WEBHOOK_SECRET – shared secret with the DB trigger
   ═══════════════════════════════════════════════════════════════════════ */

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import webpush from 'npm:web-push@3.6.7'

// ── CORS ────────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  'https://mensaena.de',
  'https://www.mensaena.de',
]

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, X-Webhook-Secret',
    'Access-Control-Max-Age': '86400',
  }
}

// ── VAPID setup (runs once per cold start) ───────────────────────────

const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? ''
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:support@mensaena.de'
const WEBHOOK_SECRET = Deno.env.get('PUSH_WEBHOOK_SECRET') ?? ''

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
}

// ── Main handler ────────────────────────────────────────────────────

serve(async (req: Request) => {
  const origin = req.headers.get('origin')

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(origin) })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    })
  }

  // Shared-secret check: only the DB trigger (or an operator) may fire.
  if (WEBHOOK_SECRET) {
    const provided = req.headers.get('x-webhook-secret') ?? ''
    if (provided !== WEBHOOK_SECRET) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      })
    }
  }

  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
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

    // Admin client for subscription lookup + stale cleanup.
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data: subscriptions, error: subError } = await supabase
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
    const staleIds: string[] = []

    await Promise.all(
      subscriptions.map(async (sub: { id: string; endpoint: string; p256dh: string; auth: string }) => {
        try {
          await webpush.sendNotification(
            {
              endpoint: sub.endpoint,
              keys: { p256dh: sub.p256dh, auth: sub.auth },
            },
            payload,
            { TTL: 86400 },
          )
          sent++
        } catch (err) {
          const status = (err as { statusCode?: number }).statusCode ?? 0
          if (status === 404 || status === 410) {
            // Gone / not registered → mark inactive.
            staleIds.push(sub.id)
          }
          failed++
        }
      }),
    )

    if (staleIds.length > 0) {
      await supabase
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
