// ─────────────────────────────────────────────────────────────────────────────
// Bright Sky API (DWD) – Offizielle deutsche Wetterdaten + Wetterwarnungen
// https://brightsky.dev · Open Source · kein API-Key nötig
//
// Quellen:
// - Wetterdaten: Deutscher Wetterdienst (DWD) – offiziell und behördlich verbürgt
// - Warnungen:   DWD WarnWetter Service (CAP-Format)
//
// Diese Datei ergänzt die NINA-Warnungen (Bevölkerungsschutz) um
// wetter-spezifische Warnungen mit Gültigkeitszeitraum und Handlungsempfehlung.
// ─────────────────────────────────────────────────────────────────────────────

import type { NinaWarning } from '@/lib/nina-api'

// ── Konstanten ──────────────────────────────────────────────────────────────

const BRIGHTSKY_BASE = 'https://api.brightsky.dev'
const REQUEST_TIMEOUT_MS = 8_000
const CACHE_TTL_MS = 15 * 60 * 1000  // 15 Minuten

// ── Public Types ────────────────────────────────────────────────────────────

export type AlertSeverity = 'minor' | 'moderate' | 'severe' | 'extreme'

export type AlertStatus = 'actual' | 'exercise' | 'system' | 'test' | 'draft'

export interface WeatherAlert {
  /** Eindeutige ID (von DWD vergeben) */
  id: string
  /** Status der Warnung; im Production-Betrieb fast immer 'actual' */
  status: AlertStatus
  /** Wann die Warnung gemeldet wurde (ISO) */
  effective: string
  /** Beginn der Wetterlage (ISO) */
  onset: string
  /** Ende der Wetterlage (ISO) */
  expires: string
  /** Ereignis-Bezeichnung (z. B. "Sturmböen", "Glätte", "Hitzewelle") */
  event: string
  /** Schweregrad gemäß CAP-Standard */
  severity: AlertSeverity
  /** Knapper Titel/Schlagzeile */
  headline: string
  /** Ausführliche Beschreibung */
  description: string
  /** Konkrete Handlungsanweisung (optional vom DWD) */
  instruction: string
}

export interface DWDCurrentWeather {
  /** Lufttemperatur in °C */
  temperature: number
  /** Windgeschwindigkeit in km/h */
  windSpeed: number
  /** Windrichtung in Grad (0 = Nord) */
  windDirection: number
  /** Niederschlag in mm (letzte Stunde) */
  precipitation: number
  /** Sonnenscheindauer in Minuten (letzte Stunde) */
  sunshine: number
  /** Bewölkung in % (0 = klar, 100 = bedeckt) */
  cloudCover: number
  /** Sichtweite in Meter */
  visibility: number
  /** Icon-Key kompatibel zu den Mensaena-Wetter-Icons */
  icon: string
  /** Zeitstempel der Messung (ISO) */
  timestamp: string
}

/**
 * Vereinheitlichte Warnungs-Form, die NINA und DWD zusammenfasst.
 * Verwendet die gleiche Struktur wie NinaWarning, ergänzt um Quelle und
 * Wetter-spezifische Felder.
 */
export interface UnifiedWarning extends NinaWarning {
  source: 'nina' | 'dwd'
  /** Nur bei DWD-Warnungen: Beginn der Wetterlage (ISO) */
  onset?: string
  /** Nur bei DWD-Warnungen: Ende der Wetterlage (ISO) */
  expires?: string
  /** Nur bei DWD-Warnungen: ursprüngliches Event (z. B. "Sturmböen") */
  event?: string
}

// ── Cache (sessionStorage – konsistent zu lib/services/weather.ts) ──────────

interface CacheEntry<T> {
  data: T
  ts: number
}

function readCache<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry<T>
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* sessionStorage kann disabled sein */ }
  return null
}

function writeCache<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(key, JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry<T>))
  } catch { /* quota exceeded */ }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const SEVERITY_ALLOWLIST = new Set<AlertSeverity>(['minor', 'moderate', 'severe', 'extreme'])
const STATUS_ALLOWLIST   = new Set<AlertStatus>(['actual', 'exercise', 'system', 'test', 'draft'])

const SEVERITY_RANK: Record<AlertSeverity, number> = {
  extreme:  4,
  severe:   3,
  moderate: 2,
  minor:    1,
}

const NINA_SEVERITY_MAP: Record<AlertSeverity, NinaWarning['severity']> = {
  minor:    'Minor',
  moderate: 'Moderate',
  severe:   'Severe',
  extreme:  'Extreme',
}

const DWD_TO_OPENMETEO_ICON: Record<string, string> = {
  'clear-day':           'clear-day',
  'clear-night':         'clear-night',
  'partly-cloudy-day':   'partly-cloudy-day',
  'partly-cloudy-night': 'partly-cloudy-night',
  cloudy:                'cloudy',
  fog:                   'fog',
  wind:                  'wind',
  rain:                  'rain',
  sleet:                 'sleet',
  snow:                  'snow',
  hail:                  'hail',
  thunderstorm:          'thunderstorm',
}

function clampLatLon(lat: number, lon: number): [number, number] {
  // Auf 2 Nachkommastellen runden ⇒ Cache-Key bleibt stabil bei kleinen GPS-Drifts
  return [Math.round(lat * 100) / 100, Math.round(lon * 100) / 100]
}

async function fetchJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) })
    if (!res.ok) return null
    return (await res.json()) as T
  } catch {
    return null
  }
}

// ── 1) Weather Alerts ───────────────────────────────────────────────────────

interface BrightSkyAlertsResponse {
  alerts?: Array<{
    id?: number | string
    status?: string
    effective?: string
    onset?: string
    expires?: string
    event_de?: string
    event_en?: string
    headline_de?: string
    headline_en?: string
    description_de?: string
    description_en?: string
    instruction_de?: string
    instruction_en?: string
    severity?: string
  }>
}

function mapBrightSkyAlert(raw: NonNullable<BrightSkyAlertsResponse['alerts']>[number]): WeatherAlert | null {
  const id = raw.id != null ? String(raw.id) : ''
  if (!id) return null

  const severityRaw = (raw.severity ?? 'minor').toLowerCase() as AlertSeverity
  const severity: AlertSeverity = SEVERITY_ALLOWLIST.has(severityRaw) ? severityRaw : 'minor'

  const statusRaw = (raw.status ?? 'actual').toLowerCase() as AlertStatus
  const status: AlertStatus = STATUS_ALLOWLIST.has(statusRaw) ? statusRaw : 'actual'

  return {
    id,
    status,
    effective:   raw.effective   ?? '',
    onset:       raw.onset       ?? '',
    expires:     raw.expires     ?? '',
    event:       raw.event_de    ?? raw.event_en       ?? 'Wetterwarnung',
    severity,
    headline:    raw.headline_de ?? raw.headline_en    ?? '',
    description: raw.description_de ?? raw.description_en ?? '',
    instruction: raw.instruction_de ?? raw.instruction_en ?? '',
  }
}

/**
 * Holt offizielle DWD-Wetterwarnungen für einen Standort.
 * Filtert automatisch abgelaufene und nicht-aktuelle Warnungen aus.
 *
 * @param lat Breitengrad
 * @param lon Längengrad
 * @returns Sortiert nach Schweregrad absteigend
 */
export async function fetchWeatherAlerts(lat: number, lon: number): Promise<WeatherAlert[]> {
  const [latR, lonR] = clampLatLon(lat, lon)
  const cacheKey = `dwd_alerts_${latR}_${lonR}`

  const cached = readCache<WeatherAlert[]>(cacheKey)
  if (cached) return cached

  const json = await fetchJson<BrightSkyAlertsResponse>(
    `${BRIGHTSKY_BASE}/alerts?lat=${latR}&lon=${lonR}`,
  )

  if (!json?.alerts) {
    writeCache(cacheKey, [])
    return []
  }

  const now = Date.now()
  const mapped = json.alerts
    .map(mapBrightSkyAlert)
    .filter((a): a is WeatherAlert => a !== null)
    // Nur aktuelle Production-Alerts; abgelaufene rausfiltern
    .filter(a => a.status === 'actual')
    .filter(a => !a.expires || new Date(a.expires).getTime() > now)
    .sort((a, b) => SEVERITY_RANK[b.severity] - SEVERITY_RANK[a.severity])

  writeCache(cacheKey, mapped)
  return mapped
}

// ── 2) Current Weather (DWD) ────────────────────────────────────────────────

interface BrightSkyCurrentWeatherResponse {
  weather?: {
    timestamp?: string
    temperature?: number
    wind_speed_10?: number
    wind_speed?: number
    wind_direction_10?: number
    wind_direction?: number
    precipitation_10?: number
    precipitation?: number
    sunshine_30?: number
    sunshine?: number
    cloud_cover?: number
    visibility?: number
    icon?: string
  }
}

/**
 * Holt aktuelle DWD-Wetterdaten für einen Standort.
 * Eignet sich als Vergleich/Fallback zu Open-Meteo.
 */
export async function fetchCurrentWeatherDWD(
  lat: number,
  lon: number,
): Promise<DWDCurrentWeather | null> {
  const [latR, lonR] = clampLatLon(lat, lon)
  const cacheKey = `dwd_current_${latR}_${lonR}`

  const cached = readCache<DWDCurrentWeather>(cacheKey)
  if (cached) return cached

  const json = await fetchJson<BrightSkyCurrentWeatherResponse>(
    `${BRIGHTSKY_BASE}/current_weather?lat=${latR}&lon=${lonR}`,
  )

  const w = json?.weather
  if (!w || w.temperature == null) return null

  const iconRaw = w.icon ?? 'cloudy'

  const data: DWDCurrentWeather = {
    temperature:    w.temperature,
    windSpeed:      w.wind_speed_10       ?? w.wind_speed       ?? 0,
    windDirection:  w.wind_direction_10   ?? w.wind_direction   ?? 0,
    precipitation:  w.precipitation_10    ?? w.precipitation    ?? 0,
    sunshine:       w.sunshine_30         ?? w.sunshine         ?? 0,
    cloudCover:     w.cloud_cover         ?? 0,
    visibility:     w.visibility          ?? 0,
    icon:           DWD_TO_OPENMETEO_ICON[iconRaw] ?? 'cloudy',
    timestamp:      w.timestamp           ?? new Date().toISOString(),
  }

  writeCache(cacheKey, data)
  return data
}

// ── 3) Konvertierung in NinaWarning-Form (für unified UI) ────────────────────

/**
 * Konvertiert eine WeatherAlert in das NinaWarning-Format, damit beide
 * Quellen in einem gemeinsamen Banner gerendert werden können.
 */
export function weatherAlertToNinaWarning(alert: WeatherAlert): NinaWarning {
  return {
    id:          `dwd:${alert.id}`,
    version:     0,
    startDate:   alert.onset || alert.effective,
    severity:    NINA_SEVERITY_MAP[alert.severity],
    type:        'weather',
    title:       alert.headline || alert.event,
    description: alert.description,
    instruction: alert.instruction,
    area:        '',
  }
}

// ── 4) Merge-Logik mit Deduplizierung ───────────────────────────────────────

/**
 * Heuristik zur Erkennung von Duplikaten:
 * Wenn zwei Warnungen das gleiche Ereignis (z. B. "Gewitter") und einen
 * überlappenden Zeitraum (innerhalb 6 h) haben, gelten sie als Duplikat.
 *
 * Wir bevorzugen NINA-Quelle, weil das die behördliche Originalmeldung ist;
 * DWD ist die Wetter-Spezialisierung.
 */
function eventsAreSimilar(a: string, b: string): boolean {
  const norm = (s: string) =>
    s.toLowerCase()
      .replace(/[^a-zäöüß ]/g, ' ')
      .split(/\s+/)
      .filter(w => w.length >= 4)
      .slice(0, 3)
      .join(' ')

  const na = norm(a)
  const nb = norm(b)
  if (!na || !nb) return false
  return na === nb || na.includes(nb) || nb.includes(na)
}

/**
 * Merge NINA-Warnungen + DWD-Warnungen in eine einheitliche Liste.
 * Duplikate (gleiches Event + überlappender Zeitraum) werden eliminiert.
 *
 * @param ninaWarnings  Bereits geladene NINA-Warnungen
 * @param dwdAlerts     Geladene Bright-Sky-Warnungen
 */
export function mergeWeatherWarnings(
  ninaWarnings: NinaWarning[],
  dwdAlerts: WeatherAlert[],
): UnifiedWarning[] {
  const SIX_HOURS_MS = 6 * 60 * 60 * 1000

  const ninaUnified: UnifiedWarning[] = ninaWarnings.map(w => ({ ...w, source: 'nina' as const }))

  const dwdUnified: UnifiedWarning[] = []
  for (const a of dwdAlerts) {
    const isDuplicate = ninaWarnings.some(n => {
      if (!eventsAreSimilar(n.title, a.headline) && !eventsAreSimilar(n.title, a.event)) {
        return false
      }
      if (!a.onset || !n.startDate) return true
      const tNina = new Date(n.startDate).getTime()
      const tDwd  = new Date(a.onset).getTime()
      return Math.abs(tNina - tDwd) < SIX_HOURS_MS
    })
    if (isDuplicate) continue

    dwdUnified.push({
      ...weatherAlertToNinaWarning(a),
      source:  'dwd',
      onset:   a.onset,
      expires: a.expires,
      event:   a.event,
    })
  }

  // Sortierung: NINA zuerst (behördlich), dann nach Severity
  const allWarnings = [...ninaUnified, ...dwdUnified]
  return allWarnings.sort((a, b) => {
    const severityDiff = severityRank(b.severity) - severityRank(a.severity)
    if (severityDiff !== 0) return severityDiff
    if (a.source !== b.source) return a.source === 'nina' ? -1 : 1
    return 0
  })
}

function severityRank(s: NinaWarning['severity']): number {
  switch (s) {
    case 'Extreme':  return 4
    case 'Severe':   return 3
    case 'Moderate': return 2
    case 'Minor':    return 1
  }
}

// ── 5) Convenience: parallele Helper für UI ─────────────────────────────────

/**
 * Lädt NINA-Warnungen (über bestehenden API-Endpunkt) und DWD-Warnungen
 * parallel und gibt eine einheitliche Liste zurück.
 *
 * Wird vom NinaWarningBanner verwendet, um beide Quellen kombiniert zu zeigen.
 */
export async function fetchAllWarnings(
  lat?: number,
  lon?: number,
): Promise<UnifiedWarning[]> {
  const ninaPromise = fetch('/api/nina/warnings')
    .then(r => (r.ok ? r.json() : { warnings: [] }))
    .then((j: { warnings?: NinaWarning[] }) => j.warnings ?? [])
    .catch(() => [] as NinaWarning[])

  const dwdPromise = lat != null && lon != null
    ? fetchWeatherAlerts(lat, lon).catch(() => [] as WeatherAlert[])
    : Promise.resolve([] as WeatherAlert[])

  const [nina, dwd] = await Promise.all([ninaPromise, dwdPromise])
  return mergeWeatherWarnings(nina, dwd)
}
