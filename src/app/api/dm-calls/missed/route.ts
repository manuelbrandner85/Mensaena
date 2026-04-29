import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface MissedCallBody {
  callId: string
}

interface DmCallRow {
  id: string
  conversation_id: string
  caller_id: string
  status: string
}

/**
 * POST /api/dm-calls/missed
 * Markiert einen Anruf als verpasst (nach 45s ohne Annahme).
 * Body: { callId }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: MissedCallBody
  try {
    body = await req.json() as MissedCallBody
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!body.callId) return err.bad('callId fehlt')

  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, conversation_id, caller_id, status')
    .eq('id', body.callId)
    .eq('caller_id', user.id)
    .eq('status', 'ringing')
    .maybeSingle<DmCallRow>()
  if (!call) return err.notFound('Anruf nicht gefunden')

  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: 'missed',
      ended_at: new Date().toISOString(),
      ended_reason: 'missed',
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  await supabase.from('messages').insert({
    conversation_id: call.conversation_id,
    sender_id: call.caller_id,
    content: '[SYSTEM_CALL] 📵 Verpasster Anruf',
  })

  return NextResponse.json({ success: true })
}
