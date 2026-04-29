'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import ChatView from '@/components/chat/ChatView'

function MessagesPageInner() {
  const [userId, setUserId] = useState<string | null>(null)
  const searchParams = useSearchParams()
  const convId = searchParams.get('conv')
  const router = useRouter()

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => {
      if (user) {
        setUserId(user.id)
      } else {
        router.replace('/auth?redirect=/dashboard/messages')
      }
    })
  }, [router])

  if (!userId) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
    </div>
  )

  return <ChatView userId={userId} initialConvId={convId} initialTab="dm" />
}

export default function MessagesPage() {
  return (
    <Suspense fallback={
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    }>
      <MessagesPageInner />
    </Suspense>
  )
}
