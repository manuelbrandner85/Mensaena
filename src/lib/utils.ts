import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatDate(dateString: string): string {
  const date = new Date(dateString)
  return new Intl.DateTimeFormat('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date)
}

export function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffMins < 1) return 'Gerade eben'
  if (diffMins < 60) return `vor ${diffMins} Min.`
  if (diffHours < 24) return `vor ${diffHours} Std.`
  if (diffDays < 7) return `vor ${diffDays} Tagen`
  return formatDate(dateString)
}

export function getPostTypeLabel(type: string): string {
  return POST_TYPE_META[type]?.label ?? type
}

export function getPostTypeColor(type: string): string {
  return POST_TYPE_META[type]?.color ?? POST_TYPE_META.community.color
}

export function getPostTypeEmoji(type: string): string {
  return POST_TYPE_META[type]?.emoji ?? '📍'
}

// ─── Unified Post-Type Metadata ──────────────────────────────────
// Single source of truth for colors, emojis and labels used by
// the map markers, legend, filter pills and any other UI that
// needs to visually represent a post type. Keep in sync with
// the `post_type` enum in supabase/migrations/001_schema.sql.
export const POST_TYPE_META: Record<
  string,
  { label: string; emoji: string; color: string; tailwind: string }
> = {
  help_needed:  { label: 'Hilfe gesucht',   emoji: '🆘', color: '#DC2626', tailwind: 'bg-red-500' },
  help_offered: { label: 'Hilfe angeboten', emoji: '🤝', color: '#1EAAA6', tailwind: 'bg-primary-500' },
  rescue:       { label: 'Ressourcen',      emoji: '🧡', color: '#F97316', tailwind: 'bg-orange-500' },
  animal:       { label: 'Tiere',           emoji: '🐾', color: '#EC4899', tailwind: 'bg-pink-500' },
  housing:      { label: 'Wohnen',          emoji: '🏡', color: '#3B82F6', tailwind: 'bg-blue-500' },
  supply:       { label: 'Versorgung',      emoji: '🌾', color: '#CA8A04', tailwind: 'bg-yellow-600' },
  mobility:     { label: 'Mobilität',       emoji: '🚗', color: '#6366F1', tailwind: 'bg-indigo-500' },
  sharing:      { label: 'Teilen',          emoji: '🔄', color: '#84CC16', tailwind: 'bg-lime-500' },
  crisis:       { label: 'Notfall',         emoji: '🚨', color: '#BE185D', tailwind: 'bg-rose-700' },
  community:    { label: 'Community',       emoji: '🗳️', color: '#8B5CF6', tailwind: 'bg-violet-500' },
}

export const POST_TYPES = Object.keys(POST_TYPE_META)

export function getUrgencyColor(urgency: string): string {
  const colors: Record<string, string> = {
    low: 'text-green-600 bg-green-50',
    medium: 'text-yellow-600 bg-yellow-50',
    high: 'text-orange-600 bg-orange-50',
    critical: 'text-red-600 bg-red-50',
  }
  return colors[urgency] || 'text-gray-600 bg-gray-50'
}

export function getUrgencyLabel(urgency: string): string {
  const labels: Record<string, string> = {
    low: 'Niedrig',
    medium: 'Mittel',
    high: 'Hoch',
    critical: 'Kritisch',
  }
  return labels[urgency] || urgency
}

/**
 * Strip all non-digit characters from a phone number string,
 * keeping a leading '+' if present.
 */
export function cleanPhone(phone: string): string {
  if (!phone) return ''
  const hasPlus = phone.startsWith('+')
  const digits = phone.replace(/\D/g, '')
  return hasPlus ? `+${digits}` : digits
}

/**
 * Truncate a string to `max` characters, appending '...' if trimmed.
 */
export function truncateText(text: string, max: number): string {
  if (!text || text.length <= max) return text ?? ''
  return text.slice(0, max).trimEnd() + '…'
}
