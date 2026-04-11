/* ═══════════════════════════════════════════════════════════════════════
   SEO  CONSTANTS  &  HELPERS
   Central source of truth for all SEO-related metadata across the app.
   ═══════════════════════════════════════════════════════════════════════ */

// ── Site-wide constants ──────────────────────────────────────────────

export const SITE_URL = 'https://www.mensaena.de'
export const SITE_NAME = 'Mensaena'
export const SITE_DESCRIPTION =
  'Nachbarschaftshilfe neu gedacht. Mensaena verbindet Nachbarn für gegenseitige Hilfe – kostenlos, gemeinnützig und DSGVO-konform.'
export const SITE_LOCALE = 'de_DE'
export const SITE_LANGUAGE = 'de'
export const DEFAULT_OG_IMAGE = '/images/og-default.png' // 1200 × 630
export const TWITTER_HANDLE = '@mensaena'
export const CONTACT_EMAIL = 'info@mensaena.de'

export const SUPABASE_PROJECT_URL =
  'https://huaqldjkgyosefzfhjnf.supabase.co'

// ── Helper functions ─────────────────────────────────────────────────

/**
 * Build a canonical URL.  Strips trailing slashes and query strings.
 */
export function getCanonicalUrl(path = ''): string {
  const clean = path.split('?')[0].replace(/\/+$/, '')
  return `${SITE_URL}${clean.startsWith('/') ? clean : `/${clean}`}`
}

/**
 * Truncate a description to `maxLength` characters, breaking at the last
 * complete word and appending "…".
 */
export function truncateDescription(
  text: string,
  maxLength = 160,
): string {
  if (!text) return ''
  if (text.length <= maxLength) return text
  const trimmed = text.slice(0, maxLength)
  const lastSpace = trimmed.lastIndexOf(' ')
  return (lastSpace > 0 ? trimmed.slice(0, lastSpace) : trimmed) + '…'
}

/**
 * Generate an SEO page title for a post.
 * Format: "PostTitle | Mensaena" (max 60 chars).
 */
export function generatePostTitle(postTitle: string): string {
  const suffix = ` | ${SITE_NAME}`
  const maxTitleLen = 60 - suffix.length
  const title =
    postTitle.length > maxTitleLen
      ? postTitle.slice(0, maxTitleLen - 1) + '…'
      : postTitle
  return `${title}${suffix}`
}

/**
 * Generate an SEO page title for a profile.
 * Format: "Name – Nachbar auf Mensaena" (max 60 chars).
 */
export function generateProfileTitle(name: string): string {
  const suffix = ` – Nachbar auf ${SITE_NAME}`
  const maxNameLen = 60 - suffix.length
  const displayName =
    name.length > maxNameLen ? name.slice(0, maxNameLen - 1) + '…' : name
  return `${displayName}${suffix}`
}

/**
 * Map internal category keys to user-facing German labels.
 */
export function getCategoryLabel(category: string): string {
  const map: Record<string, string> = {
    help_offer: 'Hilfe anbieten',
    help_offered: 'Hilfe anbieten',
    help_request: 'Hilfe suchen',
    help_needed: 'Hilfe suchen',
    tool_lending: 'Werkzeug leihen',
    event: 'Veranstaltung',
    exchange: 'Tausch & Schenk',
    ride: 'Mitfahrgelegenheit',
    crisis: 'Krisenhilfe',
    marketplace: 'Marktplatz',
    knowledge: 'Wissen teilen',
    supply: 'Versorgung',
    animal: 'Tierhilfe',
    housing: 'Wohnen',
    sharing: 'Teilen & Leihen',
    mobility: 'Mobilität',
    community: 'Gemeinschaft',
    rescue: 'Rettung',
    mental: 'Mentale Gesundheit',
  }
  return map[category] ?? category
}
