import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

/** Mindestabstand zwischen Live-Raum-Benachrichtigungen pro Kanal (5 Minuten) */
const COOLDOWN_MS = 5 * 60 * 1000

// In-memory cooldown (resets on Worker restart, good enough for rate-limiting)
const lastNotified = new Map<string, number>()

/**
 * POST /api/live-room/notify
 *
 * Sendet eine Push-Benachrichtigung an alle Nutzer mit aktiven Push-Subscriptions
 * wenn ein Live-Raum in einem Community-Kanal gestartet wird.
 *
 * Body: { channelLabel: string, channelSlug: string }
 */
export async function POST(req: NextRequest) {
  const { user } = await getApiClient()
  if (!user) return err.unauthorized()

  let channelLabel: string
  let channelSlug: string
  try {
    const body = await req.json()
    channelLabel = body.channelLabel ?? '#Kanal'
    channelSlug  = body.channelSlug  ?? 'community'
  } catch {
    return err.bad('Ungültiger Body')
  }

  // Cooldown: nicht öfter als alle 5 Minuten pro Kanal benachrichtigen
  const cooldownKey = `${channelSlug}:${user.id}`
  const last = lastNotified.get(cooldownKey) ?? 0
  if (Date.now() - last < COOLDOWN_MS) {
    return NextResponse.json({ sent: 0, reason: 'cooldown' })
  }
  lastNotified.set(cooldownKey, Date.now())

  // Service-Role-Client für vollständigen DB-Zugriff
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  // Caller-Name aus Profil laden
  const { data: profile } = await admin
    .from('profiles')
    .select('name, nickname')
    .eq('id', user.id)
    .single()
  const callerName = profile?.nickname || profile?.name || 'Jemand'

  // Alle User-IDs mit aktiven Push-Subscriptions (Web + FCM), außer dem Caller
  const [{ data: webSubs }, { data: fcmTokens }] = await Promise.all([
    admin
      .from('push_subscriptions')
      .select('user_id')
      .eq('active', true)
      .neq('user_id', user.id),
    admin
      .from('fcm_tokens')
      .select('user_id')
      .eq('active', true)
      .neq('user_id', user.id),
  ])

  const userIds = [
    ...new Set([
      ...(webSubs  ?? []).map((s: { user_id: string }) => s.user_id),
      ...(fcmTokens ?? []).map((t: { user_id: string }) => t.user_id),
    ]),
  ]

  if (userIds.length === 0) {
    return NextResponse.json({ sent: 0 })
  }

  // Max 200 Empfänger pro Aufruf (Schutz gegen sehr große User-Basis)
  const recipients = userIds.slice(0, 200)

  // Für jeden Empfänger eine Notification einfügen → DB-Trigger schickt Push
  const rows = recipients.map((userId: string) => ({
    user_id:  userId,
    type:     'live_room_started',
    category: 'system',
    title:    '🎙️ Live-Raum gestartet',
    content:  `${callerName} hat den Live-Raum in ${channelLabel} gestartet`,
    link:     '/dashboard/chat',
    actor_id: user.id,
    metadata: { channelSlug, channelLabel, callerName },
  }))

  const { error } = await admin.from('notifications').insert(rows)
  if (error) {
    console.error('[live-room/notify] insert error:', error.message)
    return err.internal(error.message)
  }

  return NextResponse.json({ sent: recipients.length })
}
