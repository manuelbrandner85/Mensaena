// ─────────────────────────────────────────────────────────────────────────────
// Feiertage-API – Deutsche Feiertage je Bundesland
// https://feiertage-api.de · kostenlos · kein API-Key
//
// Liefert offizielle gesetzliche Feiertage in Deutschland nach Bundesland.
// Wird für HolidayBadge (Dashboard-Hinweis) und HolidayCalendarOverlay
// (Event-Kalender) verwendet.
//
// Hinweis: Die Bundesland-Logik (BundeslandCode, plzToBundesland,
// coordsToBundesland, BUNDESLAND_NAMES) liegt in src/lib/geo/plz-mapping.ts.
// Importe aus diesem Modul werden für Rückwärtskompatibilität re-exportiert.
// ─────────────────────────────────────────────────────────────────────────────

// ── Re-Export der Bundesland-Definitionen (Single Source of Truth) ──────────

export type { BundeslandCode } from '@/lib/geo/plz-mapping'
import type { BundeslandCode } from '@/lib/geo/plz-mapping'
export {
  BUNDESLAND_NAMES,
  plzToBundesland,
  coordsToBundesland,
} from '@/lib/geo/plz-mapping'

// ── Konstanten ──────────────────────────────────────────────────────────────

const API_BASE = 'https://feiertage-api.de/api/'
const REQUEST_TIMEOUT_MS = 8_000
const CACHE_TTL_MS = 24 * 60 * 60 * 1000  // 24 Stunden

// ── Public Types ────────────────────────────────────────────────────────────

export interface Holiday {
  /** Original-Name aus der API, z. B. "Tag der Deutschen Einheit" */
  name: string
  /** ISO-Datum YYYY-MM-DD */
  date: string
  /** Optionaler Hinweis (z. B. "regionaler Feiertag") */
  note?: string
  /** Bundesland für das die Warnung gilt; 'NATIONAL' = bundesweit */
  state: BundeslandCode
  /** Wahr wenn nur regional, nicht bundesweit */
  isRegional: boolean
}

/**
 * Bundesweite gesetzliche Feiertage – immer in jeder Region gültig.
 * Wird genutzt um Regional vs. Bundesweit zu unterscheiden.
 */
const NATIONAL_HOLIDAYS = new Set([
  'Neujahrstag',
  'Karfreitag',
  'Ostermontag',
  'Tag der Arbeit',
  'Christi Himmelfahrt',
  'Pfingstmontag',
  'Tag der Deutschen Einheit',
  '1. Weihnachtstag',
  '2. Weihnachtstag',
])

// ── Cache (sessionStorage) ──────────────────────────────────────────────────

interface CacheEntry { data: Holiday[]; ts: number }

function cacheKey(year: number, state: BundeslandCode): string {
  return `mensaena_holidays_${year}_${state}`
}

function readCache(year: number, state: BundeslandCode): Holiday[] | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(cacheKey(year, state))
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* sessionStorage disabled */ }
  return null
}

function writeCache(year: number, state: BundeslandCode, data: Holiday[]) {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(
      cacheKey(year, state),
      JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry),
    )
  } catch { /* quota exceeded */ }
}

// ── API Call ────────────────────────────────────────────────────────────────

interface ApiResponse {
  [holidayName: string]: { datum?: string; hinweis?: string }
}

/**
 * Lädt alle Feiertage für ein Jahr und Bundesland.
 *
 * @param year   Jahreszahl, z. B. 2026
 * @param state  Bundesland-Code (z. B. 'BY', 'NATIONAL')
 * @returns      Sortierte Liste aller Feiertage, leeres Array bei Fehler
 */
export async function fetchHolidays(
  year: number,
  state: BundeslandCode = 'NATIONAL',
): Promise<Holiday[]> {
  const cached = readCache(year, state)
  if (cached) return cached

  const url = `${API_BASE}?jahr=${year}&nur_land=${state}`

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) })
    if (!res.ok) return []

    const json = (await res.json()) as ApiResponse

    const holidays: Holiday[] = Object.entries(json)
      .filter(([, value]) => value && typeof value === 'object' && value.datum)
      .map(([name, value]) => ({
        name,
        date: value.datum!,
        note: value.hinweis || undefined,
        state,
        isRegional: state !== 'NATIONAL' && !NATIONAL_HOLIDAYS.has(name),
      }))
      .sort((a, b) => a.date.localeCompare(b.date))

    writeCache(year, state, holidays)
    return holidays
  } catch {
    return []
  }
}

/**
 * Convenience: lädt aktuelles + nächstes Jahr (für Übergangstage über Jahreswechsel).
 */
export async function fetchHolidaysForCurrentAndNextYear(
  state: BundeslandCode = 'NATIONAL',
): Promise<Holiday[]> {
  const now = new Date()
  const thisYear = now.getFullYear()
  const [a, b] = await Promise.all([
    fetchHolidays(thisYear, state),
    fetchHolidays(thisYear + 1, state),
  ])
  return [...a, ...b]
}

// ── Vergleichs-Helper ───────────────────────────────────────────────────────

/** Yyyy-mm-dd in lokaler Zeit für Vergleiche – ohne Zeitzonen-Drift */
function toLocalDateKey(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function todayKey(): string { return toLocalDateKey(new Date()) }
function tomorrowKey(): string {
  const t = new Date()
  t.setDate(t.getDate() + 1)
  return toLocalDateKey(t)
}

/**
 * Findet den nächsten zukünftigen Feiertag (heute oder später).
 * Gibt null zurück wenn keine zukünftigen Feiertage in der Liste sind.
 */
export function getNextHoliday(holidays: Holiday[]): Holiday | null {
  const today = todayKey()
  const future = holidays
    .filter(h => h.date >= today)
    .sort((a, b) => a.date.localeCompare(b.date))
  return future[0] ?? null
}

/** Wenn heute ein Feiertag ist: gib ihn zurück. */
export function isHolidayToday(holidays: Holiday[]): Holiday | null {
  const today = todayKey()
  return holidays.find(h => h.date === today) ?? null
}

/** Wenn morgen ein Feiertag ist: gib ihn zurück. */
export function isHolidayTomorrow(holidays: Holiday[]): Holiday | null {
  const tomorrow = tomorrowKey()
  return holidays.find(h => h.date === tomorrow) ?? null
}

/** Anzahl Tage bis zum gegebenen Feiertag (negativ wenn vorbei). */
export function daysUntilHoliday(holiday: Holiday): number {
  const target = new Date(holiday.date + 'T00:00:00')
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  return Math.round((target.getTime() - now.getTime()) / (24 * 60 * 60 * 1000))
}

// ── Festtags-Emojis ─────────────────────────────────────────────────────────

/**
 * Mappt Feiertags-Namen auf passende Emojis.
 * Wird in HolidayBadge und HolidayCalendarOverlay verwendet.
 */
export function getHolidayEmoji(name: string): string {
  const n = name.toLowerCase()

  if (/weihnacht|christ/.test(n))                            return '🎄'
  if (/heilig.*abend|christabend/.test(n))                   return '🕯️'
  if (/silvester/.test(n))                                   return '🎆'
  if (/neujahr/.test(n))                                     return '🥂'
  if (/heilig.*drei.*könig|epiphan/.test(n))                 return '👑'
  if (/oster|ostern|karfreitag|ostermontag|gründonner/.test(n)) return '🐣'
  if (/himmelfahrt/.test(n))                                 return '☁️'
  if (/pfingst/.test(n))                                     return '🕊️'
  if (/fronleichnam/.test(n))                                return '✝️'
  if (/maria.*himmelfahrt|assumpt/.test(n))                  return '🌹'
  if (/allerheiligen|reformation|buß.*bettag/.test(n))       return '🕯️'
  if (/tag.*arbeit|maifeier/.test(n))                        return '💪'
  if (/deutsch.*einheit|tag.*einheit/.test(n))               return '🇩🇪'
  if (/welt.*kindertag|kindertag/.test(n))                   return '🧒'
  if (/frauen|weltfrauentag/.test(n))                        return '👩'
  if (/martin/.test(n))                                      return '🏮'
  if (/nikolaus/.test(n))                                    return '🎅'

  return '🎉'
}

/**
 * Kurze, freundliche Beschreibung für ein Festtags-Emoji.
 * Wird in Tooltips/aria-labels verwendet.
 */
export function getHolidayDescription(name: string): string {
  const n = name.toLowerCase()
  if (/weihnacht/.test(n))               return 'Weihnachten – Zeit für Familie und Nachbarschaft'
  if (/oster|karfreitag/.test(n))        return 'Ostern – Frühlingsfest und Familienzeit'
  if (/pfingst/.test(n))                 return 'Pfingsten – langes Wochenende, Zeit für Begegnung'
  if (/deutsch.*einheit/.test(n))        return 'Tag der Deutschen Einheit – Nachbarschaftsfest geplant?'
  if (/tag.*arbeit/.test(n))             return 'Tag der Arbeit – Maibaum, Demos, Picknicks'
  if (/neujahr/.test(n))                 return 'Neujahr – guten Start ins neue Jahr!'
  if (/himmelfahrt/.test(n))             return 'Christi Himmelfahrt / Vatertag'
  return 'Gesetzlicher Feiertag'
}
