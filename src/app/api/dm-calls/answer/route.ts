import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { generateLiveKitToken } from '@/lib/livekit/token'

export const runtime = 'edge'

interface AnswerCallBody {
  callId: string
}

interface DmCallRow {
  id: string
  room_name: string
  status: string
  callee_id: string
  caller_id: string
}

interface ProfileRow {
  name: string | null
}

/**
 * POST /api/dm-calls/answer
 * Empfänger nimmt den Anruf an. Setzt status='active' und liefert LiveKit-Token.
 * Body: { callId }
 * Response: { token, url, roomName }
 */
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: AnswerCallBody
  try {
    body = await req.json() as AnswerCallBody
  } catch {
    return err.bad('Ungültiger Body')
  }
  if (!body.callId) return err.bad('callId fehlt')

  const { data: call } = await supabase
    .from('dm_calls')
    .select('id, room_name, status, callee_id, caller_id')
    .eq('id', body.callId)
    .eq('callee_id', user.id)
    .eq('status', 'ringing')
    .maybeSingle<DmCallRow>()
  if (!call) return err.notFound('Anruf nicht gefunden oder nicht mehr aktiv')

  const { error: updateErr } = await supabase
    .from('dm_calls')
    .update({ status: 'active', answered_at: new Date().toISOString() })
    .eq('id', call.id)
  if (updateErr) return err.internal(updateErr.message)

  const { data: profile } = await supabase
    .from('profiles')
    .select('name')
    .eq('id', user.id)
    .maybeSingle<ProfileRow>()

  // Wenn die Token-Generierung scheitert, ist die Row schon auf 'active'.
  // Ohne Rollback bleibt der Callee in einem kaputten Zustand fest und kann
  // den Anruf weder annehmen noch ablehnen. Daher beenden wir die Row
  // mit ended_reason='error' und liefern 500.
  try {
    const result = await generateLiveKitToken({
      roomName: call.room_name,
      identity: user.id,
      displayName: profile?.name ?? 'Mitglied',
    })
    return NextResponse.json(result)
  } catch (tokenErr) {
    await supabase
      .from('dm_calls')
      .update({
        status: 'ended',
        ended_at: new Date().toISOString(),
        ended_reason: 'error',
      })
      .eq('id', call.id)
    const message = tokenErr instanceof Error ? tokenErr.message : 'Token-Fehler'
    return err.internal(`LiveKit-Token konnte nicht erstellt werden: ${message}`)
  }
}
