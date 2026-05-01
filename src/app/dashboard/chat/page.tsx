'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import dynamic from 'next/dynamic'
import { createClient } from '@/lib/supabase/client'
import ChatView from '@/components/chat/ChatView'

// Lazy-load LiveRoomModal – wird nur beim nativen Push-Accept gebraucht
const LiveRoomModal = dynamic(() => import('@/components/chat/LiveRoomModal'), { ssr: false })

interface CallSession {
  callId: string
  roomName: string
  token: string
  url: string
  callType: 'audio' | 'video'
  answeredAt: string
}

function ChatPageInner() {
  const [userId, setUserId] = useState<string | null>(null)
  const [userName, setUserName] = useState('Ich')
  const [nativeCallSession, setNativeCallSession] = useState<CallSession | null>(null)
  // true während der Answer-Fetch läuft → Vollbild-Overlay, kein DM-Chat-Flash.
  // Synchron aus URL initialisiert, damit der erste Frame bereits dunkel ist
  // und kein Light-/Dark-Wechsel beim Push-Accept entsteht.
  const [acceptPending, setAcceptPending] = useState(() => {
    if (typeof window === 'undefined') return false
    const sp = new URL(window.location.href).searchParams
    return sp.get('call') !== null && sp.get('action') === 'accept'
  })
  const searchParams = useSearchParams()
  const convId     = searchParams.get('conv')
  const callId     = searchParams.get('call')
  const callAction = searchParams.get('action')
  const callType   = (searchParams.get('type') ?? 'audio') as 'audio' | 'video'

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      setUserId(user.id)
      // Profilname für LiveRoomModal
      void supabase.from('profiles').select('name').eq('id', user.id).maybeSingle()
        .then(({ data }) => { if (data?.name) setUserName(data.name) })
    })
  }, [])

  // Native IncomingCallActivity accept/decline via Deep-Link-URL-Parameter.
  useEffect(() => {
    if (!callId || !callAction) return
    if (callAction === 'decline') {
      void fetch('/api/dm-calls/decline', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      }).catch(() => {})
    } else if (callAction === 'accept') {
      setAcceptPending(true)
      void createClient().auth.getSession().then(({ data: { session } }) => {
        const accessToken = session?.access_token ?? ''
        return fetch('/api/dm-calls/answer', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
          },
          body: JSON.stringify({ callId }),
        })
      })
        .then(r => r.ok ? r.json() : null)
        .then((data: { token: string; url: string; roomName: string } | null) => {
          if (data?.token) {
            setNativeCallSession({
              callId,
              roomName: data.roomName,
              token: data.token,
              url: data.url,
              callType,
              answeredAt: new Date().toISOString(),
            })
          }
        })
        .catch(() => {})
        .finally(() => setAcceptPending(false))
    }
  }, [callId, callAction, callType])

  // ── Render-Logik (WhatsApp-Stil: kein DM-Chat sichtbar während Anruf) ────────

  // 1. Fetch läuft → Vollbild-Ladeschirm
  if (acceptPending) return (
    <div className="fixed inset-0 z-[200] bg-gradient-to-b from-gray-900 via-gray-950 to-black flex flex-col items-center justify-center text-white">
      <div className="flex flex-col items-center gap-4">
        <div className="w-12 h-12 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
        <p className="text-white/80 text-base">Verbindung wird hergestellt…</p>
      </div>
    </div>
  )

  // 2. Anruf aktiv → LiveRoomModal direkt (kein ChatView dahinter → kein Flackern).
  // userId wird hier nicht erzwungen – LiveRoomModal funktioniert auch mit
  // dem Default-Namen, der Profil-Name kommt nach via Re-Render.
  if (nativeCallSession) return (
    <LiveRoomModal
      roomName={nativeCallSession.roomName}
      channelLabel={nativeCallSession.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
      userName={userName}
      preToken={nativeCallSession.token}
      preUrl={nativeCallSession.url}
      dmCallId={nativeCallSession.callId}
      answeredAt={nativeCallSession.answeredAt}
      onClose={() => setNativeCallSession(null)}
    />
  )

  // 3. User-ID noch nicht geladen
  if (!userId) {
    // Im Push-Accept-Pfad denselben dunklen Vollbild-Lader nutzen, damit kein
    // Light-/Dark-Wechsel sichtbar wird, falls der Profil-Fetch hier fertig
    // ist bevor /api/dm-calls/answer zurückkommt.
    if (callAction === 'accept' && callId) return (
      <div className="fixed inset-0 z-[200] bg-gradient-to-b from-gray-900 via-gray-950 to-black flex flex-col items-center justify-center text-white">
        <div className="w-12 h-12 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  // 4. Normal → Chat (initialCallSession=null, weil wir den Call oben direkt handeln)
  return (
    <ChatView
      userId={userId}
      initialConvId={convId}
      initialCallId={callId}
      initialCallSession={null}
      initialTab={convId ? 'dm' : 'community'}
    />
  )
}

export default function ChatPage() {
  return (
    <Suspense fallback={
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    }>
      <ChatPageInner />
    </Suspense>
  )
}
