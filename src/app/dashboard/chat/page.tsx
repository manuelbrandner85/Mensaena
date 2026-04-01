'use client'
export const runtime = 'edge'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import ChatView from '@/components/chat/ChatView'

export default function ChatPage() {
  const [userId, setUserId] = useState<string | null>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) setUserId(user.id)
    })
  }, [])

  if (!userId) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
    </div>
  )

  return <ChatView userId={userId} />
}
