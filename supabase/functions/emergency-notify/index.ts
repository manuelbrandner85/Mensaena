// emergency-notify — sendet FCM-Push an alle User im 500-m-Umkreis eines neuen SOS-Alerts.
// Wird via Supabase Database Webhook (INSERT auf emergency_alerts) getriggert.
import {
  CORS,
  json,
  adminClient,
} from '../_shared/util.ts'

const WEBHOOK_SECRET = Deno.env.get('EMERGENCY_WEBHOOK_SECRET') ?? ''
const SEND_PUSH_URL = `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push`
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  // Webhook-Secret validieren
  const secret = req.headers.get('x-webhook-secret') ?? ''
  if (WEBHOOK_SECRET && secret !== WEBHOOK_SECRET) {
    return json({ error: 'unauthorized' }, 401)
  }

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'invalid_body' }, 400)
  }

  // Supabase DB-Webhook: record ist der neue Row
  const record = (body.record ?? body) as Record<string, unknown>
  const alertId = record.id as string
  const latitude = record.latitude as number
  const longitude = record.longitude as number
  const alertType = record.alert_type as string
  const creatorId = record.user_id as string

  if (!alertId || latitude == null || longitude == null) {
    return json({ error: 'missing_fields' }, 400)
  }

  const admin = adminClient()

  // User im Umkreis von 500 m finden (via PostGIS)
  const { data: nearbyUsers, error: geoErr } = await admin.rpc(
    'users_within_meters',
    { lat: latitude, lng: longitude, meters: 500 },
  )

  if (geoErr) {
    console.error('geo lookup failed:', geoErr.message)
    return json({ error: 'geo_lookup_failed' }, 500)
  }

  const userIds: string[] = (nearbyUsers ?? [])
    .map((r: Record<string, string>) => r.user_id)
    .filter((uid: string) => uid !== creatorId)

  if (userIds.length === 0) {
    return json({ sent: 0 })
  }

  // FCM-Push via send-push Function
  const pushPayload = {
    user_ids: userIds,
    title: alertType === 'medical'
      ? '🚨 Medizinischer Notfall in deiner Nähe'
      : alertType === 'fire'
      ? '🔥 Feuer in deiner Nähe gemeldet'
      : alertType === 'accident'
      ? '⚠️ Unfall in deiner Nähe'
      : '🆘 Notfall in deiner Nähe',
    body: 'Jemand braucht sofortige Hilfe – tippe um zu helfen.',
    data: {
      type: 'emergency_alert',
      alert_id: alertId,
      route: `/dashboard/crisis/sos`,
    },
    android_channel: '_crisis',
  }

  try {
    const resp = await fetch(SEND_PUSH_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${SERVICE_ROLE}`,
      },
      body: JSON.stringify(pushPayload),
    })
    const result = await resp.json()
    return json({ sent: userIds.length, push: result })
  } catch (err) {
    console.error('push send failed:', err)
    return json({ error: 'push_failed' }, 500)
  }
})
