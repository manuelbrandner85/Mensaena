// ─────────────────────────────────────────────────────────────────────────────
// OpenChargeMap API – E-Ladesäulen Standortdaten
// https://openchargemap.org · Open Data · kein API-Key nötig (rate limited)
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_TTL_MS = 60 * 60 * 1000 // 1h

export interface ChargingConnection {
  powerKW: number | null
  type: string
}

export interface ChargingStation {
  id: string
  name: string
  address: string
  city: string
  postcode: string
  lat: number
  lon: number
  connections: ChargingConnection[]
  status: 'available' | 'occupied' | 'unknown'
}

// ── Power helpers ─────────────────────────────────────────────────────────────

export function getMaxPower(station: ChargingStation): number {
  if (station.connections.length === 0) return 0
  return Math.max(0, ...station.connections.map(c => c.powerKW ?? 0))
}

/** Color-coded by charging speed: slow=blue, medium=yellow, fast=green */
export function getPowerColor(maxKW: number): string {
  if (maxKW >= 50) return '#16A34A'
  if (maxKW >= 22) return '#F59E0B'
  return '#2563EB'
}

export function getPowerLabel(maxKW: number): string {
  if (maxKW >= 50) return `${maxKW} kW · Schnellladen`
  if (maxKW >= 22) return `${maxKW} kW · Mittlere Geschwindigkeit`
  if (maxKW > 0) return `${maxKW} kW · Normalladen`
  return 'Leistung unbekannt'
}

export function getStatusLabel(status: ChargingStation['status']): string {
  if (status === 'available') return '✅ Verfügbar'
  if (status === 'occupied') return '🔴 Belegt'
  return '❓ Status unbekannt'
}

// ── OpenChargeMap API types ───────────────────────────────────────────────────

interface OCMConnection {
  PowerKW?: number | null
  ConnectionType?: { Title?: string }
}

interface OCMAddressInfo {
  Title?: string
  AddressLine1?: string
  Town?: string
  Postcode?: string
  Latitude?: number
  Longitude?: number
}

interface OCMPoi {
  ID?: number | string
  AddressInfo?: OCMAddressInfo
  Connections?: OCMConnection[]
  StatusType?: { ID?: number }
}

function mapStatus(id?: number): ChargingStation['status'] {
  if (id === 50) return 'available'
  if (id === 75) return 'occupied'
  return 'unknown'
}

function mapPoi(poi: OCMPoi): ChargingStation | null {
  const addr = poi.AddressInfo
  if (!addr?.Latitude || !addr?.Longitude) return null
  return {
    id:          String(poi.ID ?? ''),
    name:        addr.Title ?? 'Ladestation',
    address:     addr.AddressLine1 ?? '',
    city:        addr.Town ?? '',
    postcode:    addr.Postcode ?? '',
    lat:         addr.Latitude,
    lon:         addr.Longitude,
    connections: (poi.Connections ?? []).map(c => ({
      powerKW: c.PowerKW ?? null,
      type:    c.ConnectionType?.Title ?? 'Unbekannt',
    })),
    status: mapStatus(poi.StatusType?.ID),
  }
}

// ── sessionStorage cache ──────────────────────────────────────────────────────

interface CacheEntry<T> { data: T; ts: number }

function readCache<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* disabled or corrupted */ }
  return null
}

function writeCache<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota exceeded */ }
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Lädt E-Ladesäulen im Umkreis eines Standorts.
 * Cacht das Ergebnis 1h in sessionStorage.
 */
export async function fetchChargingStations(
  lat: number,
  lon: number,
  radiusKm = 10,
): Promise<ChargingStation[]> {
  const latR = Math.round(lat * 100) / 100
  const lonR = Math.round(lon * 100) / 100
  const cacheKey = `mensaena_ocm_${latR}_${lonR}_${radiusKm}`

  const cached = readCache<ChargingStation[]>(cacheKey)
  if (cached) return cached

  try {
    const url =
      `https://api.openchargemap.io/v3/poi/?output=json` +
      `&latitude=${latR}&longitude=${lonR}` +
      `&distance=${radiusKm}&distanceunit=km` +
      `&maxresults=50&compact=true&verbose=false`
    const res = await fetch(url, { signal: AbortSignal.timeout(10_000) })
    if (!res.ok) { writeCache(cacheKey, []); return [] }
    const json = (await res.json()) as OCMPoi[]
    const stations = json.map(mapPoi).filter((s): s is ChargingStation => s !== null)
    writeCache(cacheKey, stations)
    return stations
  } catch {
    return []
  }
}
