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

  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, conversation_id, caller_id, callee_id, status, answered_at')
    .eq('id', body.callId)
    .or(`caller_id.eq.${user.id},callee_id.eq.${user.id}`)
    .eq('status', 'active')
    .maybeSingle<DmCallRow>()
  if (!call) return err.notFound('Anruf nicht aktiv')

  const endedAt = new Date()
  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: 'ended',
      ended_at: endedAt.toISOString(),
      ended_reason: 'completed',
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  let duration = '0:00'
  if (call.answered_at) {
    const answered = new Date(call.answered_at)
    const seconds = Math.max(0, Math.floor((endedAt.getTime() - answered.getTime()) / 1000))
    duration = formatDuration(seconds)
  }

  await supabase.from('messages').insert({
    conversation_id: call.conversation_id,
    sender_id: call.caller_id,
    content: `[SYSTEM_CALL] 📞 Anruf beendet (Dauer: ${duration})`,
  })

  return NextResponse.json({ success: true, duration })
}
