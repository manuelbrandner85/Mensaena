import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

export const runtime = 'nodejs'

interface CancelCallBody {
  callId: string
}

interface DmCallRow {
  id: string
  conversation_id: string
  caller_id: string
  status: string
}

/**
 * POST /api/dm-calls/cancel
 * Anrufer bricht das Klingeln ab (vor Annahme).
 * Body: { callId }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: CancelCallBody
  try {
    body = await req.json() as CancelCallBody
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
  // FIX-31: Cancel bei gleichzeitiger Annahme – prüfe ob Call gerade active wurde
  if (!call) {
    const { data: activeCall } = await supabase
      .from('dm_calls')
      .select('id, conversation_id, caller_id, status')
      .eq('id', body.callId)
      .eq('caller_id', user.id)
      .eq('status', 'active')
      .maybeSingle<DmCallRow>()

    if (activeCall) {
      await supabase.from('dm_calls').update({
        status: 'ended',
        ended_at: new Date().toISOString(),
        ended_reason: 'cancelled',
      }).eq('id', activeCall.id)

      // Duplikat-Check (FIX-5) für Systemnachricht
      const { data: existingMsg } = await supabase.from('messages')
        .select('id')
        .eq('conversation_id', activeCall.conversation_id)
        .like('content', '%[SYSTEM_CALL]%')
        .gt('created_at', new Date(Date.now() - 10_000).toISOString())
        .limit(1)
      if (!existingMsg?.length) {
        // FIX-33: Einheitliche Systemnachricht
        await supabase.from('messages').insert({
          conversation_id: activeCall.conversation_id,
          sender_id: activeCall.caller_id,
          content: '[SYSTEM_CALL] 📵 Anruf abgebrochen',
        })
      }
      return NextResponse.json({ success: true, wasActive: true })
    }

    // Weder ringing noch active → bereits beendet, kein Fehler
    return NextResponse.json({ success: true, alreadyEnded: true })
  }

  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({
      status: 'ended',
      ended_at: new Date().toISOString(),
      ended_reason: 'cancelled',
    })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  await supabase.from('messages').insert({
    conversation_id: call.conversation_id,
    sender_id: call.caller_id,
    content: '[SYSTEM_CALL] 📵 Anruf abgebrochen',
  })

  return NextResponse.json({ success: true })
}
