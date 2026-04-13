/**
 * Notification utilities for Mensaena.
 * Checks user notification preferences, creates notifications,
 * and provides icon/color helpers for the UI.
 */

import { createClient } from '@/lib/supabase/client'
import type { NotificationCategory } from '@/types'

// ── Types ────────────────────────────────────────────────────────────

export type NotificationType =
  | 'message'
  | 'interaction'
  | 'nearby_post'
  | 'trust_rating'
  | 'system'

export interface CreateNotificationParams {
  userId: string
  type: string
  category: NotificationCategory
  title: string
  content: string
  link?: string
  actorId?: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  metadata?: Record<string, any>
}

// ── Preference check ─────────────────────────────────────────────────

const categoryToPreference: Record<string, string> = {
  message: 'notify_new_messages',
  interaction: 'notify_new_interactions',
  post_nearby: 'notify_nearby_posts',
  post_response: 'notify_new_interactions',
  trust_rating: 'notify_trust_ratings',
  system: 'notify_system',
  bot: 'notify_system',
  mention: 'notify_new_interactions',
  welcome: 'notify_system',
  reminder: 'notify_inactivity_reminder',
  comment: 'notify_new_interactions',
}

/**
 * Check whether a user wants to receive a specific notification type.
 */
export async function shouldNotify(
  userId: string,
  type: NotificationType | string,
): Promise<boolean> {
  const supabase = createClient()
  const { data: profile } = await supabase
    .from('profiles')
    .select(
      'notify_new_messages, notify_new_interactions, notify_nearby_posts, notify_trust_ratings, notify_system, notify_inactivity_reminder',
    )
    .eq('id', userId)
    .single()

  if (!profile) return false

  const prefKey = categoryToPreference[type]
  if (!prefKey) return true

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const p = profile as any
  return p[prefKey] ?? true
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
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data as any)?.notify_email ?? false
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
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data as any)?.notify_push ?? false
}

/**
 * Get the notification radius for a user (km).
 */
export async function getNotificationRadius(userId: string): Promise<number> {
  const supabase = createClient()
  const { data } = await supabase
    .from('profiles')
    .select('notification_radius_km')
    .eq('id', userId)
    .single()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (data as any)?.notification_radius_km ?? 10
}

// ── Create notification ──────────────────────────────────────────────

/**
 * Create a notification in the database.
 * Checks shouldNotify first; returns null if user opted out.
 */
export async function createNotification(
  params: CreateNotificationParams,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
): Promise<Record<string, any> | null> {
  const allowed = await shouldNotify(params.userId, params.category)
  if (!allowed) return null

  const supabase = createClient()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data, error } = await (supabase.from('notifications') as any).insert({
    user_id: params.userId,
    type: params.type,
    category: params.category,
    title: params.title,
    content: params.content,
    link: params.link || null,
    actor_id: params.actorId || null,
    metadata: params.metadata || {},
  }).select().single()

  if (error) {
    console.warn('[notifications] create failed:', error.message)
    return null
  }
  return data
}

// ── Format helpers ───────────────────────────────────────────────────

/**
 * Return a Lucide icon name for the given notification category.
 */
export function getNotificationIcon(category: string): string {
  const map: Record<string, string> = {
    message: 'MessageCircle',
    interaction: 'Handshake',
    trust_rating: 'Star',
    post_nearby: 'MapPin',
    post_response: 'MessageSquare',
    system: 'Info',
    bot: 'Bot',
    mention: 'AtSign',
    welcome: 'PartyPopper',
    reminder: 'Clock',
    comment: 'MessageSquareText',
    new_match: 'Sparkles',
    match_partner_accepted: 'UserCheck',
    match_both_accepted: 'Users',
    match_expiring: 'Clock',
  }
  return map[category] || 'Bell'
}

/**
 * Return a Tailwind color name for the given category.
 */
export function getNotificationColor(category: string): string {
  const map: Record<string, string> = {
    message: 'blue',
    interaction: 'primary',
    trust_rating: 'amber',
    post_nearby: 'purple',
    post_response: 'indigo',
    system: 'gray',
    bot: 'primary',
    mention: 'pink',
    welcome: 'primary',
    reminder: 'orange',
    comment: 'blue',
    new_match: 'indigo',
    match_partner_accepted: 'amber',
    match_both_accepted: 'primary',
    match_expiring: 'red',
  }
  return map[category] || 'gray'
}

/**
 * Return a human-readable German label for the category.
 */
export function getNotificationCategoryLabel(category: string): string {
  const map: Record<string, string> = {
    message: 'Nachricht',
    interaction: 'Interaktion',
    trust_rating: 'Bewertung',
    post_nearby: 'In der Nähe',
    post_response: 'Antwort',
    system: 'System',
    bot: 'MensaenaBot',
    mention: 'Erwähnung',
    welcome: 'Willkommen',
    reminder: 'Erinnerung',
    comment: 'Kommentar',
    new_match: 'Neues Match',
    match_partner_accepted: 'Match akzeptiert',
    match_both_accepted: 'Match bestätigt',
    match_expiring: 'Match läuft ab',
  }
  return map[category] || 'Benachrichtigung'
}

/**
 * Format relative time in German.
 */
export function formatRelativeTime(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const minutes = Math.floor(diff / 60000)
  if (minutes < 1) return 'gerade eben'
  if (minutes < 60) return `vor ${minutes} Min.`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `vor ${hours} Std.`
  const days = Math.floor(hours / 24)
  if (days === 1) return 'gestern'
  if (days < 7) return `vor ${days} Tagen`
  if (days < 30) return `vor ${Math.floor(days / 7)} Wochen`
  return new Date(dateStr).toLocaleDateString('de-DE', {
    day: 'numeric',
    month: 'short',
  })
}
