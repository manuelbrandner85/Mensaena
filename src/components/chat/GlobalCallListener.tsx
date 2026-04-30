'use client'

import React, { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import { createClient } from '@/lib/supabase/client'
import IncomingCallScreen from './IncomingCallScreen'

const LiveRoomModal = dynamic(() => import('./LiveRoomModal'), { ssr: false })

export interface GlobalCallListenerProps {
  userId: string
}

interface DmCallRow {
  id: string
  conversation_id: string
  caller_id: string
  callee_id: string
  call_type: 'audio' | 'video'
  room_name: string
  status: string
  created_at: string
}

interface ProfileRow {
  name: string | null
  avatar_url: string | null
}

interface IncomingCallState {
  callId: string
  conversationId: string
  callerId: string
  callerName: string
  callerAvatar: string | null
  callType: 'audio' | 'video'
  roomName: string
}

interface ActiveCallState {
  callId: string
  roomName: string
  token: string
  url: string
  callType: 'audio' | 'video'
  partnerName: string
  partnerAvatar: string | null
  userName: string
}

/**
 * Globaler Listener für eingehende DM-Anrufe – muss in jedem Dashboard-Layout
 * gemounted sein damit Anrufe auch ausserhalb der Chat-Seite ankommen.
 *
 * Subscribed nur auf eigene Anrufe (callee_id = userId), zeigt
 * IncomingCallScreen → bei Annahme LiveRoomModal mit pre-geladenem Token.
 */
export default function GlobalCallListener({ userId }: GlobalCallListenerProps): React.JSX.Element | null {
  const [incoming, setIncoming] = useState<IncomingCallState | null>(null)
  const [active,   setActive]   = useState<ActiveCallState | null>(null)
  const [userName, setUserName] = useState<string>('Ich')

  // Auf nativer App (Capacitor APK): IncomingCallActivity ist die einzige
  // Anruf-UI. Realtime-Web-Overlay ausschalten damit kein Doppel-Screen
  // erscheint und Annehmen/Ablehnen einheitlich über die native Aktivität läuft.
  const isNative = typeof document !== 'undefined' && document.documentElement.classList.contains('is-native')

  useEffect(() => {
    if (!userId || isNative) return
    const supabase = createClient()
    void supabase
      .from('profiles').select('name').eq('id', userId).maybeSingle<ProfileRow>()
      .then(({ data }) => { if (data?.name) setUserName(data.name) })
  }, [userId, isNative])

  useEffect(() => {
    if (!userId || isNative) return
    // FIX-4: Single Source Incoming Call – wenn die URL bereits call+action
    // Parameter enthält, verarbeitet ChatPageInner den Push-Accept-Flow.
    // GlobalCallListener würde sonst parallel einen zweiten Screen aufbauen.
    if (typeof window !== 'undefined') {
      const params = new URL(window.location.href).searchParams
      if (params.get('call') && params.get('action')) return
    }
    const supabase = createClient()
    let cancelled = false

    const fetchAndShow = async (row: DmCallRow): Promise<void> => {
      if (cancelled) return
      const { data: caller } = await supabase
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', row.caller_id)
        .maybeSingle<ProfileRow>()
      if (cancelled) return
      setIncoming({
        callId:        row.id,
        conversationId: row.conversation_id,
        callerId:      row.caller_id,
        callerName:    caller?.name ?? 'Unbekannt',
        callerAvatar:  caller?.avatar_url ?? null,
        callType:      row.call_type,
        roomName:      row.room_name,
      })
    }

    void supabase
      .from('dm_calls')
      .select('*')
      .eq('callee_id', userId)
      .eq('status', 'ringing')
      .gt('created_at', new Date(Date.now() - 45_000).toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .returns<DmCallRow[]>()
      .then(({ data }) => { if (data && data[0]) void fetchAndShow(data[0]) })

    const channel = supabase
      .channel(`global-incoming-calls-${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        if (row.status === 'ringing') void fetchAndShow(row)
      })
      // Wenn der Anrufer cancelt / der Call serverseitig endet während
      // wir noch klingeln, müssen wir den IncomingCallScreen schließen.
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        if (row.status !== 'ringing') {
          setIncoming(prev => (prev && prev.callId === row.id ? null : prev))
        }
      })
      .subscribe()

    return () => {
      cancelled = true
      void supabase.removeChannel(channel)
    }
  }, [userId, isNative])

  if (isNative) return null

  if (active) {
    return (
      <LiveRoomModal
        roomName={active.roomName}
        channelLabel={active.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
        userName={userName}
        userAvatar={null}
        preToken={active.token}
        preUrl={active.url}
        dmCallId={active.callId}
        onClose={() => setActive(null)}
      />
    )
  }

  if (incoming) {
    return (
      <IncomingCallScreen
        callerName={incoming.callerName}
        callerAvatar={incoming.callerAvatar}
        callType={incoming.callType}
        callId={incoming.callId}
        conversationId={incoming.conversationId}
        onAccept={(token, url, roomName) => {
          setActive({
            callId:        incoming.callId,
            roomName,
            token,
            url,
            callType:      incoming.callType,
            partnerName:   incoming.callerName,
            partnerAvatar: incoming.callerAvatar,
            userName,
          })
          setIncoming(null)
        }}
        onDecline={() => setIncoming(null)}
      />
    )
  }

  return null
}
