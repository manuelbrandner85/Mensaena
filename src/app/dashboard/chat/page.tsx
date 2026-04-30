'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import ChatView from '@/components/chat/ChatView'

interface CallSession {
  callId: string
  roomName: string
  token: string
  url: string
  callType: 'audio' | 'video'
}

function ChatPageInner() {
  const [userId, setUserId] = useState<string | null>(null)
  const [nativeCallSession, setNativeCallSession] = useState<CallSession | null>(null)
  // FIX-A: true solange der Accept-Fetch läuft – verhindert DM-Chat-Flash vor dem Anrufscreen
  const [acceptPending, setAcceptPending] = useState(false)
  const searchParams = useSearchParams()
  const convId     = searchParams.get('conv')      // /dashboard/chat?conv=<uuid>
  const callId     = searchParams.get('call')      // call_id from native IncomingCallActivity accept
  const callAction = searchParams.get('action')    // 'accept' | 'decline'
  const callType   = (searchParams.get('type') ?? 'audio') as 'audio' | 'video'

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => {
      if (user) setUserId(user.id)
    })
  }, [])

  // Handle native IncomingCallActivity accept/decline coming via deep-link URL params.
  // Decline: fire-and-forget. Accept: await token so we can open LiveRoomModal directly.
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
            setNativeCallSession({ callId, roomName: data.roomName, token: data.token, url: data.url, callType })
          }
        })
        .catch(() => {})
        .finally(() => setAcceptPending(false))
    }
  }, [callId, callAction, callType])

  if (!userId || acceptPending) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
    </div>
  )

  return (
    <ChatView
      userId={userId}
      initialConvId={convId}
      initialCallId={callId}
      initialCallSession={nativeCallSession}
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
