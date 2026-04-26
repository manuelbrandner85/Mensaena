// ─────────────────────────────────────────────────────────────────────────────
// Nager.Date – Feiertage in 100+ Ländern weltweit
// https://date.nager.at · kostenlos · kein API-Key, CORS enabled
//
// Endpunkte:
//   GET /api/v3/PublicHolidays/{year}/{countryCode}
//   GET /api/v3/NextPublicHolidays/{countryCode}
//   GET /api/v3/IsTodayPublicHoliday/{countryCode}  → 200 = ja, 204 = nein
//   GET /api/v3/LongWeekend/{year}/{countryCode}
//
// Interner Cache (localStorage): 7 Tage für Listen, 24 h für Status-Checks.
// Wird für nicht-deutsche Regionen verwendet — DE-Feiertage kommen
// weiterhin aus src/lib/api/holidays.ts (feiertage-api.de, regionale
// Granularität pro Bundesland).
// ─────────────────────────────────────────────────────────────────────────────

import type { BundeslandCode } from '@/lib/geo/plz-mapping'
import type { GeoContext } from '@/lib/geo/country-detect'

// ── Public Types ─────────────────────────────────────────────────────────────

export type NagerHolidayType =
  | 'Public' | 'Bank' | 'School' | 'Authorities' | 'Optional' | 'Observance'

export interface PublicHoliday {
  /** ISO-Datum YYYY-MM-DD */
  date: string
  /** Lokaler Name, z. B. "Tag der Deutschen Einheit" */
  localName: string
  /** Englischer Name */
  name: string
  /** ISO-Alpha-2 Ländercode */
  countryCode: string
  /** Gilt landesweit? */
  isNational: boolean
  /** ISO-Subdivision-Codes (z. B. ['DE-BY']) oder null */
  counties: string[] | null
  /** Welche Arten von Feiertag liegen vor */
  types: NagerHolidayType[]
}

export interface LongWeekend {
  /** YYYY-MM-DD */
  startDate: string
  /** YYYY-MM-DD */
  endDate: string
  /** Anzahl Tage */
  dayCount: number
  /** Wahr wenn ein Brückentag genommen werden muss */
  needBridgeDay: boolean
}

// ── Bundesland → ISO-Subdivision (für DE) ────────────────────────────────────

export const BUNDESLAND_TO_SUBDIVISION: Record<BundeslandCode, string> = {
  SH: 'DE-SH', HH: 'DE-HH', NI: 'DE-NI', HB: 'DE-HB', NW: 'DE-NW',
  HE: 'DE-HE', RP: 'DE-RP', BW: 'DE-BW', BY: 'DE-BY', SL: 'DE-SL',
  BE: 'DE-BE', BB: 'DE-BB', MV: 'DE-MV', SN: 'DE-SN', ST: 'DE-ST',
  TH: 'DE-TH', NATIONAL: 'DE',
}

// ── Konstanten ───────────────────────────────────────────────────────────────

const BASE = 'https://date.nager.at/api/v3'
const TIMEOUT_MS = 8_000
const TTL_LIST_MS = 7 * 24 * 60 * 60 * 1000  // 7 Tage
const TTL_STATUS_MS = 24 * 60 * 60 * 1000     // 24 h

// ── Cache (localStorage) ─────────────────────────────────────────────────────

interface CacheEntry<T> { data: T; ts: number }

function readLs<T>(key: string, ttl: number): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < ttl) return data
  } catch { /* ignore */ }
  return null
}

function writeLs<T>(key: string, data: T): void {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota */ }
}

// ── Fetch-Helper ─────────────────────────────────────────────────────────────

async function fetchWithTimeout(url: string): Promise<Response> {
  const controller = new AbortController()
  const t = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    return await fetch(url, {
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
      },
    })
  } finally {
    clearTimeout(t)
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Lädt alle gesetzlichen Feiertage eines Jahres für ein Land.
 * Ergebnis wird 7 Tage in localStorage gecached.
 */
export async function fetchPublicHolidays(
  year: number,
  countryCode: string,
): Promise<PublicHoliday[]> {
  const cc = countryCode.toUpperCase()
  const key = `mensaena_nager_holidays_${year}_${cc}`
  const cached = readLs<PublicHoliday[]>(key, TTL_LIST_MS)
  if (cached) return cached

  try {
    const res = await fetchWithTimeout(`${BASE}/PublicHolidays/${year}/${cc}`)
    if (!res.ok) return []
    const data = (await res.json()) as PublicHoliday[]
    writeLs(key, data)
    return data
  } catch {
    return []
  }
}

/**
 * Lädt die nächsten anstehenden Feiertage (max. 12 Monate Sicht).
 * Cached 24 h.
 */
export async function fetchNextHolidays(
  countryCode: string,
): Promise<PublicHoliday[]> {
  const cc = countryCode.toUpperCase()
  const key = `mensaena_nager_next_${cc}`
  const cached = readLs<PublicHoliday[]>(key, TTL_STATUS_MS)
  if (cached) return cached

  try {
    const res = await fetchWithTimeout(`${BASE}/NextPublicHolidays/${cc}`)
    if (!res.ok) return []
    const data = (await res.json()) as PublicHoliday[]
    writeLs(key, data)
    return data
  } catch {
    return []
  }
}

/**
 * Prüft ob heute ein gesetzlicher Feiertag im Land ist.
 * 200 = ja, 204 = nein. Cached 24 h.
 */
export async function isTodayHoliday(
  countryCode: string,
): Promise<boolean> {
  const cc = countryCode.toUpperCase()
  const key = `mensaena_nager_today_${cc}`
  const cached = readLs<boolean>(key, TTL_STATUS_MS)
  if (cached !== null) return cached

  try {
    const res = await fetchWithTimeout(`${BASE}/IsTodayPublicHoliday/${cc}`)
    const value = res.status === 200
    writeLs(key, value)
    return value
  } catch {
    return false
  }
}

/**
 * Lädt lange Wochenenden / Brückentage eines Jahres. Cached 7 Tage.
 */
export async function fetchLongWeekends(
  year: number,
  countryCode: string,
): Promise<LongWeekend[]> {
  const cc = countryCode.toUpperCase()
  const key = `mensaena_nager_longwk_${year}_${cc}`
  const cached = readLs<LongWeekend[]>(key, TTL_LIST_MS)
  if (cached) return cached

  try {
    const res = await fetchWithTimeout(`${BASE}/LongWeekend/${year}/${cc}`)
    if (!res.ok) return []
    const data = (await res.json()) as LongWeekend[]
    writeLs(key, data)
    return data
  } catch {
    return []
  }
}

/**
 * Filtert Feiertage auf ein deutsches Bundesland.
 * - Bundesweite Feiertage (counties === null oder isNational === true) → ja
 * - Regionale Feiertage → nur wenn `counties` die ISO-Subdivision enthält
 */
export function filterByBundesland(
  holidays: PublicHoliday[],
  bundesland: BundeslandCode,
): PublicHoliday[] {
  const subdivision = BUNDESLAND_TO_SUBDIVISION[bundesland]
  return holidays.filter(h => {
    if (h.isNational || !h.counties || h.counties.length === 0) return true
    return h.counties.includes(subdivision)
  })
}

/**
 * Komfort-Wrapper: liefert Feiertage automatisch passend zum GeoContext.
 * Berücksichtigt Bundesland-Filter wenn verfügbar.
 */
export async function getHolidaysForUser(
  geo: Pick<GeoContext, 'countryCode' | 'bundesland'>,
  year?: number,
): Promise<PublicHoliday[]> {
  const cc = geo.countryCode || 'DE'
  const targetYear = year ?? new Date().getFullYear()
  const all = await fetchPublicHolidays(targetYear, cc)
  if (cc === 'DE' && geo.bundesland) {
    return filterByBundesland(all, geo.bundesland)
  }
  return all
}
