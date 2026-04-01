/**
 * Chat utility functions – extracted from ChatView.tsx
 * to avoid loading the entire heavy ChatView component
 * when only these utility functions are needed.
 */
import { createClient } from '@/lib/supabase/client'

/**
 * Opens an existing DM conversation or creates a new one.
 * Returns the conversation ID or null on error.
 */
export async function openOrCreateDM(
  currentUserId: string,
  targetUserId: string,
  postId?: string | null
): Promise<string | null> {
  const supabase = createClient()
  const { data: myMemberships } = await supabase
    .from('conversation_members').select('conversation_id').eq('user_id', currentUserId)

  if (myMemberships && myMemberships.length > 0) {
    const myConvIds = myMemberships.map((m: { conversation_id: string }) => m.conversation_id)
    const { data: shared } = await supabase
      .from('conversation_members').select('conversation_id, conversations(type)')
      .eq('user_id', targetUserId).in('conversation_id', myConvIds)
    if (shared) {
      const direct = (shared as any[]).find(s => s.conversations?.type === 'direct')
      if (direct) return direct.conversation_id
    }
  }

  const { data: conv, error } = await supabase
    .from('conversations').insert({ type: 'direct', title: null, post_id: postId ?? null }).select().single()
  if (error || !conv) return null

  await supabase.from('conversation_members').insert([
    { conversation_id: conv.id, user_id: currentUserId },
    { conversation_id: conv.id, user_id: targetUserId },
  ])
  return conv.id
}

/**
 * Returns the total unread DM message count for a user.
 */
export async function getUnreadDMCount(userId: string): Promise<number> {
  const supabase = createClient()
  const { data } = await supabase
    .from('conversation_members')
    .select('conversation_id, last_read_at, conversations(id, type, messages(id, created_at, sender_id))')
    .eq('user_id', userId)
  if (!data) return 0
  let total = 0
  for (const row of data as any[]) {
    const c = row.conversations
    if (!c || c.type === 'system') continue
    const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
    const msgs: any[] = c.messages ?? []
    total += msgs.filter((m: any) => m.sender_id !== userId && new Date(m.created_at).getTime() > lastRead).length
  }
  return total
}
