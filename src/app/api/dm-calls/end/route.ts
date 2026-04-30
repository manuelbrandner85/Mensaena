import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface EndCallBody {
  callId: string
}

interface DmCallRow {
  id: string
  conversation_id: string
  caller_id: string
  callee_id: string
  status: string
  answered_at: string | null
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${s.toString().padStart(2, '0')}`
}

/**
 * POST /api/dm-calls/end
 * Beendet einen aktiven Anruf. Berechnet Dauer und schreibt Systemnachricht.
 * Body: { callId }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: EndCallBody
  try {
    body = await req.json() as EndCallBody
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!body.callId) return err.bad('callId fehlt')

  // Akzeptiert sowohl 'ringing' (Anruf wurde noch nicht angenommen — der Anrufer
  // hängt auf, bevor der Empfänger annimmt) als auch 'active' (laufender Anruf).
  // Vorher nur 'active' → 404 wenn der Anrufer früh auflegt → Row bleibt 'ringing'
  // → nächster Anruf in der Konversation wird blockiert.
  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, conversation_id, caller_id, callee_id, status, answered_at')
    .eq('id', body.callId)
    .or(`caller_id.eq.${user.id},callee_id.eq.${user.id}`)
    .in('status', ['ringing', 'active'])
    .maybeSingle<DmCallRow>()
  if (!call) {
    // Bereits beendet → idempotent. Wichtig damit der Client nicht in einer
    // Retry-Schleife hängt und der Bot das als Fehler reportiert.
    return NextResponse.json({ success: true, alreadyEnded: true })
  }

  const endedAt = new Date()
  const wasActive = call.status === 'active'
  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: 'ended',
      ended_at: endedAt.toISOString(),
      ended_reason: wasActive ? 'completed' : 'cancelled',
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  // Dauer nur bei wirklich angenommenem Anruf
  let duration: string | null = null
  if (wasActive && call.answered_at) {
    const answered = new Date(call.answered_at)
    const seconds = Math.max(0, Math.floor((endedAt.getTime() - answered.getTime()) / 1000))
    duration = formatDuration(seconds)
  }

  // Systemnachricht nur bei wirklich geführtem Anruf (status='active') —
  // ein abgebrochener 'ringing'-Anruf hat dafür /api/dm-calls/cancel.
  if (wasActive) {
    await supabase.from('messages').insert({
      conversation_id: call.conversation_id,
      sender_id: call.caller_id,
      content: duration
        ? `[SYSTEM_CALL] 📞 Anruf beendet (Dauer: ${duration})`
        : '[SYSTEM_CALL] 📞 Anruf beendet',
    })
  }

  return NextResponse.json({ success: true, duration })
}
