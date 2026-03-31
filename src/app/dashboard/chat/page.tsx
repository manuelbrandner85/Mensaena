import { createClient } from '@/lib/supabase/server'
import ChatView from '@/components/chat/ChatView'

export default async function ChatPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  return <ChatView userId={user!.id} />
}
