// ─────────────────────────────────────────────────────────────────────────────
// Bildungssuche – Client-Lib (ruft /api/education Proxy auf)
// ─────────────────────────────────────────────────────────────────────────────

// ── Public Types ──────────────────────────────────────────────────────────────

export interface Apprenticeship {
  id:          string
  title:       string
  provider:    string
  city:        string
  plz:         string
  startDate:   string | null
  description: string | null
  url:         string
  type:        'apprenticeship'
}

export interface Course {
  id:          string
  title:       string
  provider:    string
  city:        string
  plz:         string
  startDate:   string | null
  description: string | null
  funded:      boolean
  category:    string | null
  url:         string
  type:        'course'
}

export interface EducationSearchOptions {
  plz:     string
  radius?: number
  query?:  string
  page?:   number
  size?:   number
}

export interface EducationResult<T> {
  items: T[]
  total: number
}

// ── Fetch helpers ─────────────────────────────────────────────────────────────

async function fetchEducation<T>(
  kind: 'apprenticeship' | 'course',
  opts: EducationSearchOptions,
): Promise<EducationResult<T>> {
  const params = new URLSearchParams({ kind, plz: opts.plz })
  if (opts.radius !== undefined) params.set('radius', String(opts.radius))
  if (opts.query)                params.set('query',  opts.query)
  if (opts.page  !== undefined)  params.set('page',   String(opts.page))
  if (opts.size  !== undefined)  params.set('size',   String(opts.size))

  const res = await fetch(`/api/education?${params}`, { cache: 'no-store' })
  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { error?: string }
    throw new Error(err.error ?? `education API error ${res.status}`)
  }
  return res.json() as Promise<EducationResult<T>>
}

// ── Public API ────────────────────────────────────────────────────────────────

export async function searchApprenticeships(
  plz:    string,
  radius = 25,
  opts:   Omit<EducationSearchOptions, 'plz' | 'radius'> = {},
): Promise<EducationResult<Apprenticeship>> {
  return fetchEducation<Apprenticeship>('apprenticeship', { plz, radius, ...opts })
}

export async function searchCourses(
  plz:    string,
  radius = 25,
  opts:   Omit<EducationSearchOptions, 'plz' | 'radius'> = {},
): Promise<EducationResult<Course>> {
  return fetchEducation<Course>('course', { plz, radius, ...opts })
}

// ── Formatters ────────────────────────────────────────────────────────────────

export function formatStartDate(iso: string | null): string {
  if (!iso) return 'Laufend'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}
