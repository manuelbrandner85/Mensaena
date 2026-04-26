// ─────────────────────────────────────────────────────────────────────────────
// MeteoAlarm – Unwetterwarnungen aus 38 europäischen Wetterdiensten
// https://www.meteoalarm.org · CAP/EDR-Feed, kein API-Key
//
// EDR-Endpunkt:  https://api.meteoalarm.org/edr/v1/collections/warnings/locations/{countryCode}
// countryCode    ISO-3166-1 Alpha-2 (z. B. 'DE', 'AT', 'CH')
//
// Feed wird alle ~10 Minuten aktualisiert. Falls der Endpunkt aus
// CORS-/Zugriffsgründen nicht erreichbar ist, liefern wir leise [].
// ─────────────────────────────────────────────────────────────────────────────

// ── Public Types ─────────────────────────────────────────────────────────────

export type MeteoAlarmSeverity = 'Minor' | 'Moderate' | 'Severe' | 'Extreme'
export type MeteoAlarmUrgency  = 'Immediate' | 'Expected' | 'Future' | 'Past'
export type MeteoAlarmCertainty = 'Observed' | 'Likely' | 'Possible' | 'Unlikely'

export interface MeteoAlarmWarning {
  id: string
  event: string
  severity: MeteoAlarmSeverity
  urgency: MeteoAlarmUrgency
  certainty: MeteoAlarmCertainty
  onset: string             // ISO 8601
  expires: string           // ISO 8601
  headline: string
  description: string
  areaDesc: string
  senderName: string
  source: 'meteoalarm'
}

// ── Konstanten ───────────────────────────────────────────────────────────────

const BASE_URL = 'https://api.meteoalarm.org/edr/v1/collections/warnings/locations'
const TIMEOUT_MS = 10_000
const CACHE_TTL_MS = 15 * 60 * 1000 // 15 Min

const SEVERITY_ORDER: Record<MeteoAlarmSeverity, number> = {
  Extreme: 4, Severe: 3, Moderate: 2, Minor: 1,
}

// ── Cache ────────────────────────────────────────────────────────────────────

interface CacheEntry { data: MeteoAlarmWarning[]; ts: number }

function cacheKey(countryCode: string): string {
  return `mensaena_meteoalarm_${countryCode.toUpperCase()}`
}

function readCache(countryCode: string): MeteoAlarmWarning[] | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(cacheKey(countryCode))
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* ignore */ }
  return null
}

function writeCache(countryCode: string, data: MeteoAlarmWarning[]): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(
      cacheKey(countryCode),
      JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry),
    )
  } catch { /* quota */ }
}

// ── Mapping ──────────────────────────────────────────────────────────────────

interface CapInfo {
  identifier?: string
  event?: string
  severity?: string
  urgency?: string
  certainty?: string
  onset?: string
  expires?: string
  headline?: string
  description?: string
  area?: { description?: string; areaDesc?: string }
  senderName?: string
  sender_name?: string
}

interface EdrFeature {
  properties?: CapInfo & {
    info?: CapInfo[] | CapInfo
    identifier?: string
  }
  id?: string
}

interface EdrCollection {
  features?: EdrFeature[]
}

function pickInfo(props: EdrFeature['properties']): CapInfo | null {
  if (!props) return null
  if (Array.isArray(props.info)) {
    const de = props.info.find(i => /de/i.test(JSON.stringify(i))) ?? props.info[0]
    return de ?? null
  }
  if (props.info && typeof props.info === 'object') return props.info as CapInfo
  return props
}

function normaliseSeverity(s: string | undefined): MeteoAlarmSeverity {
  if (!s) return 'Minor'
  const cap = s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
  if (cap === 'Extreme' || cap === 'Severe' || cap === 'Moderate' || cap === 'Minor') {
    return cap
  }
  return 'Minor'
}

function normaliseUrgency(s: string | undefined): MeteoAlarmUrgency {
  if (!s) return 'Future'
  const cap = s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
  if (cap === 'Immediate' || cap === 'Expected' || cap === 'Future' || cap === 'Past') {
    return cap
  }
  return 'Future'
}

function normaliseCertainty(s: string | undefined): MeteoAlarmCertainty {
  if (!s) return 'Possible'
  const cap = s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
  if (cap === 'Observed' || cap === 'Likely' || cap === 'Possible' || cap === 'Unlikely') {
    return cap
  }
  return 'Possible'
}

function mapFeature(feat: EdrFeature): MeteoAlarmWarning | null {
  const info = pickInfo(feat.properties)
  if (!info) return null
  const id = String(feat.id ?? feat.properties?.identifier ?? info.identifier ?? '')
  if (!id) return null

  return {
    id,
    event: info.event ?? 'Unwetter',
    severity: normaliseSeverity(info.severity),
    urgency: normaliseUrgency(info.urgency),
    certainty: normaliseCertainty(info.certainty),
    onset: info.onset ?? '',
    expires: info.expires ?? '',
    headline: info.headline ?? info.event ?? 'Wetterwarnung',
    description: info.description ?? '',
    areaDesc: info.area?.description ?? info.area?.areaDesc ?? '',
    senderName: info.senderName ?? info.sender_name ?? 'MeteoAlarm',
    source: 'meteoalarm',
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Lädt aktive Wetterwarnungen für ein Land (ISO-3166-1 Alpha-2).
 * Liefert leeres Array bei Netzwerk-/Mapping-Fehlern (silent fail).
 *
 * Filtert abgelaufene Warnungen (`expires` vor jetzt) heraus und sortiert
 * nach Schweregrad absteigend (Extreme → Minor).
 */
export async function fetchMeteoAlarmWarnings(
  countryCode: string,
): Promise<MeteoAlarmWarning[]> {
  if (!countryCode) return []
  const cc = countryCode.toUpperCase()

  const cached = readCache(cc)
  if (cached) return cached

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)

  try {
    const url = `${BASE_URL}/${cc}`
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
      },
    })
    if (!res.ok) {
      writeCache(cc, [])
      return []
    }
    const json = (await res.json()) as EdrCollection
    const now = Date.now()

    const warnings = (json.features ?? [])
      .map(mapFeature)
      .filter((w): w is MeteoAlarmWarning => w !== null)
      .filter(w => {
        if (!w.expires) return true
        const t = Date.parse(w.expires)
        return isNaN(t) || t > now
      })
      .sort((a, b) => SEVERITY_ORDER[b.severity] - SEVERITY_ORDER[a.severity])

    writeCache(cc, warnings)
    return warnings
  } catch {
    writeCache(cc, [])
    return []
  } finally {
    clearTimeout(timer)
  }
}
