import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface StartCallBody {
  conversationId: string
  callType: 'audio' | 'video'
}

interface ConversationMember {
  user_id: string
}

interface DmCallRow {
  id: string
  room_name: string
  status: string
  created_at: string
  caller_id?: string
}

/**
 * POST /api/dm-calls/start
 * Startet einen 1-zu-1-Anruf in einer DM-Konversation.
 * Body: { conversationId, callType }
 * Response: { callId, roomName }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: StartCallBody
  try {
    body = await req.json() as StartCallBody
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!body.conversationId || !['audio', 'video'].includes(body.callType)) {
    return err.bad('conversationId oder callType fehlt/ungültig')
  }

  const { data: ownMembership } = await supabase
    .from('conversation_members')
    .select('user_id')
    .eq('conversation_id', body.conversationId)
    .eq('user_id', user.id)
    .maybeSingle<ConversationMember>()
  if (!ownMembership) return err.forbidden()

  // FIX-28: Ban-Check vor Anruf-Start
  const { data: ban } = await supabase
    .from('chat_banned_users')
    .select('id, expires_at')
    .eq('user_id', user.id)
    .maybeSingle<{ id: string; expires_at: string | null }>()
  if (ban && (!ban.expires_at || new Date(ban.expires_at) > new Date())) {
    return err.forbidden('Du bist im Chat gesperrt')
  }

  const { data: existing } = await supabase
    .from('dm_calls')
    .select('id, room_name, status, created_at, caller_id')
    .eq('conversation_id', body.conversationId)
    .in('status', ['ringing', 'active'])
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle<DmCallRow>()
  if (existing) {
    // Stale-Cleanup: Eine Row in 'ringing'/'active' kann hängen bleiben wenn
    //   - die App des Anrufers crasht/geschlossen wird bevor /end gepostet wird,
    //   - das Netzwerk während des Hangups abbricht,
    //   - LiveKit-Disconnect das /end-POST verschluckt (cleanedUp-Race).
    // Ohne Auto-Cleanup blockiert sie *jeden* weiteren Call in der Konversation.
    // Zusätzlich: wenn derselbe User einen neuen Call starten will, hat er den
    // alten offensichtlich abgebrochen — dessen Row sofort beenden (egal wie alt).
    const ageMs = Date.now() - new Date(existing.created_at).getTime()
    const callerRetry  = existing.caller_id === user.id
    const ringingStale = existing.status === 'ringing' && (callerRetry || ageMs > 90_000)
    // FIX-B: In einem 2-Personen-DM ist der anfragende User immer Caller oder Callee.
    // Wenn er einen neuen Call starten will, ist ein 'active'-Row zwingend stale
    // (weil /api/dm-calls/end nicht ankam). Kleiner Buffer von 10s schützt vor
    // Race-Cleanup eines soeben verbundenen Calls.
    const activeStale  = existing.status === 'active'  && ageMs > 10_000
    if (ringingStale || activeStale) {
      await supabase
        .from('dm_calls')
        .update({
          status: 'ended',
          ended_reason: 'cancelled',
          ended_at: new Date().toISOString(),
        })
        .eq('id', existing.id)
      // Fall durch zu Insert unten
    } else {
      return err.conflict('Bereits ein aktiver Anruf in dieser Konversation')
    }
  }

  const { data: members } = await supabase
    .from('conversation_members')
    .select('user_id')
    .eq('conversation_id', body.conversationId)
    .neq('user_id', user.id)
    .returns<ConversationMember[]>()
  const calleeId = members?.[0]?.user_id
  if (!calleeId) return err.bad('Kein Empfänger in dieser Konversation')

  const roomName = `dm-call-${crypto.randomUUID()}`

  const { data: inserted, error: insertErr } = await supabase
    .from('dm_calls')
    .insert({
      conversation_id: body.conversationId,
      caller_id: user.id,
      callee_id: calleeId,
      call_type: body.callType,
      room_name: roomName,
      status: 'ringing',
    })
    .select('id, room_name')
    .single<DmCallRow>()

  if (insertErr || !inserted) {
    // FIX-1: Race Condition Doppel-Start – unique constraint verletzt = paralleler Insert
    if (insertErr?.code === '23505') {
      return NextResponse.json({ error: 'Anruf existiert bereits' }, { status: 409 })
    }
    return err.internal(insertErr?.message ?? 'Insert fehlgeschlagen')
  }

  // ── BUG-FIX: Caller-Token sofort bei Start generieren ────────────────────
  // Damit A nicht nach der Annahme nochmal /api/live-room/token fetchen muss
  const { data: callerProfileForToken } = await supabase
    .from('profiles')
    .select('name, role')
    .eq('id', user.id)
    .maybeSingle<{ name: string | null; role: string | null }>()

  let callerToken: string | null = null
  let callerUrl: string | null = null
  try {
    const { generateLiveKitToken } = await import('@/lib/livekit/token')
    const result = await generateLiveKitToken({
      roomName,
      identity: user.id,
      displayName: callerProfileForToken?.name ?? 'Mitglied',
      metadata: JSON.stringify({ role: callerProfileForToken?.role ?? 'user' }),
    })
    callerToken = result.token
    callerUrl = result.url
  } catch {
    // BUG-FIX: Token-Fehler darf Call nicht blockieren – Fallback auf alten Flow
  }

  // ── FEATURE: WhatsApp-Style Call – High-Priority Push an Callee ──────────
  try {
    const [{ data: callerProfile }, { data: subscriptions }] = await Promise.all([
      supabase
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', user.id)
        .maybeSingle<{ name: string | null; avatar_url: string | null }>(),
      supabase
        .from('push_subscriptions')
        .select('endpoint, p256dh, auth')
        .eq('user_id', calleeId),
    ])

    if (subscriptions && subscriptions.length > 0) {
      const pushPayload = JSON.stringify({
        type: 'incoming_call',
        call_id: inserted.id,
        room_name: inserted.room_name,
        call_type: body.callType,
        conversation_id: body.conversationId,
        caller_name: callerProfile?.name ?? 'Unbekannt',
        caller_avatar: callerProfile?.avatar_url ?? null,
        caller_id: user.id,
        title: callerProfile?.name
          ? `${callerProfile.name} ruft an`
          : 'Eingehender Anruf',
        body: body.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
        tag: 'incoming-call',
        requireInteraction: true,
      })

      const webPush = await import('web-push')
      webPush.setVapidDetails(
        'mailto:support@mensaena.de',
        process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!,
        process.env.VAPID_PRIVATE_KEY!,
      )

      await Promise.allSettled(
        (subscriptions as Array<{ endpoint: string; p256dh: string; auth: string }>).map(sub =>
          webPush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
            pushPayload,
            { TTL: 60, urgency: 'high', topic: `call-${inserted.id}` },
          ).catch(() => {}),
        ),
      )
    }
  } catch {
    // FEATURE: WhatsApp-Style Call – Push-Fehler blockiert den Call nicht, Realtime ist Fallback
  }

  // BUG-FIX: Token + URL direkt mitliefern damit Anrufer sofort beitreten kann
  return NextResponse.json({
    callId: inserted.id,
    roomName: inserted.room_name,
    callerToken,
    callerUrl,
  })
}
