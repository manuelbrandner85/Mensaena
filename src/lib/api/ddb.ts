// ─────────────────────────────────────────────────────────────────────────────
// Deutsche Digitale Bibliothek (DDB) API – Historische Fotos & Kulturgüter
// https://api.deutsche-digitale-bibliothek.de
//
// Kostenloser API-Key: https://www.deutsche-digitale-bibliothek.de/user/apikey
// ENV: NEXT_PUBLIC_DDB_API_KEY
//
// Daten ändern sich selten → 24h localStorage-Cache.
// ─────────────────────────────────────────────────────────────────────────────

const DDB_API_BASE   = 'https://api.deutsche-digitale-bibliothek.de'
const DDB_PUBLIC_BASE = 'https://www.deutsche-digitale-bibliothek.de'
const TIMEOUT_MS    = 10_000
const CACHE_TTL_MS  = 24 * 60 * 60 * 1000 // 24 Stunden

// ── Public types ──────────────────────────────────────────────────────────────

export type CulturalItemType = 'image' | 'document' | 'audio' | 'video' | 'object' | 'unknown'

export interface CulturalItem {
  id:           string
  title:        string
  subtitle:     string
  thumbnailUrl: string | null
  detailUrl:    string
  type:         CulturalItemType
  /** ISO year (4-digit) wenn aus Datums-Facet ableitbar. */
  year:         number | null
}

// ── Cache ────────────────────────────────────────────────────────────────────

interface CacheEntry<T> { data: T; ts: number }

function lsRead<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < CACHE_TTL_MS) return data
    localStorage.removeItem(key)
  } catch { /* quota or parse */ }
  return null
}

function lsWrite<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try {
    localStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota */ }
}

// ── API key helper ────────────────────────────────────────────────────────────

function getApiKey(): string | null {
  const key = process.env.NEXT_PUBLIC_DDB_API_KEY
  if (!key || key === 'YOUR_DDB_API_KEY' || key.length < 8) return null
  return key
}

// ── Type & URL helpers ────────────────────────────────────────────────────────

function classifyType(raw: unknown): CulturalItemType {
  if (!raw) return 'unknown'
  const arr = Array.isArray(raw) ? raw : [raw]
  const flat = arr.map(v => String(v).toLowerCase()).join(' ')
  if (flat.includes('image') || flat.includes('mediatype_001'))   return 'image'
  if (flat.includes('audio') || flat.includes('mediatype_003'))   return 'audio'
  if (flat.includes('video') || flat.includes('mediatype_002'))   return 'video'
  if (flat.includes('text')  || flat.includes('mediatype_004'))   return 'document'
  if (flat.includes('object') || flat.includes('mediatype_005'))  return 'object'
  return 'unknown'
}

function buildThumbUrl(rawThumb: unknown): string | null {
  if (!rawThumb) return null
  const candidate = Array.isArray(rawThumb) ? rawThumb[0] : rawThumb
  if (typeof candidate !== 'string' || !candidate.trim()) return null
  if (candidate.startsWith('http://') || candidate.startsWith('https://')) return candidate
  // Relative paths (z.B. "/binary/XYZ.jpg") → an API-Host hängen
  if (candidate.startsWith('/')) return `${DDB_API_BASE}${candidate}`
  return `${DDB_API_BASE}/${candidate}`
}

function extractYear(raw: unknown): number | null {
  if (!raw) return null
  const candidate = Array.isArray(raw) ? raw[0] : raw
  if (typeof candidate !== 'string' && typeof candidate !== 'number') return null
  const m = String(candidate).match(/(\d{4})/)
  if (!m) return null
  const n = parseInt(m[1], 10)
  if (n < 1000 || n > new Date().getUTCFullYear() + 1) return null
  return n
}

function pickString(...candidates: unknown[]): string {
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim()) return c.trim()
    if (Array.isArray(c) && c.length > 0 && typeof c[0] === 'string' && c[0].trim()) return c[0].trim()
  }
  return ''
}

// ── Raw API shape (best-effort, DDB schema variiert je Endpoint-Version) ──────

interface RawDdbDoc {
  id?:               string
  edm_datasetname?:  string
  label?:            string | string[]
  title?:            string | string[]
  subtitle?:         string | string[]
  view_thumbnail?:   string | string[]
  preview?:          string | string[] | { thumbnail?: string }
  thumbnail?:        string | string[]
  media_type?:       string | string[]
  category?:         string | string[]
  type?:             string | string[]
  date?:             string | string[]
  begin_time?:       string | string[]
}

interface RawDdbSearchResponse {
  results?: { docs?: RawDdbDoc[] }[]
  // Manche Endpunkte liefern direkt eine Items-Liste:
  numberOfResults?: number
}

// ── Search ────────────────────────────────────────────────────────────────────

async function runSearch(params: URLSearchParams): Promise<RawDdbDoc[]> {
  const apiKey = getApiKey()
  if (!apiKey) return []
  params.set('oauth_consumer_key', apiKey)

  try {
    const url = `${DDB_API_BASE}/search?${params.toString()}`
    const res = await fetch(url, {
      signal:  AbortSignal.timeout(TIMEOUT_MS),
      headers: { Accept: 'application/json' },
    })
    if (!res.ok) return []
    const json = (await res.json()) as RawDdbSearchResponse
    const docs = json.results?.[0]?.docs ?? []
    return Array.isArray(docs) ? docs : []
  } catch {
    return []
  }
}

function mapDoc(doc: RawDdbDoc): CulturalItem | null {
  const id = doc.id?.trim()
  if (!id) return null

  const title = pickString(doc.title, doc.label)
  if (!title) return null

  // Thumbnail kann an diversen Stellen liegen
  const previewObj = (typeof doc.preview === 'object' && !Array.isArray(doc.preview))
    ? doc.preview
    : null
  const rawThumb =
    previewObj?.thumbnail ??
    doc.view_thumbnail ??
    doc.thumbnail ??
    (typeof doc.preview === 'string' ? doc.preview : Array.isArray(doc.preview) ? doc.preview : null)

  return {
    id,
    title,
    subtitle:     pickString(doc.subtitle, doc.edm_datasetname),
    thumbnailUrl: buildThumbUrl(rawThumb),
    detailUrl:    `${DDB_PUBLIC_BASE}/item/${encodeURIComponent(id)}`,
    type:         classifyType(doc.media_type ?? doc.category ?? doc.type),
    year:         extractYear(doc.begin_time ?? doc.date),
  }
}

/**
 * Sucht Kulturgüter (Bilder, Dokumente, Objekte) zur Region des Users.
 * Standardmäßig nur Bild-Treffer – nutze `mediaType: 'all'` für andere Typen.
 */
export async function searchCulturalItems(
  query: string,
  limit = 8,
  options: { year?: number; mediaType?: 'image' | 'all' } = {},
): Promise<CulturalItem[]> {
  const q = query.trim()
  if (!q) return []

  const mediaType = options.mediaType ?? 'image'
  const cacheKey  = `ddb_search_${q.toLowerCase().replace(/\s+/g, '_')}_${limit}_${mediaType}_${options.year ?? 'any'}`

  const cached = lsRead<CulturalItem[]>(cacheKey)
  if (cached) return cached

  const params = new URLSearchParams({
    query: q,
    rows:  String(limit),
  })
  if (mediaType === 'image') {
    // Bilder priorisieren via Facet-Filter
    params.append('facet', 'media_type')
    params.append('media_type', 'mediatype_001')
  }
  if (options.year != null) {
    params.append('facet', 'time_fct')
    params.append('time_fct', `time_${options.year}`)
  }

  const docs  = await runSearch(params)
  const items = docs.map(mapDoc).filter((x): x is CulturalItem => x !== null)

  lsWrite(cacheKey, items)
  return items
}

/**
 * "Heute vor 100 Jahren" – Treffer aus dem Jahr (currentYear - yearsAgo).
 * Fällt auf eine Toleranz von ±2 Jahren zurück, falls das Ziel-Jahr leer ist.
 */
export async function searchHistoricalItems(
  query: string,
  yearsAgo = 100,
  limit = 6,
): Promise<{ year: number; items: CulturalItem[] }> {
  const target = new Date().getUTCFullYear() - yearsAgo

  // Erste Runde: exakt das Zieljahr
  let items = await searchCulturalItems(query, limit, { year: target, mediaType: 'image' })

  // Fallback: ohne Jahresfilter, dann clientseitig nach Jahr ±5 sortieren
  if (items.length === 0) {
    const broad = await searchCulturalItems(query, limit * 2, { mediaType: 'image' })
    items = broad
      .filter(i => i.year != null && Math.abs(i.year - target) <= 5)
      .slice(0, limit)
  }

  return { year: target, items }
}

/**
 * Liefert eine direkte URL zur DDB-Detailseite eines Items.
 */
export function getDdbDetailUrl(id: string): string {
  return `${DDB_PUBLIC_BASE}/item/${encodeURIComponent(id)}`
}

/**
 * Prüft ob ein API-Key konfiguriert ist (für Feature-Toggle in der UI).
 */
export function isDdbConfigured(): boolean {
  return getApiKey() !== null
}
