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
 * RLS-compatible approach:
 *  - conv_select requires is_conversation_member(id, auth.uid()) so
 *    .insert().select().single() fails because the user isn't a member yet.
 *  - Fix: generate UUID client-side so we don't need the RETURNING clause,
 *    then insert current user as member first (passes conversation_members_insert_secure),
 *    then insert target user (passes cm_insert which only needs auth.uid() IS NOT NULL).
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

    // Check each conversation in smaller batches (Supabase has a limit on IN clause size)
    const batchSize = 50
    for (let i = 0; i < myConvIds.length; i += batchSize) {
      const batch = myConvIds.slice(i, i + batchSize)
      const { data: shared } = await supabase
        .from('conversation_members')
        .select('conversation_id, conversations!inner(type)')
        .eq('user_id', targetUserId)
        .in('conversation_id', batch)
        .eq('conversations.type', 'direct')
      if (shared && shared.length > 0) {
        return (shared[0] as any).conversation_id
      }
    }
  }

  // Step 2: Generate UUID client-side to avoid .select() after insert
  // (conv_select RLS blocks RETURNING because user isn't a member yet)
  const convId = crypto.randomUUID()

  // Try with post_id first, fallback without it (FK might fail for deleted posts)
  const insertPayload: Record<string, unknown> = { id: convId, type: 'direct', title: null }
  if (postId) insertPayload.post_id = postId

  let convErr: { message: string; code?: string } | null = null
  const res1 = await supabase.from('conversations').insert(insertPayload)
  if (res1.error) {
    // If post_id caused FK violation, retry without it
    if (postId && (res1.error.code === '23503' || res1.error.message?.includes('foreign key'))) {
      const res2 = await supabase.from('conversations').insert({ id: convId, type: 'direct', title: null })
      convErr = res2.error
    } else {
      convErr = res1.error
    }
  }

  if (convErr) {
    console.error('openOrCreateDM conv error:', convErr.message)
    return null
  }

  // Step 3: Insert current user first (allowed by conversation_members_insert_secure: auth.uid() = user_id)
  const { error: selfErr } = await supabase
    .from('conversation_members')
    .insert({ conversation_id: convId, user_id: currentUserId })

  if (selfErr) {
    console.error('openOrCreateDM self-member error:', selfErr.message)
    await supabase.from('conversations').delete().eq('id', convId)
    return null
  }

  // Step 4: Insert target user (allowed by cm_insert: auth.uid() IS NOT NULL, PERMISSIVE OR)
  const { error: targetErr } = await supabase
    .from('conversation_members')
    .insert({ conversation_id: convId, user_id: targetUserId })

  if (targetErr) {
    console.error('openOrCreateDM target-member error:', targetErr.message)
    // Clean up: remove self membership and conversation
    await supabase.from('conversation_members').delete().eq('conversation_id', convId).eq('user_id', currentUserId)
    await supabase.from('conversations').delete().eq('id', convId)
    return null
  }

  return convId
}

/**
 * Returns the total unread DM message count for a user.
 * Optimiert: zählt nur Nachrichten NACH last_read_at per Query statt alle zu laden.
 */
export async function getUnreadDMCount(userId: string): Promise<number> {
  const supabase = createClient()
  const { data: memberships } = await supabase
    .from('conversation_members')
    .select('conversation_id, last_read_at, conversations!inner(type)')
    .eq('user_id', userId)
    .neq('conversations.type', 'system')

  if (!memberships?.length) return 0

  let total = 0
  // Pro Konversation nur die ungelesenen Nachrichten zählen (nicht alle laden)
  for (const row of memberships as any[]) {
    const lastRead = row.last_read_at || '1970-01-01T00:00:00Z'
    const { count } = await supabase
      .from('messages')
      .select('id', { count: 'exact', head: true })
      .eq('conversation_id', row.conversation_id)
      .neq('sender_id', userId)
      .gt('created_at', lastRead)
      .is('deleted_at', null)
    total += count ?? 0
  }
  return total
}
