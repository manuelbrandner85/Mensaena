import { createClient } from '@/lib/supabase/client'

/**
 * Client-side rate-limit check via Supabase RPC `check_rate_limit`.
 * Returns `true` if the action is ALLOWED (under limit).
 * Returns `false` if the user has exceeded the limit (rate-limited).
 *
 * Falls die RPC nicht existiert (z.B. noch nicht deployed), wird `true` zurückgegeben
 * damit das Frontend nicht blockiert.
 *
 * @param userId  – auth user id
 * @param action  – action identifier, e.g. 'create_post', 'create_board_post', 'send_message', 'create_event'
 * @param max     – max allowed actions within the window (default 10)
 * @param windowMinutes – time window in minutes (default 60)
 */
export async function checkRateLimit(
  userId: string,
  action: string,
  max: number = 10,
  windowMinutes: number = 60,
): Promise<boolean> {
  try {
    const supabase = createClient()
    const { data, error } = await supabase.rpc('check_rate_limit', {
      p_user_id: userId,
      p_action: action,
      p_max_count: max,
      p_window_minutes: windowMinutes,
    })
    if (error) {
      // RPC doesn't exist yet or other error – allow action (fail open)
      console.warn('check_rate_limit RPC error (fail open):', error.message)
      return true
    }
    // RPC returns true if under limit (allowed), false if rate-limited
    return !!data
  } catch {
    // Network error etc. – fail open
    return true
  }
}
