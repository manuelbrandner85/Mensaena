import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface DeclineCallBody {
  callId: string
}

interface DmCallRow {
  id: string
  conversation_id: string
  callee_id: string
  caller_id: string
  status: string
}

/**
 * POST /api/dm-calls/decline
 * Empfänger lehnt den Anruf ab. Schreibt Systemnachricht in den Chat.
 * Body: { callId }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: DeclineCallBody
  try {
    body = await req.json() as DeclineCallBody
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!body.callId) return err.bad('callId fehlt')

  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, conversation_id, callee_id, caller_id, status')
    .eq('id', body.callId)
    .or(`callee_id.eq.${user.id},caller_id.eq.${user.id}`)
    .maybeSingle<DmCallRow>()
  if (!call) return err.notFound('Anruf nicht gefunden')

  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: 'declined',
      ended_at: new Date().toISOString(),
      ended_reason: 'declined',
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  await supabase.from('messages').insert({
    conversation_id: call.conversation_id,
    sender_id: call.callee_id,
    content: '[SYSTEM_CALL] 📵 Anruf abgelehnt',
  })

  return NextResponse.json({ success: true })
}
