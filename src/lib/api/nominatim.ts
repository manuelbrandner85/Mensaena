// ─────────────────────────────────────────────────────────────────────────────
// Nominatim Reverse Geocoding – Koordinaten zu Adresse
// https://nominatim.openstreetmap.org
//
// OSM Nominatim Usage Policy:
// • max. 1 Request pro Sekunde (Singleton-Queue erzwingt das)
// • User-Agent Header zwingend (sonst 403)
// • Caching wird empfohlen → 1 h In-Memory Cache mit Koord-Rundung
// ─────────────────────────────────────────────────────────────────────────────

const ENDPOINT       = 'https://nominatim.openstreetmap.org'
const USER_AGENT     = 'MensaEna/1.0 (https://www.mensaena.de)'
const TIMEOUT_MS     = 8_000
const MIN_INTERVAL_MS = 1_100              // > 1 s, kleiner Sicherheitspuffer
const CACHE_TTL_MS   = 60 * 60 * 1000      // 1 Stunde
const COORD_PRECISION = 3                  // ≈ 110 m Genauigkeit

// ── Public types ──────────────────────────────────────────────────────────────

export interface GeoAddress {
  /** Vollständiger Anzeigename (z.B. "Musterstr. 1, 10115 Berlin") */
  displayName:  string
  street:       string | null
  houseNumber:  string | null
  /** Stadtteil / Ortsteil */
  suburb:       string | null
  /** Stadt / Gemeinde */
  city:         string | null
  postcode:     string | null
  /** Bundesland */
  state:        string | null
  country:      string | null
  /** Original-Koordinaten (Eingabe) */
  lat:          number
  lon:          number
}

// ── Rate-Limiter (Singleton Promise-Chain) ────────────────────────────────────

let queueTail: Promise<unknown> = Promise.resolve()
let lastRequestAt = 0

/**
 * Reiht ein Async-Task ein, sodass zwischen zwei tatsächlichen Requests
 * mindestens MIN_INTERVAL_MS vergehen. Verkettung über einen einzigen
 * Promise-Tail – Reihenfolge bleibt erhalten.
 */
function enqueue<T>(fn: () => Promise<T>): Promise<T> {
  const result = queueTail.then(async () => {
    const wait = MIN_INTERVAL_MS - (Date.now() - lastRequestAt)
    if (wait > 0) await new Promise(r => setTimeout(r, wait))
    lastRequestAt = Date.now()
    return fn()
  })
  // queueTail darf den Fehler nicht propagieren – sonst stoppt die ganze Kette
  queueTail = result.catch(() => undefined)
  return result
}

// ── In-Memory Cache ───────────────────────────────────────────────────────────

interface CacheEntry { data: GeoAddress; ts: number }

const cache = new Map<string, CacheEntry>()

function cacheKey(lat: number, lon: number): string {
  return `${lat.toFixed(COORD_PRECISION)},${lon.toFixed(COORD_PRECISION)}`
}

function cacheGet(lat: number, lon: number): GeoAddress | null {
  const entry = cache.get(cacheKey(lat, lon))
  if (!entry) return null
  if (Date.now() - entry.ts > CACHE_TTL_MS) {
    cache.delete(cacheKey(lat, lon))
    return null
  }
  return entry.data
}

function cacheSet(lat: number, lon: number, data: GeoAddress) {
  // Soft-Limit: max 200 Einträge → bei Überschreitung die ältesten 50 löschen
  if (cache.size >= 200) {
    const oldest = [...cache.entries()]
      .sort((a, b) => a[1].ts - b[1].ts)
      .slice(0, 50)
    for (const [k] of oldest) cache.delete(k)
  }
  cache.set(cacheKey(lat, lon), { data, ts: Date.now() })
}

// ── Response Parsing ──────────────────────────────────────────────────────────

interface NominatimResponse {
  display_name?: string
  address?: {
    road?:          string
    pedestrian?:    string
    footway?:       string
    cycleway?:      string
    house_number?:  string
    suburb?:        string
    neighbourhood?: string
    quarter?:       string
    city_district?: string
    village?:       string
    town?:          string
    city?:          string
    county?:        string
    municipality?:  string
    postcode?:      string
    state?:         string
    country?:       string
  }
}

function parseAddress(json: NominatimResponse, lat: number, lon: number): GeoAddress {
  const a = json.address ?? {}
  return {
    displayName: json.display_name ?? `${lat}, ${lon}`,
    street:      a.road ?? a.pedestrian ?? a.footway ?? a.cycleway ?? null,
    houseNumber: a.house_number ?? null,
    suburb:      a.suburb ?? a.neighbourhood ?? a.quarter ?? a.city_district ?? null,
    city:        a.city ?? a.town ?? a.village ?? a.municipality ?? a.county ?? null,
    postcode:    a.postcode ?? null,
    state:       a.state ?? null,
    country:     a.country ?? null,
    lat,
    lon,
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

export interface ReverseGeocodeOptions {
  /** Detail-Level: 0 (Land) bis 18 (Hausnummer). Default 18. */
  zoom?: number
  /** Cache umgehen (z.B. nach manueller Adressänderung). */
  skipCache?: boolean
}

/**
 * Wandelt Koordinaten in eine strukturierte Adresse um.
 *
 * Wirft niemals – im Fehlerfall enthält das Ergebnis nur `displayName`
 * mit den Roh-Koordinaten und alle anderen Felder sind `null`.
 */
export async function reverseGeocode(
  lat: number,
  lon: number,
  opts: ReverseGeocodeOptions = {},
): Promise<GeoAddress> {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return emptyAddress(lat, lon)
  }

  if (!opts.skipCache) {
    const cached = cacheGet(lat, lon)
    if (cached) return cached
  }

  const zoom = opts.zoom ?? 18
  const url  = `${ENDPOINT}/reverse?lat=${lat}&lon=${lon}`
                + `&format=json&addressdetails=1&accept-language=de&zoom=${zoom}`

  try {
    const data = await enqueue(async () => {
      const res = await fetch(url, {
        signal:  AbortSignal.timeout(TIMEOUT_MS),
        headers: {
          'User-Agent': USER_AGENT,
          'Accept':     'application/json',
        },
      })
      if (!res.ok) throw new Error(`nominatim ${res.status}`)
      return (await res.json()) as NominatimResponse
    })

    const parsed = parseAddress(data, lat, lon)
    cacheSet(lat, lon, parsed)
    return parsed
  } catch {
    return emptyAddress(lat, lon)
  }
}

function emptyAddress(lat: number, lon: number): GeoAddress {
  return {
    displayName: `${lat}, ${lon}`,
    street: null, houseNumber: null, suburb: null, city: null,
    postcode: null, state: null, country: null, lat, lon,
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Kompakte Anzeige: "Straße Nr, PLZ Stadt" – fällt nacheinander auf
 * weniger Felder zurück, wenn Daten fehlen.
 */
export function formatAddressShort(a: GeoAddress): string {
  const line1 = [a.street, a.houseNumber].filter(Boolean).join(' ')
  const line2 = [a.postcode, a.city].filter(Boolean).join(' ')
  if (line1 && line2) return `${line1}, ${line2}`
  if (line2) return line2
  if (line1) return line1
  if (a.suburb && a.city) return `${a.suburb}, ${a.city}`
  return a.city ?? a.displayName
}

/**
 * Privatsphäre-freundliche Anzeige: nur Stadtteil, Stadt, Bundesland –
 * niemals Straße oder Hausnummer.
 */
export function formatAddressPrivacy(a: GeoAddress): string {
  const parts = [a.suburb, a.city, a.state].filter(Boolean)
  return parts.length ? parts.join(', ') : (a.city ?? '')
}

/**
 * Liefert ein Profile-Update-Patch aus einer Adresse: Stadt, PLZ, Bundesland.
 */
export function addressToProfilePatch(a: GeoAddress): {
  city:     string | null
  postcode: string | null
  state:    string | null
  location: string
} {
  return {
    city:     a.city,
    postcode: a.postcode,
    state:    a.state,
    location: formatAddressPrivacy(a),
  }
}
