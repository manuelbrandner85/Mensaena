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
  const labels: Record<string, string> = {
    help_needed: 'Hilfe gesucht',
    help_offered: 'Hilfe angeboten',
    rescue: 'Retter-Angebot',
    animal: 'Tier',
    housing: 'Wohnen',
    supply: 'Versorgung',
    mobility: 'Mobilität',
    sharing: 'Teilen & Tauschen',
    crisis: 'Notfall',
    community: 'Community',
  }
  return labels[type] || type
}

export function getPostTypeColor(type: string): string {
  const colors: Record<string, string> = {
    help_needed: '#C62828',      // emergency red
    help_offered: '#66BB6A',     // primary green
    rescue: '#FF8F00',           // amber
    animal: '#AB47BC',           // purple
    housing: '#1976D2',          // blue
    supply: '#4CAF50',           // green
    mobility: '#0288D1',         // light blue
    sharing: '#7CB342',          // light green
    crisis: '#C62828',           // red
    community: '#4F6D8A',        // trust blue
  }
  return colors[type] || '#66BB6A'
}

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
