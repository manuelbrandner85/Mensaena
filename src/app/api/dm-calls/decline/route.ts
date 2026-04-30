import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface DeclineCallBody {
  callId: string
  reason?: 'declined' | 'missed'
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
 * Empfänger lehnt den Anruf ab oder Anruf-Timeout (45s).
 * Body: { callId, reason?: 'declined' | 'missed' }
 *
 * - reason='declined' (default): status='declined', Systemnachricht "Anruf abgelehnt"
 * - reason='missed': status='missed', Systemnachricht "Verpasster Anruf"
 *   (Wird vom IncomingCallScreen-Timeout aufgerufen, da der Callee
 *   /api/dm-calls/missed nicht nutzen kann – das ist Caller-only.)
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
  const reason = body.reason === 'missed' ? 'missed' : 'declined'

  // FIX-32: Nur Callee darf ablehnen – or()-Query erlaubte dem Caller
  // den Call als 'declined' zu markieren statt 'cancelled'.
  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, conversation_id, callee_id, caller_id, status')
    .eq('id', body.callId)
    .eq('callee_id', user.id)  // FIX-32: Nur Empfänger
    .in('status', ['ringing'])  // FIX-32: Nur wenn noch klingelt
    .maybeSingle<DmCallRow>()
  if (!call) return NextResponse.json({ error: 'Anruf nicht gefunden oder nicht berechtigt' }, { status: 404 })

  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: reason,
      ended_at: new Date().toISOString(),
      ended_reason: reason,
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  // FIX-5: Duplikat-Check – verhindert doppelte Systemnachrichten wenn
  // Caller-Timeout und Callee-Decline zeitgleich feuern.
  const { data: existing } = await supabase
    .from('messages')
    .select('id')
    .eq('conversation_id', call.conversation_id)
    .like('content', '%[SYSTEM_CALL]%')
    .gt('created_at', new Date(Date.now() - 10_000).toISOString())
    .limit(1)
  if (!existing?.length) {
    await supabase.from('messages').insert({
      conversation_id: call.conversation_id,
      sender_id: reason === 'missed' ? call.caller_id : call.callee_id,
      content: reason === 'missed'
        ? '[SYSTEM_CALL] 📵 Verpasster Anruf'
        : '[SYSTEM_CALL] 📵 Anruf abgelehnt',
    })
  }

  return NextResponse.json({ success: true })
}
