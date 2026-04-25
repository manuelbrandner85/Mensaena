// OpenRouteService API client
// Kostenloser API-Key: https://openrouteservice.org/dev/#/signup
// Key in .env.local als NEXT_PUBLIC_ORS_API_KEY eintragen.

export type RouteProfile = 'car' | 'bike' | 'foot'

export interface RouteStep {
  instruction: string
  distance: number
  duration: number
}

export interface RouteResult {
  distanceKm: number
  durationMin: number
  /** GeoJSON LineString – coordinates in [lon, lat] ORS convention */
  geometry: { type: 'LineString'; coordinates: number[][] }
  steps?: RouteStep[]
}

export interface IsochroneResult {
  polygons: Array<{
    type: 'Feature'
    geometry: { type: 'Polygon'; coordinates: number[][][] }
    properties: { value: number; [key: string]: unknown }
  }>
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/** Format meters → "450 m" or "2,3 km" */
export function formatDistance(meters: number): string {
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toLocaleString('de-DE', { maximumFractionDigits: 1 })} km`
}

/** Format seconds → "12 Min." or "1 Std. 23 Min." */
export function formatDuration(seconds: number): string {
  const mins = Math.round(seconds / 60)
  if (mins < 60) return `${mins} Min.`
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return m > 0 ? `${h} Std. ${m} Min.` : `${h} Std.`
}

/**
 * Haversine great-circle distance in km.
 * Accepts lat/lon in decimal degrees. No API call needed.
 */
export function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ── API Calls (via server-side proxy to avoid CORS) ──────────────────────────

/**
 * Berechnet eine Route zwischen zwei Punkten.
 * @param from [lat, lon]
 * @param to   [lat, lon]
 */
export async function getRoute(
  from: [number, number],
  to: [number, number],
  profile: RouteProfile = 'foot',
): Promise<RouteResult> {
  const params = new URLSearchParams({
    profile,
    fromLat: String(from[0]),
    fromLon: String(from[1]),
    toLat: String(to[0]),
    toLon: String(to[1]),
  })
  const res = await fetch(`/api/routing?${params}`, { cache: 'no-store' })
  if (!res.ok) {
    const body = await res.text().catch(() => '')
    throw new Error(`Route fetch failed ${res.status}: ${body}`)
  }
  return res.json() as Promise<RouteResult>
}

/**
 * Berechnet Erreichbarkeits-Isochrone (Polygone).
 * @param center  [lat, lon]
 * @param minutes Array von Minuten, z.B. [5, 10, 15]
 */
export async function getIsochrones(
  center: [number, number],
  minutes: number[],
  profile: RouteProfile = 'foot',
): Promise<IsochroneResult> {
  const res = await fetch('/api/routing', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ center, minutes, profile }),
    cache: 'no-store',
  })
  if (!res.ok) {
    const body = await res.text().catch(() => '')
    throw new Error(`Isochrone fetch failed ${res.status}: ${body}`)
  }
  return res.json() as Promise<IsochroneResult>
}
