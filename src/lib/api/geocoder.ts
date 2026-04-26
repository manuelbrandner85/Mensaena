// ─────────────────────────────────────────────────────────────────────────────
// Photon Geocoder – Adress-Autovervollständigung (Komoot Public)
// https://photon.komoot.io
//
// Forward:  GET /api/?q={query}&limit=5&lang=de[&lat=&lon=][&layer=]
// Reverse:  GET /reverse?lat={lat}&lon={lon}&lang=de
//
// Kein API-Key. Fair-Use ~5 req/s.
// ─────────────────────────────────────────────────────────────────────────────

// ── Public Types ─────────────────────────────────────────────────────────────

export type GeocodingType =
  | 'house' | 'street' | 'locality' | 'district' | 'city'
  | 'county' | 'state' | 'country'

export interface GeocodingResult {
  id: string
  name: string
  displayName: string
  lat: number
  lng: number
  type: GeocodingType
  country?: string
  state?: string
  city?: string
  postcode?: string
  street?: string
  housenumber?: string
}

export interface GeocoderOptions {
  /** Bevorzugte Region (Location Bias) */
  biasLat?: number
  biasLng?: number
  /** Max. Trefferzahl (1-15, Default 5) */
  limit?: number
  /** Layer-Filter (z. B. ['house', 'street', 'city']) */
  layers?: GeocodingType[]
}

// ── Konstanten ───────────────────────────────────────────────────────────────

const BASE = 'https://photon.komoot.io'
const TIMEOUT_MS = 5_000
const CACHE_LIMIT = 100

// ── Photon-Response-Typen ────────────────────────────────────────────────────

interface PhotonProperties {
  osm_id?: number
  osm_type?: string
  osm_key?: string
  osm_value?: string
  type?: string
  name?: string
  street?: string
  housenumber?: string
  postcode?: string
  city?: string
  district?: string
  county?: string
  state?: string
  country?: string
  countrycode?: string
}

interface PhotonFeature {
  type: 'Feature'
  geometry: { type: 'Point'; coordinates: [number, number] }
  properties: PhotonProperties
}

interface PhotonResponse {
  type?: 'FeatureCollection'
  features?: PhotonFeature[]
}

// ── In-Memory LRU-Cache ──────────────────────────────────────────────────────

const cache = new Map<string, GeocodingResult[]>()

function cacheGet(key: string): GeocodingResult[] | null {
  const v = cache.get(key)
  if (!v) return null
  // Bei Hit ans Ende verschieben (LRU)
  cache.delete(key)
  cache.set(key, v)
  return v
}

function cacheSet(key: string, value: GeocodingResult[]): void {
  if (cache.size >= CACHE_LIMIT) {
    const firstKey = cache.keys().next().value
    if (firstKey !== undefined) cache.delete(firstKey)
  }
  cache.set(key, value)
}

// ── Mapping ──────────────────────────────────────────────────────────────────

function mapType(p: PhotonProperties): GeocodingType {
  const k = (p.osm_key ?? '').toLowerCase()
  const v = (p.type ?? '').toLowerCase()
  if (v === 'house' || k === 'building') return 'house'
  if (v === 'street' || k === 'highway') return 'street'
  if (v === 'city')  return 'city'
  if (v === 'county') return 'county'
  if (v === 'state') return 'state'
  if (v === 'country') return 'country'
  if (v === 'district') return 'district'
  return 'locality'
}

function buildDisplayName(p: PhotonProperties): string {
  const parts: string[] = []
  if (p.name) parts.push(p.name)
  if (p.street && p.housenumber) parts.push(`${p.street} ${p.housenumber}`)
  else if (p.street) parts.push(p.street)
  if (p.postcode && p.city) parts.push(`${p.postcode} ${p.city}`)
  else if (p.city) parts.push(p.city)
  if (p.country) parts.push(p.country)
  return parts.join(', ') || 'Unbekannt'
}

function featureToResult(f: PhotonFeature): GeocodingResult {
  const p = f.properties
  const [lng, lat] = f.geometry.coordinates
  return {
    id: `${p.osm_type ?? '?'}-${p.osm_id ?? 'x'}`,
    name: p.name ?? p.street ?? p.city ?? 'Ergebnis',
    displayName: buildDisplayName(p),
    lat,
    lng,
    type: mapType(p),
    country: p.country,
    state: p.state,
    city: p.city,
    postcode: p.postcode,
    street: p.street,
    housenumber: p.housenumber,
  }
}

async function fetchJson<T>(url: string, signal: AbortSignal): Promise<T> {
  const res = await fetch(url, {
    signal,
    headers: {
      Accept: 'application/json',
      'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
    },
  })
  if (!res.ok) throw new Error(`${url} → ${res.status}`)
  return (await res.json()) as T
}

function withTimeout<T>(p: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  return p(controller.signal).finally(() => clearTimeout(timer))
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Adress-Autovervollständigung. Liefert max. `limit` Treffer mit optional
 * Location Bias (verbessert Relevanz wenn der User-Standort bekannt ist).
 */
export async function searchAddress(
  query: string,
  options: GeocoderOptions = {},
): Promise<GeocodingResult[]> {
  const trimmed = query.trim()
  if (trimmed.length < 3) return []

  const limit = Math.max(1, Math.min(15, options.limit ?? 5))
  const params = new URLSearchParams({
    q: trimmed,
    limit: String(limit),
    lang: 'de',
  })

  if (options.biasLat !== undefined && options.biasLng !== undefined) {
    params.set('lat', String(options.biasLat))
    params.set('lon', String(options.biasLng))
  }

  if (options.layers && options.layers.length > 0) {
    // Photon erwartet kommagetrennte Liste
    params.set('layer', options.layers.join(','))
  }

  const cacheKey = params.toString()
  const cached = cacheGet(cacheKey)
  if (cached) return cached

  try {
    const json = await withTimeout(s =>
      fetchJson<PhotonResponse>(`${BASE}/api/?${cacheKey}`, s),
    )
    const results = (json.features ?? []).map(featureToResult)
    cacheSet(cacheKey, results)
    return results
  } catch {
    return []
  }
}

/**
 * Reverse-Geocoding via Photon. Liefert das nächstgelegene Feature.
 */
export async function reverseGeocode(
  lat: number,
  lng: number,
): Promise<GeocodingResult | null> {
  const params = new URLSearchParams({
    lat: String(lat),
    lon: String(lng),
    lang: 'de',
  })
  const cacheKey = `reverse-${params.toString()}`
  const cached = cacheGet(cacheKey)
  if (cached) return cached[0] ?? null

  try {
    const json = await withTimeout(s =>
      fetchJson<PhotonResponse>(`${BASE}/reverse?${params.toString()}`, s),
    )
    const result = (json.features ?? [])[0]
    if (!result) return null
    const mapped = featureToResult(result)
    cacheSet(cacheKey, [mapped])
    return mapped
  } catch {
    return null
  }
}

/**
 * Formatiert ein Geocoding-Ergebnis als kompakten String.
 */
export function formatAddress(result: GeocodingResult): string {
  return result.displayName
}
