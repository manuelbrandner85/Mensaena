/**
 * Chat utility functions – extracted from ChatView.tsx
 * to avoid loading the entire heavy ChatView component
 * when only these utility functions are needed.
 */
import { createClient } from '@/lib/supabase/client'

/**
 * Opens an existing DM conversation or creates a new one.
 * Returns the conversation ID or null on error.
 *
 * Fixed: Handles RLS properly - first creates the conversation,
 * then inserts members (so member can then read the conversation).
 */
export async function openOrCreateDM(
  currentUserId: string,
  targetUserId: string,
  postId?: string | null
): Promise<string | null> {
  const supabase = createClient()

  // Step 1: Find existing direct conversation between these two users
  const { data: myMemberships, error: memErr } = await supabase
    .from('conversation_members')
    .select('conversation_id')
    .eq('user_id', currentUserId)

  if (!memErr && myMemberships && myMemberships.length > 0) {
    const myConvIds = myMemberships.map((m: { conversation_id: string }) => m.conversation_id)
    const { data: shared } = await supabase
      .from('conversation_members')
      .select('conversation_id, conversations!inner(type)')
      .eq('user_id', targetUserId)
      .in('conversation_id', myConvIds)
      .eq('conversations.type', 'direct')
    if (shared && shared.length > 0) {
      return (shared[0] as any).conversation_id
    }
  }

  // Step 2: Create new conversation
  const { data: conv, error: convErr } = await supabase
    .from('conversations')
    .insert({ type: 'direct', title: null, post_id: postId ?? null })
    .select('id')
    .single()

  if (convErr || !conv) {
    console.error('openOrCreateDM conv error:', convErr?.message)
    return null
  }

  // Step 3: Insert both members
  const { error: membersErr } = await supabase
    .from('conversation_members')
    .insert([
      { conversation_id: conv.id, user_id: currentUserId },
      { conversation_id: conv.id, user_id: targetUserId },
    ])

  if (membersErr) {
    console.error('openOrCreateDM members error:', membersErr.message)
    // Try to clean up the orphaned conversation
    await supabase.from('conversations').delete().eq('id', conv.id)
    return null
  }

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
