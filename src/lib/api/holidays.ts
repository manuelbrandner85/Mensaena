// ─────────────────────────────────────────────────────────────────────────────
// Feiertage-API – Deutsche Feiertage je Bundesland
// https://feiertage-api.de · kostenlos · kein API-Key
//
// Liefert offizielle gesetzliche Feiertage in Deutschland nach Bundesland.
// Wird für HolidayBadge (Dashboard-Hinweis) und HolidayCalendarOverlay
// (Event-Kalender) verwendet.
// ─────────────────────────────────────────────────────────────────────────────

// ── Konstanten ──────────────────────────────────────────────────────────────

const API_BASE = 'https://feiertage-api.de/api/'
const REQUEST_TIMEOUT_MS = 8_000
const CACHE_TTL_MS = 24 * 60 * 60 * 1000  // 24 Stunden

// ── Public Types ────────────────────────────────────────────────────────────

export type BundeslandCode =
  | 'BW' | 'BY' | 'BE' | 'BB' | 'HB' | 'HH'
  | 'HE' | 'MV' | 'NI' | 'NW' | 'RP' | 'SL'
  | 'SN' | 'ST' | 'SH' | 'TH' | 'NATIONAL'

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

// ── Bundesland-Metadaten ────────────────────────────────────────────────────

export const BUNDESLAND_NAMES: Record<BundeslandCode, string> = {
  BW:        'Baden-Württemberg',
  BY:        'Bayern',
  BE:        'Berlin',
  BB:        'Brandenburg',
  HB:        'Bremen',
  HH:        'Hamburg',
  HE:        'Hessen',
  MV:        'Mecklenburg-Vorpommern',
  NI:        'Niedersachsen',
  NW:        'Nordrhein-Westfalen',
  RP:        'Rheinland-Pfalz',
  SL:        'Saarland',
  SN:        'Sachsen',
  ST:        'Sachsen-Anhalt',
  SH:        'Schleswig-Holstein',
  TH:        'Thüringen',
  NATIONAL:  'Deutschland (bundesweit)',
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

// ── PLZ → Bundesland Mapping ────────────────────────────────────────────────

/**
 * Mapping basierend auf den ersten 1-2 PLZ-Ziffern.
 * Quelle: Deutsche Post Leitzonen.
 *
 * Die Zuordnung ist eine bewährte Heuristik – einzelne Grenzfälle
 * (z. B. PLZ-Bereiche an Bundeslandgrenzen) können falsch sein,
 * decken aber den überwiegenden Teil korrekt ab.
 */
function plzPrefixToBundesland(plz: string): BundeslandCode | null {
  const trimmed = plz.replace(/\s/g, '')
  if (trimmed.length < 2) return null

  const firstTwo = parseInt(trimmed.slice(0, 2), 10)
  if (isNaN(firstTwo)) return null

  // ── Sachsen ──────────────────────────────────
  if (firstTwo >= 1 && firstTwo <= 9)  return 'SN'  // 01-09 Dresden, Leipzig, Chemnitz
  // ── Berlin (10-14 teils Berlin, teils Brandenburg) ──
  if (firstTwo === 10 || firstTwo === 12 || firstTwo === 13) return 'BE'
  if (firstTwo === 14)                                       return 'BB'  // Potsdam
  // ── Brandenburg ──────────────────────────────
  if (firstTwo >= 15 && firstTwo <= 16) return 'BB'
  // ── Mecklenburg-Vorpommern ───────────────────
  if (firstTwo >= 17 && firstTwo <= 19) return 'MV'
  // ── Hamburg ──────────────────────────────────
  if (firstTwo >= 20 && firstTwo <= 21) return 'HH'
  if (firstTwo === 22)                  return 'HH'  // 22 teils Hamburg, teils SH
  // ── Schleswig-Holstein ───────────────────────
  if (firstTwo >= 23 && firstTwo <= 25) return 'SH'
  // ── Niedersachsen ────────────────────────────
  if (firstTwo === 26 || firstTwo === 27) return 'NI'
  // ── Bremen ───────────────────────────────────
  if (firstTwo === 28)                  return 'HB'
  // ── Niedersachsen ────────────────────────────
  if (firstTwo >= 29 && firstTwo <= 31) return 'NI'
  // ── NRW ──────────────────────────────────────
  if (firstTwo >= 32 && firstTwo <= 33) return 'NW'
  // ── Niedersachsen / Hessen ──────────────────
  if (firstTwo === 34)                  return 'HE'  // Kassel
  if (firstTwo === 35)                  return 'HE'
  if (firstTwo === 36)                  return 'HE'
  // ── Niedersachsen ────────────────────────────
  if (firstTwo >= 37 && firstTwo <= 38) return 'NI'
  // ── Sachsen-Anhalt ───────────────────────────
  if (firstTwo === 39)                  return 'ST'
  // ── NRW ──────────────────────────────────────
  if (firstTwo >= 40 && firstTwo <= 48) return 'NW'
  // ── Niedersachsen ────────────────────────────
  if (firstTwo === 49)                  return 'NI'
  // ── NRW ──────────────────────────────────────
  if (firstTwo >= 50 && firstTwo <= 51) return 'NW'
  if (firstTwo === 52)                  return 'NW'  // Aachen
  // ── Hessen / RP ──────────────────────────────
  if (firstTwo === 53)                  return 'NW'  // Bonn
  if (firstTwo >= 54 && firstTwo <= 56) return 'RP'
  if (firstTwo === 57)                  return 'NW'  // Siegen
  if (firstTwo >= 58 && firstTwo <= 59) return 'NW'
  // ── Hessen ───────────────────────────────────
  if (firstTwo >= 60 && firstTwo <= 65) return 'HE'  // Frankfurt, Wiesbaden
  // ── RP ───────────────────────────────────────
  if (firstTwo === 66)                  return 'SL'  // Saarland (66xxx)
  if (firstTwo >= 67 && firstTwo <= 68) return 'RP'
  // ── BW ───────────────────────────────────────
  if (firstTwo === 68)                  return 'BW'  // Mannheim
  if (firstTwo >= 69 && firstTwo <= 79) return 'BW'
  // ── Bayern ───────────────────────────────────
  if (firstTwo >= 80 && firstTwo <= 87) return 'BY'  // München, Augsburg
  if (firstTwo === 88)                  return 'BW'  // Bodensee, teils BW
  if (firstTwo >= 89 && firstTwo <= 96) return 'BY'
  // ── Thüringen ────────────────────────────────
  if (firstTwo >= 97 && firstTwo <= 97) return 'BY'  // Würzburg
  if (firstTwo >= 98 && firstTwo <= 99) return 'TH'

  return null
}

/**
 * Public Helper: PLZ → Bundesland-Code.
 * Gibt 'NATIONAL' zurück wenn keine eindeutige Zuordnung möglich ist.
 */
export function plzToBundesland(plz: string | null | undefined): BundeslandCode {
  if (!plz) return 'NATIONAL'
  return plzPrefixToBundesland(plz) ?? 'NATIONAL'
}

/**
 * Bundesland aus Koordinaten – grobe Bounding-Box-Heuristik.
 * Fallback wenn keine PLZ verfügbar ist (z. B. nur lat/lng aus Geolocation).
 */
export function coordsToBundesland(lat: number, lon: number): BundeslandCode {
  // Stadtstaaten (sehr klein, exakt prüfen)
  if (lat >= 53.39 && lat <= 53.74 && lon >= 8.10 && lon <= 9.30) return 'HB'  // Bremen
  if (lat >= 53.39 && lat <= 53.74 && lon >= 9.71 && lon <= 10.33) return 'HH' // Hamburg
  if (lat >= 52.34 && lat <= 52.68 && lon >= 13.08 && lon <= 13.77) return 'BE' // Berlin

  // Flächenstaaten – grobe Boxen, in zweifel das umschließende Bundesland
  if (lat >= 47.27 && lat <= 50.56 && lon >= 9.00 && lon <= 13.84) return 'BY'  // Bayern
  if (lat >= 47.53 && lat <= 49.79 && lon >= 7.51 && lon <= 10.50) return 'BW'  // BW
  if (lat >= 49.11 && lat <= 50.94 && lon >= 8.00 && lon <= 10.24) return 'HE'  // Hessen
  if (lat >= 50.32 && lat <= 51.65 && lon >= 5.86 && lon <= 9.46)  return 'NW'  // NRW
  if (lat >= 49.11 && lat <= 50.94 && lon >= 6.11 && lon <= 8.51)  return 'RP'  // RP
  if (lat >= 49.11 && lat <= 49.64 && lon >= 6.36 && lon <= 7.40)  return 'SL'  // Saarland
  if (lat >= 51.32 && lat <= 53.89 && lon >= 6.65 && lon <= 11.59) return 'NI'  // NI
  if (lat >= 53.36 && lat <= 55.07 && lon >= 7.86 && lon <= 11.32) return 'SH'  // SH
  if (lat >= 53.10 && lat <= 54.71 && lon >= 10.59 && lon <= 14.41) return 'MV' // MV
  if (lat >= 51.36 && lat <= 53.56 && lon >= 11.27 && lon <= 14.77) return 'BB' // BB
  if (lat >= 50.17 && lat <= 51.69 && lon >= 11.87 && lon <= 15.04) return 'SN' // Sachsen
  if (lat >= 50.17 && lat <= 53.04 && lon >= 10.55 && lon <= 13.18) return 'ST' // ST
  if (lat >= 50.20 && lat <= 51.65 && lon >= 9.87 && lon <= 12.66)  return 'TH' // TH

  return 'NATIONAL'
}

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
  if (/martin/.test(n))                                      return '🏮'  // St. Martin
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
