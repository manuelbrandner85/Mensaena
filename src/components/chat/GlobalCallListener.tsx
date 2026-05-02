'use client'

import React, { useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useDndMode } from '@/hooks/useDndMode'
import IncomingCallScreen from './IncomingCallScreen'
import dynamic from 'next/dynamic'

// Lazy-Load LiveRoom (chunk-split)
const LiveRoom = dynamic(() => import('./LiveRoom'), {
  ssr: false,
  loading: () => (
    <div className="fixed inset-0 z-[9999] bg-gray-950 flex items-center justify-center">
      <div className="w-8 h-8 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
    </div>
  ),
})

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

interface IncomingState {
  callId: string
  conversationId: string
  callerId: string
  callerName: string
  callerAvatar: string | null
  callType: 'audio' | 'video'
  roomName: string
}

interface ActiveState {
  callId: string
  roomName: string
  token: string
  url: string
  callType: 'audio' | 'video'
  partnerName: string
  partnerAvatar: string | null
  answeredAt: string
}

export default function GlobalCallListener({ userId }: GlobalCallListenerProps): React.JSX.Element | null {
  const [incoming, setIncoming] = useState<IncomingState | null>(null)
  const [active, setActive] = useState<ActiveState | null>(null)
  const { dnd } = useDndMode()

  // FIX-104: Ref damit dnd.enabled live abgerufen wird (statt useEffect-capture)
  const dndRef = useRef(dnd)
  useEffect(() => { dndRef.current = dnd }, [dnd])

  // Eingehenden Anruf anzeigen (holt Caller-Profil)
  useEffect(() => {
    if (!userId) return
    const supabase = createClient()
    let cancelled = false

    const show = async (row: DmCallRow) => {
      if (cancelled) return
      if (dndRef.current.enabled) {
        await fetch('/api/dm-calls/decline', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: row.id, reason: 'dnd' }),
        }).catch(() => {})
        return
      }
      const { data: caller } = await supabase
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', row.caller_id)
        .maybeSingle<ProfileRow>()
      if (cancelled) return
      setIncoming({
        callId: row.id,
        conversationId: row.conversation_id,
        callerId: row.caller_id,
        callerName: caller?.name ?? 'Unbekannt',
        callerAvatar: caller?.avatar_url ?? null,
        callType: row.call_type,
        roomName: row.room_name,
      })
    }

    // Prüfe auf aktive ringing-Calls beim Start
    void supabase
      .from('dm_calls')
      .select('*')
      .eq('callee_id', userId)
      .eq('status', 'ringing')
      .gt('created_at', new Date(Date.now() - 45_000).toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .returns<DmCallRow[]>()
      .then(({ data }) => { if (data?.[0]) void show(data[0]) })

    // Realtime: neue Calls + Status-Updates
    const channel = supabase
      .channel(`gcl-calls-${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        if (row.status === 'ringing') void show(row)
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        if (row.status !== 'ringing') {
          setIncoming(prev => prev?.callId === row.id ? null : prev)
        }
        const TERMINAL = ['ended', 'declined', 'missed', 'cancelled']
        if (TERMINAL.includes(row.status)) {
          setActive(prev => prev?.callId === row.id ? null : prev)
        }
      })
      .subscribe()

    return () => {
      cancelled = true
      void supabase.removeChannel(channel)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // Nativer IncomingCallKit (Android Fullscreen)
  useEffect(() => {
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean } }
    if (!w.Capacitor?.isNativePlatform()) return
    let cleanups: Array<() => void> = []
    async function init() {
      const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')

      // FIX-100: Permissions nur einmal pro Install anfragen.
      // Wenn bereits granted → nichts tun. Wenn schon mal gefragt + denied →
      // nicht erneut den System-Settings-Dialog aufpoppen lassen.
      try {
        const status = await IncomingCallKit.checkPermissions()
        if (status.notifications !== 'granted') {
          await IncomingCallKit.requestPermissions().catch(() => {})
        }
        if (status.fullScreenIntent !== 'granted') {
          const asked = typeof localStorage !== 'undefined' && localStorage.getItem('fullScreenIntent_asked')
          if (!asked) {
            try { localStorage.setItem('fullScreenIntent_asked', '1') } catch {}
            await IncomingCallKit.requestFullScreenIntentPermission().catch(() => {})
          }
        }
      } catch { /* best effort, blockiert init nicht */ }

      const a = await IncomingCallKit.addListener('callAccepted', async ({ call }) => {
        const supabase = createClient()
        const { data: { session } } = await supabase.auth.getSession()
        const res = await fetch('/api/dm-calls/answer', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {}),
          },
          body: JSON.stringify({ callId: call.callId }),
        })
        if (!res.ok) return
        const data = await res.json() as { token: string; url: string; roomName: string }
        setActive({
          callId: call.callId,
          roomName: data.roomName,
          token: data.token,
          url: data.url,
          callType: (call.extra?.callType as 'audio' | 'video') ?? 'audio',
          partnerName: (call.extra?.callerName as string) ?? 'Unbekannt',
          partnerAvatar: (call.extra?.callerAvatar as string | null) ?? null,
          answeredAt: new Date().toISOString(),
        })
        setIncoming(null)
      })
      cleanups.push(() => { void a.remove() })

      const d = await IncomingCallKit.addListener('callDeclined', async ({ call }) => {
        await fetch('/api/dm-calls/decline', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: call.callId }),
        }).catch(() => {})
        setIncoming(null)
      })
      cleanups.push(() => { void d.remove() })

      const t = await IncomingCallKit.addListener('callTimedOut', ({ call }) => {
        fetch('/api/dm-calls/decline', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: call.callId, reason: 'missed' }),
        }).catch(() => {})
        setIncoming(null)
      })
      cleanups.push(() => { void t.remove() })
    }
    void init()
    return () => { cleanups.forEach(fn => fn()) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  // Native IncomingCallKit anzeigen wenn incoming kommt
  useEffect(() => {
    if (!incoming) return
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean } }
    if (!w.Capacitor?.isNativePlatform()) return
    async function show() {
      const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')
      await IncomingCallKit.showIncomingCall({
        callId: incoming!.callId,
        callerName: incoming!.callerName,
        handle: incoming!.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
        appName: 'Mensaena',
        hasVideo: incoming!.callType === 'video',
        timeoutMs: 45_000,
        extra: {
          conversationId: incoming!.conversationId,
          roomName: incoming!.roomName,
          callType: incoming!.callType,
          callerName: incoming!.callerName,
          callerAvatar: incoming!.callerAvatar ?? null,
        },
        android: {
          channelId: 'mensaena-calls',
          channelName: 'Eingehende Anrufe',
          showFullScreen: true,
          isHighPriority: true,
          accentColor: '#1EAAA6',
        },
        ios: { handleType: 'generic' },
      }).catch(() => {})
    }
    void show()
  }, [incoming])

  // Native IncomingCallKit beenden wenn Call weg
  useEffect(() => {
    if (incoming) return
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean } }
    if (!w.Capacitor?.isNativePlatform()) return
    // Kein callId verfügbar, beende alle
  }, [incoming])

  return (
    <>
      {!active && incoming && (
        <IncomingCallScreen
          callId={incoming.callId}
          conversationId={incoming.conversationId}
          callerName={incoming.callerName}
          callerAvatar={incoming.callerAvatar}
          callType={incoming.callType}
          onAccept={(token, url, roomName) => {
            setActive({
              callId: incoming.callId,
              roomName,
              token,
              url,
              callType: incoming.callType,
              partnerName: incoming.callerName,
              partnerAvatar: incoming.callerAvatar,
              answeredAt: new Date().toISOString(),
            })
            setIncoming(null)
          }}
          onDecline={() => setIncoming(null)}
        />
      )}
      {active && (
        <LiveRoom
          roomName={active.roomName}
          token={active.token}
          serverUrl={active.url}
          title={active.callType === 'video' ? `📹 ${active.partnerName}` : `📞 ${active.partnerName}`}
          isDMCall
          dmCallId={active.callId}
          answeredAt={active.answeredAt}
          partnerName={active.partnerName}
          partnerAvatar={active.partnerAvatar}
          onClose={() => setActive(null)}
        />
      )}
    </>
  )
}
