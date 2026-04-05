/**
 * Notification utilities for Mensaena.
 * Checks user notification preferences before sending notifications.
 */

import { createClient } from '@/lib/supabase/client'

export type NotificationType = 'message' | 'interaction' | 'nearby_post' | 'trust_rating' | 'system'

/**
 * Check whether a user wants to receive a specific notification type.
 * Reads the user's notification preferences from the profiles table.
 *
 * @param userId  - The user ID to check
 * @param type    - The notification type
 * @returns true if the user should be notified, false otherwise
 */
export async function shouldNotify(
  userId: string,
  type: NotificationType
): Promise<boolean> {
  const supabase = createClient()

  const { data: profile } = await supabase
    .from('profiles')
    .select('notify_new_messages, notify_new_interactions, notify_nearby_posts, notify_trust_ratings, notify_system')
    .eq('id', userId)
    .single()

  if (!profile) return false

  const mapping: Record<NotificationType, boolean> = {
    message: profile.notify_new_messages ?? true,
    interaction: profile.notify_new_interactions ?? true,
    nearby_post: profile.notify_nearby_posts ?? true,
    trust_rating: profile.notify_trust_ratings ?? true,
    system: profile.notify_system ?? true,
  }

  return mapping[type] ?? true
}

/**
 * Check whether a user wants email notifications.
 */
export async function shouldNotifyEmail(userId: string): Promise<boolean> {
  const supabase = createClient()
  const { data } = await supabase
    .from('profiles')
    .select('notify_email')
    .eq('id', userId)
    .single()
  return data?.notify_email ?? false
}

/**
 * Check whether a user wants push notifications.
 */
export async function shouldNotifyPush(userId: string): Promise<boolean> {
  const supabase = createClient()
  const { data } = await supabase
    .from('profiles')
    .select('notify_push')
    .eq('id', userId)
    .single()
  return data?.notify_push ?? false
}

/**
 * Get the notification radius for a user (km).
 * Used for "nearby posts" notifications.
 */
export async function getNotificationRadius(userId: string): Promise<number> {
  const supabase = createClient()
  const { data } = await supabase
    .from('profiles')
    .select('notification_radius_km')
    .eq('id', userId)
    .single()
  return data?.notification_radius_km ?? 10
}
