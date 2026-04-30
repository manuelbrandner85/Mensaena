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

  const { data: existing } = await supabase
    .from('dm_calls')
    .select('id, room_name, status')
    .eq('conversation_id', body.conversationId)
    .in('status', ['ringing', 'active'])
    .maybeSingle<DmCallRow>()
  if (existing) {
    return err.conflict('Bereits ein aktiver Anruf in dieser Konversation')
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

  return NextResponse.json({
    callId: inserted.id,
    roomName: inserted.room_name,
  })
}
