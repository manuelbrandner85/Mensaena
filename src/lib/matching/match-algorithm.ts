/**
 * Mensaena Match Algorithm
 * Client-side candidate selection and match generation logic.
 * The actual matching is done server-side via RPC (generate_matches_for_post),
 * but this module provides utilities for client-side filtering and sorting.
 */

import { createClient } from '@/lib/supabase/client'
import type { Match, MatchPreferences, MatchCounts, MatchFilter, MatchStatus } from '@/app/dashboard/matching/types'

// ── RPC wrappers ────────────────────────────────────────────────────

/**
 * Trigger match generation for a specific post via RPC.
 * Called automatically by DB trigger, but can also be called manually.
 */
export async function generateMatchesForPost(postId: string): Promise<number> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase as any).rpc('generate_matches_for_post', {
    p_post_id: postId,
  })
  if (error) {
    console.error('[matching] generate failed:', error.message)
    return 0
  }
  return (data as number) ?? 0
}

/**
 * Fetch matches for the current user with pagination.
 */
export async function fetchMyMatches(
  status: MatchFilter = 'all',
  limit = 20,
  offset = 0,
): Promise<Match[]> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase as any).rpc('get_my_matches', {
    p_status: status === 'all' ? null : status,
    p_limit: limit,
    p_offset: offset,
  })

  if (error) {
    console.error('[matching] fetch failed:', error.message)
    return []
  }

  if (!data || !Array.isArray(data)) return []

  // Map flat RPC results to nested Match objects
  return data.map((row: Record<string, unknown>) => ({
    id: row.id as string,
    offer_post_id: row.offer_post_id as string,
    request_post_id: row.request_post_id as string,
    offer_user_id: row.offer_user_id as string,
    request_user_id: row.request_user_id as string,
    match_score: Number(row.match_score) || 0,
    score_breakdown: (row.score_breakdown as Match['score_breakdown']) || {
      category_match: 0, distance_score: 0, trust_score: 0,
      availability_score: 0, activity_score: 0,
    },
    status: row.status as MatchStatus,
    distance_km: row.distance_km != null ? Number(row.distance_km) : null,
    offer_responded: row.offer_responded as boolean,
    request_responded: row.request_responded as boolean,
    offer_accepted: row.offer_accepted as boolean | null,
    request_accepted: row.request_accepted as boolean | null,
    conversation_id: row.conversation_id as string | null,
    seen_by_offer: row.seen_by_offer as boolean,
    seen_by_request: row.seen_by_request as boolean,
    declined_by: row.declined_by as string | null,
    decline_reason: row.decline_reason as string | null,
    expires_at: row.expires_at as string,
    completed_at: row.completed_at as string | null,
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
    offer_post: {
      id: row.offer_post_id as string,
      title: (row.offer_post_title as string) || 'Untitled',
      type: (row.offer_post_type as string) || '',
      category: row.offer_post_category as string | null,
      description: row.offer_post_description as string | null,
      location: row.offer_post_location as string | null,
      urgency: row.offer_post_urgency as string | null,
      media_urls: row.offer_post_media as string[] | null,
    },
    request_post: {
      id: row.request_post_id as string,
      title: (row.request_post_title as string) || 'Untitled',
      type: (row.request_post_type as string) || '',
      category: row.request_post_category as string | null,
      description: row.request_post_description as string | null,
      location: row.request_post_location as string | null,
      urgency: row.request_post_urgency as string | null,
      media_urls: row.request_post_media as string[] | null,
    },
    offer_user: {
      id: row.offer_user_id as string,
      name: row.offer_user_name as string | null,
      avatar_url: row.offer_user_avatar as string | null,
      trust_score: Number(row.offer_user_trust) || 0,
      trust_score_count: Number(row.offer_user_trust_count) || 0,
    },
    request_user: {
      id: row.request_user_id as string,
      name: row.request_user_name as string | null,
      avatar_url: row.request_user_avatar as string | null,
      trust_score: Number(row.request_user_trust) || 0,
      trust_score_count: Number(row.request_user_trust_count) || 0,
    },
  }))
}

/**
 * Respond to a match (accept or decline).
 */
export async function respondToMatch(
  matchId: string,
  accept: boolean,
  declineReason?: string,
): Promise<{ success: boolean; status?: string; conversation_id?: string; error?: string }> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase as any).rpc('respond_to_match', {
    p_match_id: matchId,
    p_accept: accept,
    p_decline_reason: declineReason || null,
  })

  if (error) {
    console.error('[matching] respond failed:', error.message)
    return { success: false, error: error.message }
  }

  const result = data as Record<string, unknown>
  if (result?.error) {
    return { success: false, error: result.error as string }
  }

  return {
    success: true,
    status: result?.status as string,
    conversation_id: result?.conversation_id as string | undefined,
  }
}

/**
 * Fetch match counts for the current user.
 */
export async function fetchMatchCounts(userId?: string): Promise<MatchCounts> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase as any).rpc('get_match_counts', {
    p_user_id: userId || null,
  })

  if (error || !data) {
    return { suggested: 0, pending: 0, accepted: 0, completed: 0 }
  }

  const counts = data as Record<string, number>
  return {
    suggested: counts.suggested ?? 0,
    pending: counts.pending ?? 0,
    accepted: counts.accepted ?? 0,
    completed: counts.completed ?? 0,
  }
}

/**
 * Fetch or create match preferences for the current user.
 */
export async function fetchMatchPreferences(userId: string): Promise<MatchPreferences | null> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase.from('match_preferences') as any)
    .select('*')
    .eq('user_id', userId)
    .single()

  if (error || !data) return null
  return data as MatchPreferences
}

/**
 * Save match preferences (upsert).
 */
export async function saveMatchPreferences(
  userId: string,
  prefs: Partial<MatchPreferences>,
): Promise<boolean> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { error } = await (supabase.from('match_preferences') as any)
    .upsert({
      user_id: userId,
      ...prefs,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })

  if (error) {
    console.error('[matching] save prefs failed:', error.message)
    return false
  }
  return true
}

/**
 * Mark a match as seen by the current user.
 */
export async function markMatchAsSeen(matchId: string, userId: string): Promise<void> {
  const supabase = createClient()
  // We need to determine which side the user is on
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data: match } = await (supabase.from('matches') as any)
    .select('offer_user_id, request_user_id')
    .eq('id', matchId)
    .single()

  if (!match) return

  const isOffer = (match as Record<string, string>).offer_user_id === userId
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  await (supabase.from('matches') as any)
    .update(isOffer ? { seen_by_offer: true } : { seen_by_request: true })
    .eq('id', matchId)
}

/**
 * Trigger cleanup of expired matches.
 */
export async function cleanupExpiredMatches(): Promise<number> {
  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase as any).rpc('cleanup_expired_matches')
  if (error) {
    console.error('[matching] cleanup failed:', error.message)
    return 0
  }
  return (data as number) ?? 0
}
