// ─────────────────────────────────────────────────────────────────────────────
// Autobahn App API – Verkehrslage & Baustellen (Bundesfernstraßen)
// https://autobahn.api.bund.dev  ·  Open Data ·  kein API-Key nötig
// ─────────────────────────────────────────────────────────────────────────────

const BASE = 'https://verkehr.autobahn.de/o/autobahn'
const TIMEOUT_MS = 8_000
const CACHE_TTL_MS = 15 * 60 * 1000 // 15 Min

// ── Public types ──────────────────────────────────────────────────────────────

export type WarningType = 'jam' | 'roadwork' | 'closure' | 'hazard' | 'other'

export interface AutobahnWarning {
  identifier: string
  title: string
  subtitle: string
  description: string
  lat: number
  lon: number
  isBlocked: boolean
  type: WarningType
  roadId: string
}

export interface AutobahnRoadwork {
  identifier: string
  title: string
  subtitle: string
  description: string
  lat: number
  lon: number
  roadId: string
}

export interface AutobahnTraffic {
  roadId: string
  warnings: AutobahnWarning[]
  roadworks: AutobahnRoadwork[]
  fetchedAt: number
}

// ── Cache (sessionStorage, 15 min) ───────────────────────────────────────────

interface CacheEntry<T> { data: T; ts: number }

function cacheRead<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* disabled */ }
  return null
}

function cacheWrite<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota */ }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async function fetchJson<T>(path: string): Promise<T | null> {
  try {
    const res = await fetch(`${BASE}${path}`, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
      headers: { Accept: 'application/json' },
    })
    if (!res.ok) return null
    return (await res.json()) as T
  } catch {
    return null
  }
}

function classifyWarning(displayType: string, isBlocked: boolean, title: string): WarningType {
  if (isBlocked) return 'closure'
  const t = (displayType + title).toLowerCase()
  if (t.includes('stau') || t.includes('stocken') || t.includes('langsam')) return 'jam'
  if (t.includes('baustelle') || t.includes('bauarbeiten') || t.includes('roadwork')) return 'roadwork'
  if (t.includes('sperrung') || t.includes('gesperrt') || t.includes('gesperr')) return 'closure'
  if (t.includes('gefahr') || t.includes('glatteis') || t.includes('unfall') || t.includes('hindernis')) return 'hazard'
  return 'other'
}

// ── Raw API response shapes ───────────────────────────────────────────────────

interface RawWarning {
  identifier?: string
  extent?:      string
  point?:       string
  title?:       string
  subtitle?:    string[]
  description?: string[]
  coordinate?:  { lat: string; long: string }
  isBlocked?:   string | boolean
  display_type?: string
}

interface RawRoadwork {
  identifier?: string
  extent?:     string
  point?:      string
  title?:      string
  subtitle?:   string[]
  description?: string[]
  coordinate?: { lat: string; long: string }
}

// ── Fetchers ──────────────────────────────────────────────────────────────────

/**
 * Aktuelle Verkehrsmeldungen (Staus, Sperrungen, Gefahren) für eine Autobahn.
 */
export async function fetchAutobahnWarnings(roadId: string): Promise<AutobahnWarning[]> {
  const id = roadId.toUpperCase()
  const cacheKey = `autobahn_warn_${id}`
  const cached = cacheRead<AutobahnWarning[]>(cacheKey)
  if (cached) return cached

  const json = await fetchJson<{ warning?: RawWarning[] }>(`/${id}/services/warning`)
  if (!json?.warning) { cacheWrite(cacheKey, []); return [] }

  const mapped: AutobahnWarning[] = json.warning
    .filter(w => w.coordinate?.lat && w.coordinate?.long)
    .map(w => {
      const isBlocked = w.isBlocked === true || w.isBlocked === 'true'
      const title     = w.title ?? 'Verkehrsmeldung'
      const subtitle  = Array.isArray(w.subtitle) ? w.subtitle.join(' · ') : ''
      const description = Array.isArray(w.description) ? w.description.join('\n') : ''
      return {
        identifier:  w.identifier ?? `${id}-${Math.random()}`,
        title,
        subtitle,
        description,
        lat:         parseFloat(w.coordinate!.lat),
        lon:         parseFloat(w.coordinate!.long),
        isBlocked,
        type:        classifyWarning(w.display_type ?? '', isBlocked, title),
        roadId:      id,
      }
    })

  cacheWrite(cacheKey, mapped)
  return mapped
}

/**
 * Baustellen für eine Autobahn.
 */
export async function fetchAutobahnRoadworks(roadId: string): Promise<AutobahnRoadwork[]> {
  const id = roadId.toUpperCase()
  const cacheKey = `autobahn_rw_${id}`
  const cached = cacheRead<AutobahnRoadwork[]>(cacheKey)
  if (cached) return cached

  const json = await fetchJson<{ roadworks?: RawRoadwork[] }>(`/${id}/services/roadworks`)
  if (!json?.roadworks) { cacheWrite(cacheKey, []); return [] }

  const mapped: AutobahnRoadwork[] = json.roadworks
    .filter(r => r.coordinate?.lat && r.coordinate?.long)
    .map(r => ({
      identifier:  r.identifier ?? `${id}-rw-${Math.random()}`,
      title:       r.title ?? 'Baustelle',
      subtitle:    Array.isArray(r.subtitle) ? r.subtitle.join(' · ') : '',
      description: Array.isArray(r.description) ? r.description.join('\n') : '',
      lat:         parseFloat(r.coordinate!.lat),
      lon:         parseFloat(r.coordinate!.long),
      roadId:      id,
    }))

  cacheWrite(cacheKey, mapped)
  return mapped
}

/**
 * Alle Warnungen + Baustellen für eine Autobahn in einem Aufruf.
 */
export async function fetchAutobahnTraffic(roadId: string): Promise<AutobahnTraffic> {
  const [warnings, roadworks] = await Promise.all([
    fetchAutobahnWarnings(roadId),
    fetchAutobahnRoadworks(roadId),
  ])
  return { roadId: roadId.toUpperCase(), warnings, roadworks, fetchedAt: Date.now() }
}

// ── Region → Autobahn-Mapping ─────────────────────────────────────────────────

/** Bounding-box: [south, west, north, east] */
type BBox = [number, number, number, number]

interface RegionAutobahns {
  bbox:  BBox
  roads: string[]
}

// Vereinfachtes Mapping: Bundesland/Region → relevante Autobahnen
const REGION_MAP: RegionAutobahns[] = [
  // Bayern
  { bbox: [47.3, 10.0, 49.5, 13.8], roads: ['A8', 'A9', 'A92', 'A93', 'A95', 'A96', 'A99'] },
  // Baden-Württemberg
  { bbox: [47.5, 7.5, 49.8, 10.5], roads: ['A5', 'A6', 'A8', 'A81', 'A98'] },
  // NRW – Rhein/Ruhr
  { bbox: [51.0, 6.0, 52.0, 8.5],  roads: ['A1', 'A2', 'A3', 'A40', 'A43', 'A44', 'A45', 'A46'] },
  // Hessen
  { bbox: [49.5, 7.8, 51.7, 10.2], roads: ['A3', 'A5', 'A7', 'A44', 'A45', 'A66'] },
  // Niedersachsen/Bremen
  { bbox: [51.5, 7.5, 53.9, 11.5], roads: ['A1', 'A2', 'A7', 'A27', 'A30'] },
  // Hamburg/Schleswig-Holstein
  { bbox: [53.4, 8.5, 55.1, 10.9], roads: ['A1', 'A7', 'A23', 'A24', 'A25'] },
  // Berlin/Brandenburg
  { bbox: [51.5, 12.5, 53.5, 14.7], roads: ['A9', 'A10', 'A12', 'A13', 'A24', 'A100', 'A115'] },
  // Sachsen
  { bbox: [50.2, 11.8, 51.7, 15.0], roads: ['A4', 'A9', 'A13', 'A14', 'A17', 'A72'] },
  // Sachsen-Anhalt/Thüringen
  { bbox: [50.5, 10.0, 52.5, 12.7], roads: ['A2', 'A4', 'A9', 'A14', 'A38', 'A71'] },
  // Rheinland-Pfalz/Saarland
  { bbox: [49.0, 6.0, 51.0, 8.5],   roads: ['A1', 'A3', 'A6', 'A48', 'A60', 'A61', 'A62', 'A63'] },
  // Mecklenburg-Vorpommern
  { bbox: [53.3, 10.5, 54.7, 14.5], roads: ['A19', 'A20', 'A24'] },
]

/**
 * Gibt die wahrscheinlichsten Autobahnen für einen Standort zurück (max. 4).
 * Fallback auf die häufigsten Bundesautobahnen wenn keine Region passt.
 */
export function getNearbyAutobahns(lat: number, lon: number): string[] {
  for (const region of REGION_MAP) {
    const [s, w, n, e] = region.bbox
    if (lat >= s && lat <= n && lon >= w && lon <= e) {
      return region.roads.slice(0, 4)
    }
  }
  return ['A1', 'A3', 'A7', 'A9']
}

/** Alle deutschen Autobahnen für die manuelle Auswahl. */
export const ALL_AUTOBAHNS: string[] = [
  'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9',
  'A10', 'A11', 'A12', 'A13', 'A14', 'A15', 'A17', 'A19', 'A20',
  'A21', 'A23', 'A24', 'A25', 'A26', 'A27', 'A28', 'A29', 'A30',
  'A31', 'A33', 'A37', 'A38', 'A39', 'A40', 'A42', 'A43', 'A44',
  'A45', 'A46', 'A48', 'A57', 'A59', 'A60', 'A61', 'A62', 'A63',
  'A64', 'A65', 'A66', 'A67', 'A70', 'A71', 'A72', 'A73', 'A81',
  'A92', 'A93', 'A94', 'A95', 'A96', 'A98', 'A99',
  'A100', 'A103', 'A111', 'A113', 'A114', 'A115',
]
