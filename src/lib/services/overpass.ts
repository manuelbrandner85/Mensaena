/**
 * Overpass API integration for public map layers (defibrillators, pharmacies, etc.).
 * Caches responses per bbox + layer in localStorage with a 1h TTL.
 */

export type OverpassLayer =
  | 'defibrillator'
  | 'pharmacy'
  | 'playground'
  | 'drinking_water'
  | 'public_bookcase'

export interface OverpassPoint {
  id: string
  lat: number
  lng: number
  name?: string
  tags: Record<string, string>
}

interface LayerMeta {
  label: string
  emoji: string
  color: string
  /** Overpass tag filter (e.g. 'emergency=defibrillator') */
  filter: string
  /** Include OSM ways as well (for areas like playgrounds) */
  includeWays?: boolean
}

export const LAYER_META: Record<OverpassLayer, LayerMeta> = {
  defibrillator: {
    label: 'Defibrillatoren',
    emoji: '❤️',
    color: '#DC2626',
    filter: 'emergency=defibrillator',
  },
  pharmacy: {
    label: 'Apotheken',
    emoji: '💊',
    color: '#16A34A',
    filter: 'amenity=pharmacy',
  },
  playground: {
    label: 'Spielplätze',
    emoji: '🛝',
    color: '#F59E0B',
    filter: 'leisure=playground',
    includeWays: true,
  },
  drinking_water: {
    label: 'Trinkbrunnen',
    emoji: '💧',
    color: '#2563EB',
    filter: 'amenity=drinking_water',
  },
  public_bookcase: {
    label: 'Bücherschränke',
    emoji: '📚',
    color: '#7C3AED',
    filter: 'amenity=public_bookcase',
  },
}

export const OVERPASS_LAYERS: OverpassLayer[] = Object.keys(LAYER_META) as OverpassLayer[]

// ── Cache ────────────────────────────────────────────────────────────────────

const CACHE_TTL = 60 * 60 * 1000 // 1h
const CACHE_PREFIX = 'mensaena_overpass_'

export type Bbox = readonly [south: number, west: number, north: number, east: number]

/** Round bbox to 0.05° so small pans reuse the cache entry. */
function cacheKey(layer: OverpassLayer, bbox: Bbox): string {
  const r = (n: number) => Math.round(n * 20) / 20
  return `${CACHE_PREFIX}${layer}_${r(bbox[0])}_${r(bbox[1])}_${r(bbox[2])}_${r(bbox[3])}`
}

function readCache(key: string): OverpassPoint[] | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { data: OverpassPoint[]; timestamp: number }
    if (Date.now() - parsed.timestamp > CACHE_TTL) {
      localStorage.removeItem(key)
      return null
    }
    return parsed.data
  } catch {
    return null
  }
}

function writeCache(key: string, data: OverpassPoint[]) {
  if (typeof window === 'undefined') return
  try {
    localStorage.setItem(key, JSON.stringify({ data, timestamp: Date.now() }))
  } catch { /* quota exceeded – skip */ }
}

// ── Fetcher ──────────────────────────────────────────────────────────────────

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter'

function buildQuery(layer: OverpassLayer, bbox: Bbox): string {
  const meta = LAYER_META[layer]
  const [s, w, n, e] = bbox
  const bboxStr = `${s},${w},${n},${e}`
  const [tagKey, tagValue] = meta.filter.split('=')
  const quoted = `["${tagKey}"="${tagValue}"]`
  const nodePart = `node${quoted}(${bboxStr});`
  const wayPart  = meta.includeWays ? `way${quoted}(${bboxStr});` : ''
  return `[out:json][timeout:25];(${nodePart}${wayPart});out center;`
}

interface OverpassElement {
  type: 'node' | 'way' | 'relation'
  id: number
  lat?: number
  lon?: number
  center?: { lat: number; lon: number }
  tags?: Record<string, string>
}

// Deduplicate inflight requests so rapid toggles don't spam the API.
const inflight = new Map<string, Promise<OverpassPoint[]>>()

export async function fetchOverpassLayer(
  layer: OverpassLayer,
  bbox: Bbox,
): Promise<OverpassPoint[]> {
  const key = cacheKey(layer, bbox)

  const cached = readCache(key)
  if (cached) return cached

  const existing = inflight.get(key)
  if (existing) return existing

  const promise = (async () => {
    try {
      const query = buildQuery(layer, bbox)
      const res = await fetch(OVERPASS_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `data=${encodeURIComponent(query)}`,
      })
      if (!res.ok) return []
      const json = (await res.json()) as { elements: OverpassElement[] }
      const points: OverpassPoint[] = []
      for (const el of json.elements ?? []) {
        const lat = el.lat ?? el.center?.lat
        const lng = el.lon ?? el.center?.lon
        if (lat === undefined || lng === undefined) continue
        points.push({
          id: `${el.type}/${el.id}`,
          lat,
          lng,
          name: el.tags?.name,
          tags: el.tags ?? {},
        })
      }
      writeCache(key, points)
      return points
    } catch {
      return []
    } finally {
      inflight.delete(key)
    }
  })()

  inflight.set(key, promise)
  return promise
}

/** Expand a center point to a ~10km bbox. */
export function bboxAround(lat: number, lng: number, radiusKm = 10): Bbox {
  const dLat = radiusKm / 111
  const dLng = radiusKm / (111 * Math.cos((lat * Math.PI) / 180))
  return [lat - dLat, lng - dLng, lat + dLat, lng + dLng]
}
