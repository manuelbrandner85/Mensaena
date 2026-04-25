export interface WaterStation {
  uuid: string
  name: string
  waterName: string
  lat: number
  lon: number
  currentLevel: number
  unit: string
  timestamp: string
  trend: 'rising' | 'falling' | 'stable'
}

export interface WaterMeasurement {
  timestamp: string
  value: number
}

export type WaterWarningLevel = 'normal' | 'elevated' | 'flood' | 'extreme'

export function getWarningLevel(cm: number): WaterWarningLevel {
  if (cm < 200) return 'normal'
  if (cm < 400) return 'elevated'
  if (cm < 600) return 'flood'
  return 'extreme'
}

export const WARNING_COLORS: Record<WaterWarningLevel, { bg: string; ring: string; text: string; hex: string; label: string }> = {
  normal:   { bg: 'bg-emerald-50',  ring: 'ring-emerald-300', text: 'text-emerald-700',  hex: '#10b981', label: 'Normal' },
  elevated: { bg: 'bg-amber-50',    ring: 'ring-amber-300',   text: 'text-amber-700',    hex: '#f59e0b', label: 'Erhöht' },
  flood:    { bg: 'bg-orange-50',   ring: 'ring-orange-400',  text: 'text-orange-700',   hex: '#ea580c', label: 'Hochwasser' },
  extreme:  { bg: 'bg-red-50',      ring: 'ring-red-500',     text: 'text-red-700',      hex: '#dc2626', label: 'Extremes Hochwasser' },
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// Module-level cache (15 min)
const CACHE_TTL = 15 * 60 * 1000
let _stationsCache: { data: WaterStation[]; expires: number } | null = null
const _measurementsCache = new Map<string, { data: WaterMeasurement[]; expires: number }>()

export async function fetchNearbyStations(lat: number, lon: number, radiusKm: number): Promise<WaterStation[]> {
  if (_stationsCache && Date.now() < _stationsCache.expires) {
    return _stationsCache.data
      .map(s => ({ ...s, _d: haversineKm(lat, lon, s.lat, s.lon) }))
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .filter((s: any) => s._d <= radiusKm)
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .sort((a: any, b: any) => a._d - b._d)
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .map(({ _d, ...rest }: any) => rest as WaterStation)
  }

  const res = await fetch(`/api/waterlevel?lat=${lat}&lon=${lon}&radius=${radiusKm}`, { cache: 'no-store' })
  if (!res.ok) throw new Error(`Pegel-API ${res.status}`)
  const stations: WaterStation[] = await res.json()
  _stationsCache = { data: stations, expires: Date.now() + CACHE_TTL }
  return stations
}

export async function fetchStationMeasurements(uuid: string): Promise<WaterMeasurement[]> {
  const cached = _measurementsCache.get(uuid)
  if (cached && Date.now() < cached.expires) return cached.data

  const res = await fetch(`/api/waterlevel/measurements?uuid=${uuid}`, { cache: 'no-store' })
  if (!res.ok) throw new Error(`Pegel-Measurements ${res.status}`)
  const data: WaterMeasurement[] = await res.json()
  _measurementsCache.set(uuid, { data, expires: Date.now() + CACHE_TTL })
  return data
}

export function clearWaterLevelCache() {
  _stationsCache = null
  _measurementsCache.clear()
}
