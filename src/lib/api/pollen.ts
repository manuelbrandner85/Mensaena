/**
 * DWD Pollenflug-Gefahrenindex
 * Source: https://opendata.dwd.de/climate_environment/health/alerts/s31fg.json
 * Free, no API key. Updated once daily by the German Weather Service (DWD).
 *
 * Pollen level scale:
 *   -1 = keine Vorhersage möglich
 *    0 = kein Flug
 *    1 = schwacher Flug
 *    2 = mittlerer Flug
 *    3 = starker Flug
 * Intermediate values (0.5, 1.5, 2.5) = transitional
 */

export type PollenLevel = -1 | 0 | 0.5 | 1 | 1.5 | 2 | 2.5 | 3

export interface PollenEntry {
  key: string          // DWD key e.g. 'Birke'
  label: string        // German display name
  emoji: string
  today: PollenLevel
  tomorrow: PollenLevel
  dayAfter: PollenLevel
}

export interface PollenRegion {
  regionId: number
  regionName: string
  pollens: PollenEntry[]
  lastUpdate: string
}

// ── Metadata ──────────────────────────────────────────────────────────────────

const POLLEN_META: Record<string, { label: string; emoji: string }> = {
  Birke:    { label: 'Birke',    emoji: '🌳' },
  Roggen:   { label: 'Roggen',   emoji: '🌾' },
  Graeser:  { label: 'Gräser',   emoji: '🌿' },
  Erle:     { label: 'Erle',     emoji: '🌲' },
  Hasel:    { label: 'Hasel',    emoji: '🌰' },
  Esche:    { label: 'Esche',    emoji: '🍃' },
  Beifuss:  { label: 'Beifuß',   emoji: '🌱' },
  Ambrosia: { label: 'Ambrosia', emoji: '⚠️' },
}

/** DWD region center coords for closest-region lookup [lat, lng] */
const REGION_COORDS: Record<number, [number, number]> = {
  10: [54.0, 10.0],  // Schleswig-Holstein und Hamburg
  11: [53.8, 12.6],  // Mecklenburg-Vorpommern
  12: [52.4, 13.4],  // Brandenburg und Berlin
  20: [52.7,  9.2],  // Niedersachsen und Bremen
  31: [51.8, 11.8],  // Sachsen-Anhalt
  32: [50.9, 11.0],  // Thüringen
  33: [51.1, 13.2],  // Sachsen
  34: [50.6, 12.1],  // Vogtland
  41: [51.7,  7.8],  // Westfalen
  42: [51.2,  7.0],  // Rheinland und Ruhrgebiet
  43: [51.0,  8.0],  // Westl. Mittelgebirge
  44: [51.0,  9.5],  // Östl. Mittelgebirge
  50: [50.2,  8.5],  // Rhein-Main und Hessen
  61: [49.5, 10.5],  // Fränkisches Tiefland
  62: [48.4, 10.5],  // Schwaben (Bayern)
  71: [47.8, 11.5],  // Alpen und Alpenvorland
  91: [49.3,  7.5],  // Rhein-Pfalz und Mittelrhein
  92: [49.8,  7.0],  // Rheinhessen und Saarland
  93: [48.5,  8.5],  // Schwarzwald und Schwaben BW
}

// ── Human-readable helpers ────────────────────────────────────────────────────

export function pollenLevelLabel(level: PollenLevel): string {
  const map: Record<number, string> = {
    '-1': 'k.A.',
    '0': 'kein',
    '0.5': 'keine–gering',
    '1': 'gering',
    '1.5': 'gering–mittel',
    '2': 'mittel',
    '2.5': 'mittel–stark',
    '3': 'stark',
  }
  return map[level] ?? '–'
}

export function pollenLevelColorClass(level: PollenLevel): string {
  if (level <= 0)   return 'bg-green-100 text-green-800 border-green-200'
  if (level <= 1)   return 'bg-yellow-100 text-yellow-800 border-yellow-200'
  if (level <= 2)   return 'bg-orange-100 text-orange-800 border-orange-200'
  return              'bg-red-100 text-red-800 border-red-200'
}

export function pollenLevelDot(level: PollenLevel): string {
  if (level <= 0)   return 'bg-green-400'
  if (level <= 1)   return 'bg-yellow-400'
  if (level <= 2)   return 'bg-orange-400'
  return              'bg-red-500'
}

/** Parse DWD string values like "0", "0-1", "1", "2-3", "3", "-1" into PollenLevel */
function parseDWDLevel(raw: string | undefined): PollenLevel {
  if (!raw || raw === '' || raw === '-1') return -1
  if (raw.includes('-')) {
    const [a, b] = raw.split('-').map(Number)
    return ((a + b) / 2) as PollenLevel
  }
  return Number(raw) as PollenLevel
}

/** Haversine distance in km */
function distKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R   = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLng = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

/** Return the DWD region ID closest to given coordinates */
export function closestRegionId(lat: number, lng: number): number {
  let best = 50, bestDist = Infinity
  for (const [id, [rlat, rlng]] of Object.entries(REGION_COORDS)) {
    const d = distKm(lat, lng, rlat, rlng)
    if (d < bestDist) { bestDist = d; best = Number(id) }
  }
  return best
}

// ── Cache ─────────────────────────────────────────────────────────────────────

let _cache: { data: Record<string, unknown>; ts: number } | null = null
const POLLEN_TTL = 6 * 60 * 60 * 1000 // 6 h (DWD updates once daily)

// ── API ───────────────────────────────────────────────────────────────────────

async function loadDWDData(): Promise<Record<string, unknown> | null> {
  if (_cache && Date.now() - _cache.ts < POLLEN_TTL) return _cache.data
  try {
    const res = await fetch(
      'https://opendata.dwd.de/climate_environment/health/alerts/s31fg.json',
      { signal: AbortSignal.timeout(8000) },
    )
    if (!res.ok) return null
    const json = await res.json() as Record<string, unknown>
    _cache = { data: json, ts: Date.now() }
    return json
  } catch {
    return null
  }
}

/**
 * Fetch pollen data for a specific DWD region.
 * Pass `regionId = closestRegionId(lat, lng)` to get location-aware data.
 */
export async function fetchPollenRegion(regionId: number): Promise<PollenRegion | null> {
  const raw = await loadDWDData()
  if (!raw) return null

  const lastUpdate = (raw.last_update as string) ?? ''
  const content    = raw.content as Array<Record<string, unknown>>
  const region     = content?.find((r) => (r.region_id as number) === regionId)
  if (!region) return null

  const pollenMap = region.Pollen as Record<string, Record<string, string>> | undefined
  if (!pollenMap) return null

  const pollens: PollenEntry[] = Object.entries(pollenMap).map(([key, vals]) => {
    const meta = POLLEN_META[key] ?? { label: key, emoji: '🌿' }
    return {
      key,
      label:    meta.label,
      emoji:    meta.emoji,
      today:    parseDWDLevel(vals.today),
      tomorrow: parseDWDLevel(vals.tomorrow),
      dayAfter: parseDWDLevel(vals.dayafter_to),
    }
  })

  return {
    regionId,
    regionName: region.region_name as string,
    pollens,
    lastUpdate,
  }
}

/** Returns the highest pollen level active today across all regions */
export async function fetchPollenPeak(): Promise<PollenEntry[]> {
  const raw = await loadDWDData()
  if (!raw) return []

  const content = raw.content as Array<Record<string, unknown>>
  const peak: Record<string, { entry: PollenEntry; max: number }> = {}

  for (const region of content) {
    const pollenMap = region.Pollen as Record<string, Record<string, string>> | undefined
    if (!pollenMap) continue
    for (const [key, vals] of Object.entries(pollenMap)) {
      const today = parseDWDLevel(vals.today)
      if (today <= 0) continue
      const prev = peak[key]
      if (!prev || today > prev.max) {
        const meta = POLLEN_META[key] ?? { label: key, emoji: '🌿' }
        peak[key] = {
          max: today,
          entry: {
            key,
            label:    meta.label,
            emoji:    meta.emoji,
            today,
            tomorrow: parseDWDLevel(vals.tomorrow),
            dayAfter: parseDWDLevel(vals.dayafter_to),
          },
        }
      }
    }
  }

  return Object.values(peak)
    .sort((a, b) => b.max - a.max)
    .map((p) => p.entry)
}
