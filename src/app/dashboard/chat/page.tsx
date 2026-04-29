'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import ChatView from '@/components/chat/ChatView'

function ChatPageInner() {
  const [userId, setUserId] = useState<string | null>(null)
  const searchParams = useSearchParams()
  const convId    = searchParams.get('conv')      // /dashboard/chat?conv=<uuid>
  const callId    = searchParams.get('call')      // call_id from push action
  const callAction= searchParams.get('action')    // 'accept' | 'decline'

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => {
      if (user) setUserId(user.id)
    })
  }, [])

  // Handle service-worker push action (accept/decline) coming via URL params.
  // Wichtig: NICHT direkt in dm_calls schreiben (umgeht Auth/RLS-Validierung
  // und schreibt keine Systemnachricht). Stattdessen die offiziellen
  // API-Endpoints nutzen, die die Identität gegen callee_id prüfen.
  useEffect(() => {
    if (!callId || !callAction) return
    if (callAction === 'decline') {
      void fetch('/api/dm-calls/decline', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      }).catch(() => { /* server-seitig wird das aufgeräumt */ })
    } else if (callAction === 'accept') {
      void fetch('/api/dm-calls/answer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      }).catch(() => { /* GlobalCallListener nimmt das Klingeln auf */ })
    }
  }, [callId, callAction])

  if (!userId) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
    </div>
  )

  return <ChatView userId={userId} initialConvId={convId} initialCallId={callId} initialTab={convId ? 'dm' : 'community'} />
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
