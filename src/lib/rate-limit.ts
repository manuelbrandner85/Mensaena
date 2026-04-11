import { createClient } from '@/lib/supabase/client'

/**
 * Client-side rate-limit check via Supabase RPC `check_rate_limit`.
 * Returns `true` if the action is ALLOWED (under limit).
 * Returns `false` if the user has exceeded the limit (rate-limited).
 *
 * Falls die RPC nicht existiert (z.B. noch nicht deployed), wird `true` zurückgegeben
 * damit das Frontend nicht blockiert.
 *
 * SECURITY NOTE (D1.5): This rate limiter intentionally "fails open" – if the RPC
 * is unavailable or errors out, the action is allowed rather than blocked. This is a
 * design decision to prevent the rate-limit system from becoming a denial-of-service
 * vector against our own users. Server-side RLS policies and Supabase's built-in rate
 * limiting (via GoTrue / PostgREST) provide the authoritative enforcement layer.
 *
 * @param userId  – auth user id
 * @param action  – action identifier, e.g. 'create_post', 'create_board_post', 'send_message', 'create_event'
 * @param maxPerMinute – max actions per minute (default 5)
 * @param maxPerHour   – max actions per hour (default 30)
 */
export async function checkRateLimit(
  userId: string,
  action: string,
  maxPerMinute: number = 5,
  maxPerHour: number = 30,
): Promise<boolean> {
  try {
    const supabase = createClient()
    // Try the DB function signature: check_rate_limit(p_user_id, p_action, p_max_per_hour, p_max_per_minute)
    const { data, error } = await supabase.rpc('check_rate_limit', {
      p_user_id: userId,
      p_action: action,
      p_max_per_hour: maxPerHour,
      p_max_per_minute: maxPerMinute,
    })
    if (error) {
      // RPC doesn't exist or signature mismatch – allow action (fail open)
      return true
    }
    // RPC returns true if under limit (allowed), false if rate-limited
    return !!data
  } catch {
    // Network error etc. – fail open
    return true
  }
}
