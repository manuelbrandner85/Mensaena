'use client'

import React, { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import dynamic from 'next/dynamic'
import { usePathname } from 'next/navigation'
import { Phone } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useDndMode } from '@/hooks/useDndMode' // FEATURE: DND-Modus
import IncomingCallScreen from './IncomingCallScreen'
import {
  startCallForegroundService,
  stopCallForegroundService,
} from '@/hooks/useCallForegroundService' // FIX-43: Foreground Service
// FEATURE: WhatsApp-Style Call – Nativer Incoming-Call-Screen
import {
  useNativeIncomingCall,
  showNativeIncomingCall,
  endNativeIncomingCall,
} from '@/hooks/useNativeIncomingCall'
import toast from 'react-hot-toast'

// FEATURE: Lazy-Load LiveRoomModal
const LiveRoomModal = dynamic(() => import('./LiveRoomModal'), {
  ssr: false,
  loading: () => (
    <div className="fixed inset-0 z-[9999] bg-gray-900 flex items-center justify-center">
      <div className="flex flex-col items-center gap-3">
        <div className="w-8 h-8 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
        <p className="text-white/60 text-sm">Wird geladen…</p>
      </div>
    </div>
  ),
})

// FIX-76: Chunk vorladen damit beim Call-Accept kein Spinner erscheint
if (typeof window !== 'undefined') {
  void import('./LiveRoomModal')
}

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
  answeredAt: string // FIX-10: Timer ab answered_at
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
  // FEATURE: DND-Modus
  const { dnd } = useDndMode()
  // FEATURE: Call-Banner — Modal bei Navigation verbergen, Call bleibt aktiv
  const [showLiveRoom, setShowLiveRoom] = useState(true)
  const activeRef = useRef(active)
  // FIX-76: Zeitpunkt merken für pathname-Guard
  const callStartedAtRef = useRef<number>(0)
  useEffect(() => {
    activeRef.current = active
    if (active) callStartedAtRef.current = Date.now()
  }, [active])
  // Reset showLiveRoom wenn Call endet
  useEffect(() => { if (!active) setShowLiveRoom(true) }, [active])

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

  // FIX-43: Foreground Service bei aktivem Anruf (GlobalCallListener-Seite)
  useEffect(() => {
    if (!active) return
    void startCallForegroundService({
      partnerName: active.partnerName ?? 'Anruf',
      callType: active.callType,
      onHangupFromNotification: () => {
        fetch('/api/dm-calls/end', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: active.callId }),
        }).catch(() => {})
        setActive(null)
      },
    })
    return () => { void stopCallForegroundService() }
  }, [active])

  // FIX-78: Push-Notification IMMER schließen wenn incoming sich ändert
  // incoming !== null → Fullscreen-UI da, Push überflüssig
  // incoming === null → Anruf vorbei, Push aufräumen
  useEffect(() => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then(reg => {
        reg.getNotifications({ tag: 'incoming-call' }).then(ns => {
          ns.forEach(n => n.close())
        })
        reg.getNotifications().then(ns => {
          ns.filter(n => n.data?.type === 'incoming_call')
            .forEach(n => n.close())
        })
      }).catch(() => {})
    }
  }, [incoming])

  // FEATURE: Call-Banner — bei Navigation LiveRoom verbergen statt Call beenden
  const pathname = usePathname()
  const isFirstRender = useRef(true)
  // FIX-76: Pathname-Änderungen in den ersten 5s nach Call-Start ignorieren
  // (App-Start über Push ändert pathname mehrfach bevor alles stabil ist)
  useEffect(() => {
    if (isFirstRender.current) { isFirstRender.current = false; return }
    if (!activeRef.current) return
    const elapsed = Date.now() - callStartedAtRef.current
    if (elapsed < 5000) return
    setShowLiveRoom(false)
  }, [pathname])

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
      // FEATURE: DND-Modus — automatisch ablehnen ohne zu klingeln
      if (dnd.enabled) {
        void fetch('/api/dm-calls/decline', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: row.id, reason: 'dnd' }),
        }).catch(() => {})
        return
      }
      // FIX-18: AudioContext vorbereiten wenn Push-Notification Fokus gegeben hat
      try {
        const AC = window.AudioContext || (window as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
        if (AC) {
          const tempCtx = new AC()
          await tempCtx.resume()
          void tempCtx.close()
        }
      } catch { /* ignore – kein User-Gesture vorhanden, Vibration-Fallback greift */ }
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
      // FIX-78: Push-Notification sofort schließen wenn Fullscreen-UI kommt
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.ready.then(reg => {
          reg.getNotifications({ tag: 'incoming-call' }).then(ns => {
            ns.forEach(n => n.close())
          })
          reg.getNotifications().then(ns => {
            ns.filter(n => n.data?.type === 'incoming_call')
              .forEach(n => n.close())
          })
        }).catch(() => {})
      }
      // FEATURE: WhatsApp-Style Call – Nativen Screen parallel zum Web-Screen zeigen
      void showNativeIncomingCall({
        callId:         row.id,
        callerName:     caller?.name ?? 'Unbekannt',
        callerAvatar:   caller?.avatar_url,
        callType:       row.call_type,
        conversationId: row.conversation_id,
        roomName:       row.room_name,
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
      // FIX-89: ZWEI UPDATE-Listener nötig – einer für Callee, einer für Caller.
      // Vorher feuerte nur der callee_id-Filter → der Caller bekam terminale
      // Stati nicht mit wenn er außerhalb von ChatView war (z.B. Notifications-
      // Page) → activeDMCallSession hing → LiveKit-Reconnect-Loop → 30-40s-Drop.
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        if (row.status !== 'ringing') {
          setIncoming(prev => (prev && prev.callId === row.id ? null : prev))
          // FEATURE: WhatsApp-Style Call – Nativen Screen beenden
          void endNativeIncomingCall(row.id)
        }
        const TERMINAL = ['ended', 'declined', 'missed', 'cancelled']
        if (TERMINAL.includes(row.status)) {
          setActive(prev => (prev && prev.callId === row.id ? null : prev))
        }
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `caller_id=eq.${userId}`,
      }, (payload) => {
        const row = payload.new as DmCallRow
        const TERMINAL = ['ended', 'declined', 'missed', 'cancelled']
        if (TERMINAL.includes(row.status)) {
          setActive(prev => (prev && prev.callId === row.id ? null : prev))
        }
      })
      .subscribe()

    return () => {
      cancelled = true
      void supabase.removeChannel(channel)
    }
  }, [userId, isNative])

  // ── FEATURE: WhatsApp-Style Call – Nativer Anruf-Screen (Capacitor APK) ──
  useNativeIncomingCall({
    userId,
    onAccept: async (callId, extra) => {
      try {
        const supabase = createClient()
        const { data: { session } } = await supabase.auth.getSession()
        const authToken = session?.access_token ?? ''
        const res = await fetch('/api/dm-calls/answer', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(authToken ? { Authorization: `Bearer ${authToken}` } : {}),
          },
          body: JSON.stringify({ callId }),
        })
        if (!res.ok) throw new Error('Answer fehlgeschlagen')
        const data = await res.json() as { roomName: string; token: string; url: string }
        // FIX-80: Batching statt rAF – kein Frame ohne UI mehr
        setActive({
          callId,
          roomName:      data.roomName,
          token:         data.token,
          url:           data.url,
          callType:      (extra.callType as 'audio' | 'video') ?? 'audio',
          partnerName:   (extra.callerName as string) ?? 'Unbekannt',
          partnerAvatar: (extra.callerAvatar as string | null) ?? null,
          userName,
          answeredAt:    new Date().toISOString(),
        })
        setIncoming(null)
      } catch {
        toast.error('Anruf konnte nicht angenommen werden')
      }
    },
    onDecline: async (callId) => {
      await fetch('/api/dm-calls/decline', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      }).catch(() => {})
      setIncoming(null)
    },
  })

  if (isNative) return null

  return (
    <>
      {/* FEATURE: Call-Banner — sichtbar wenn User während eines Anrufs navigiert */}
      {active && !showLiveRoom && typeof document !== 'undefined' && createPortal(
        <div
          className="fixed top-0 inset-x-0 z-[150] bg-green-500 text-white text-center text-sm font-medium flex items-center justify-center gap-2 cursor-pointer active:bg-green-600"
          style={{ paddingTop: 'max(env(safe-area-inset-top, 0px), 8px)', paddingBottom: '8px' }}
          onClick={() => setShowLiveRoom(true)}
          role="button"
          aria-label="Zurück zum Anruf"
        >
          <Phone className="w-4 h-4 animate-pulse" />
          Anruf läuft — Tippe zum Zurückkehren
        </div>,
        document.body,
      )}

      {/* FEATURE: Call-Banner — Modal nur anzeigen wenn showLiveRoom */}
      {active && showLiveRoom && (
        <LiveRoomModal
          roomName={active.roomName}
          channelLabel={active.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
          userName={userName}
          userAvatar={null}
          preToken={active.token}
          preUrl={active.url}
          dmCallId={active.callId}
          answeredAt={active.answeredAt}
          onClose={() => {
            setActive(null)
            setShowLiveRoom(true) // Reset für nächsten Call
          }}
        />
      )}

      {!active && incoming && (
        <IncomingCallScreen
          callerName={incoming.callerName}
          callerAvatar={incoming.callerAvatar}
          callType={incoming.callType}
          callId={incoming.callId}
          conversationId={incoming.conversationId}
          onAccept={(token, url, roomName) => {
            // FIX-80: Beide State-Updates in einem Render (React-18-Batching).
            // Vorher rAF → Frame-Lücke zwischen Unmount IncomingCallScreen
            // und Mount LiveRoomModal → sichtbares Flackern.
            const snap = incoming
            setActive({
              callId:        snap.callId,
              roomName,
              token,
              url,
              callType:      snap.callType,
              partnerName:   snap.callerName,
              partnerAvatar: snap.callerAvatar,
              userName,
              answeredAt:    new Date().toISOString(),
            })
            setIncoming(null)
          }}
          onDecline={() => setIncoming(null)}
        />
      )}
    </>
  )
}
