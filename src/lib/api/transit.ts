/**
 * Deutsche Bahn / ÖPNV API client
 * Source: https://v6.db.transport.rest (free, no key required)
 * Covers Germany-wide public transit: ICE, IC, RE, S-Bahn, U-Bahn, Bus, Tram
 */

export interface TransitStop {
  id: string
  name: string
  distance: number       // metres from query point
  products: string[]     // e.g. ['nationalExpress', 'regional', 'bus']
}

export interface TransitDeparture {
  tripId: string
  line: string           // e.g. 'S1', 'U4', 'RE1'
  direction: string | null
  when: string | null    // ISO – null if cancelled
  plannedWhen: string
  delay: number | null   // seconds
  cancelled: boolean
  platform: string | null
  color: string | null   // line colour from operator
}

// ── In-memory cache (stops rarely change; departures = live) ─────────────────

const _stopsCache = new Map<string, { data: TransitStop[]; ts: number }>()
const _depsCache  = new Map<string, { data: TransitDeparture[]; ts: number }>()
const STOPS_TTL   = 30 * 60 * 1000  // 30 min
const DEPS_TTL    = 60 * 1000        // 1 min (live data)

const BASE = 'https://v6.db.transport.rest'

// ── Product → human label ─────────────────────────────────────────────────────

export const PRODUCT_LABELS: Record<string, string> = {
  nationalExpress: 'ICE',
  national:        'IC/EC',
  regionalExpress: 'RE',
  regional:        'RB',
  suburban:        'S-Bahn',
  bus:             'Bus',
  ferry:           'Fähre',
  subway:          'U-Bahn',
  tram:            'Tram',
  taxi:            'Ruf-Taxi',
}

export function productLabel(p: string): string {
  return PRODUCT_LABELS[p] ?? p
}

// ── API functions ─────────────────────────────────────────────────────────────

/**
 * Returns up to `results` public-transit stops within `distanceM` metres.
 */
export async function fetchNearbyStops(
  lat: number,
  lng: number,
  results = 4,
  distanceM = 1500,
): Promise<TransitStop[]> {
  const key = `${lat.toFixed(3)}_${lng.toFixed(3)}`
  const cached = _stopsCache.get(key)
  if (cached && Date.now() - cached.ts < STOPS_TTL) return cached.data

  try {
    const url =
      `${BASE}/stops/nearby?latitude=${lat}&longitude=${lng}` +
      `&results=${results}&distance=${distanceM}&language=de`
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) })
    if (!res.ok) return []

    const json = await res.json() as Record<string, unknown>[]
    const stops: TransitStop[] = json.map((s) => ({
      id:       s.id as string,
      name:     s.name as string,
      distance: s.distance as number,
      products: Object.entries((s.products ?? {}) as Record<string, boolean>)
        .filter(([, v]) => v)
        .map(([k]) => k),
    }))

    _stopsCache.set(key, { data: stops, ts: Date.now() })
    return stops
  } catch {
    return []
  }
}

/**
 * Returns next `results` departures from a stop in the next `durationMin` minutes.
 */
export async function fetchDepartures(
  stopId: string,
  results = 8,
  durationMin = 60,
): Promise<TransitDeparture[]> {
  const minKey = Math.floor(Date.now() / 60_000).toString()
  const key    = `${stopId}_${minKey}`
  const cached = _depsCache.get(key)
  if (cached && Date.now() - cached.ts < DEPS_TTL) return cached.data

  try {
    const when = new Date().toISOString()
    const url  =
      `${BASE}/stops/${encodeURIComponent(stopId)}/departures` +
      `?when=${encodeURIComponent(when)}&duration=${durationMin}&results=${results}&language=de`
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) })
    if (!res.ok) return []

    const json = await res.json() as { departures?: Record<string, unknown>[] }
    const deps: TransitDeparture[] = (json.departures ?? []).map((d) => {
      const line = d.line as Record<string, unknown>
      return {
        tripId:      (d.tripId as string) ?? '',
        line:        (line?.name  as string) ?? '?',
        direction:   (d.direction as string | null),
        when:        (d.when      as string | null),
        plannedWhen: (d.plannedWhen as string),
        delay:       (d.delay     as number | null),
        cancelled:   Boolean(d.cancelled),
        platform:    (d.platform  as string | null) ?? (d.plannedPlatform as string | null),
        color:       (line?.color as Record<string, string> | null)?.background ?? null,
      }
    })

    _depsCache.set(key, { data: deps, ts: Date.now() })
    return deps
  } catch {
    return []
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Format delay in minutes with sign. Returns null when no delay. */
export function formatDelay(seconds: number | null): string | null {
  if (seconds == null || seconds === 0) return null
  const min = Math.round(seconds / 60)
  return min > 0 ? `+${min} Min` : `${min} Min`
}

/** Format ISO departure time as HH:MM */
export function formatTime(iso: string | null): string {
  if (!iso) return '–'
  return new Date(iso).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
}
