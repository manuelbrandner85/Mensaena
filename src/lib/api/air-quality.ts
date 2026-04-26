// ─────────────────────────────────────────────────────────────────────────────
// Open-Meteo Air Quality – Luftqualität, Pollen und UV-Index
// https://open-meteo.com/en/docs/air-quality-api
//
// Endpunkt:  https://air-quality-api.open-meteo.com/v1/air-quality
// Pollenwerte sind nur in Europa verfügbar (CAMS Europa-Modell).
// AQI ist global nutzbar.
// Kein API-Key, ~10.000 req/Tag.
// ─────────────────────────────────────────────────────────────────────────────

// ── Public Types ─────────────────────────────────────────────────────────────

export type AirLevel = 'good' | 'fair' | 'moderate' | 'poor' | 'very_poor' | 'extremely_poor'

export interface AirQualityData {
  europeanAqi: number
  usAqi: number
  level: AirLevel
  label_de: string
  color: string
  pm10: number
  pm25: number
  ozone: number
  no2: number
  so2: number
  co: number
  dust: number
  uvIndex: number
  fetchedAt: number
}

export type PollenLevel = 'none' | 'low' | 'moderate' | 'high' | 'very_high'

export interface PollenData {
  alder: number
  birch: number
  grass: number
  mugwort: number
  olive: number
  ragweed: number
  dominantPollen: string
  overallLevel: PollenLevel
  label_de: string
  available: boolean
}

export interface AirQualityHourly {
  time: string
  europeanAqi: number
  pm10: number
  pm25: number
  uvIndex: number
}

// ── Konstanten ───────────────────────────────────────────────────────────────

const BASE = 'https://air-quality-api.open-meteo.com/v1/air-quality'
const TIMEOUT_MS = 8_000
const CACHE_TTL_MS = 30 * 60 * 1000 // 30 Min

const AIR_LABELS: Record<AirLevel, { label_de: string; color: string }> = {
  good:             { label_de: 'Gut',                color: '#22c55e' },
  fair:             { label_de: 'Befriedigend',       color: '#84cc16' },
  moderate:         { label_de: 'Mäßig',              color: '#eab308' },
  poor:             { label_de: 'Schlecht',           color: '#f97316' },
  very_poor:        { label_de: 'Sehr schlecht',      color: '#ef4444' },
  extremely_poor:   { label_de: 'Extrem schlecht',    color: '#7f1d1d' },
}

const POLLEN_LABELS: Record<PollenLevel, string> = {
  none: 'Keine', low: 'Schwach', moderate: 'Mäßig', high: 'Stark', very_high: 'Sehr stark',
}

// ── Klassifizierung ──────────────────────────────────────────────────────────

function classifyAqi(value: number): AirLevel {
  if (value <= 20) return 'good'
  if (value <= 40) return 'fair'
  if (value <= 60) return 'moderate'
  if (value <= 80) return 'poor'
  if (value <= 100) return 'very_poor'
  return 'extremely_poor'
}

function classifyPollen(value: number): PollenLevel {
  if (value <= 0) return 'none'
  if (value < 10) return 'low'
  if (value < 30) return 'moderate'
  if (value < 60) return 'high'
  return 'very_high'
}

// ── Caching (sessionStorage) ─────────────────────────────────────────────────

interface CacheBundle {
  air: AirQualityData
  pollen: PollenData
  hourly: AirQualityHourly[]
  ts: number
}

function cacheKey(lat: number, lng: number): string {
  return `mensaena_airquality_${lat.toFixed(2)}_${lng.toFixed(2)}`
}

function readCache(lat: number, lng: number): CacheBundle | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(cacheKey(lat, lng))
    if (!raw) return null
    const c = JSON.parse(raw) as CacheBundle
    if (Date.now() - c.ts < CACHE_TTL_MS) return c
  } catch { /* ignore */ }
  return null
}

function writeCache(lat: number, lng: number, bundle: CacheBundle): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(cacheKey(lat, lng), JSON.stringify(bundle))
  } catch { /* quota */ }
}

// ── Fetch ────────────────────────────────────────────────────────────────────

interface OpenMeteoAirResp {
  current?: {
    european_aqi?: number
    us_aqi?: number
    pm10?: number
    pm2_5?: number
    carbon_monoxide?: number
    nitrogen_dioxide?: number
    sulphur_dioxide?: number
    ozone?: number
    dust?: number
    uv_index?: number
    alder_pollen?: number
    birch_pollen?: number
    grass_pollen?: number
    mugwort_pollen?: number
    olive_pollen?: number
    ragweed_pollen?: number
  }
  hourly?: {
    time: string[]
    pm10?: number[]
    pm2_5?: number[]
    european_aqi?: number[]
    uv_index?: number[]
  }
}

async function fetchOpenMeteoAir(lat: number, lng: number): Promise<OpenMeteoAirResp> {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lng),
    current: [
      'european_aqi', 'us_aqi', 'pm10', 'pm2_5',
      'carbon_monoxide', 'nitrogen_dioxide', 'sulphur_dioxide',
      'ozone', 'dust', 'uv_index',
      'alder_pollen', 'birch_pollen', 'grass_pollen',
      'mugwort_pollen', 'olive_pollen', 'ragweed_pollen',
    ].join(','),
    hourly: ['pm10', 'pm2_5', 'european_aqi', 'uv_index'].join(','),
    timezone: 'auto',
    forecast_days: '5',
  })

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    const res = await fetch(`${BASE}?${params.toString()}`, {
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
      },
    })
    if (!res.ok) throw new Error(`AirQuality ${res.status}`)
    return (await res.json()) as OpenMeteoAirResp
  } finally {
    clearTimeout(timer)
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Lädt aktuelle Luftqualität (AQI, PM, Schadstoffe, UV).
 * Nutzt 30-Minuten-Cache pro Standort (auf 2 Nachkommastellen gerundet).
 */
export async function fetchAirQuality(
  lat: number,
  lng: number,
): Promise<AirQualityData> {
  const cached = readCache(lat, lng)
  if (cached) return cached.air

  const json = await fetchOpenMeteoAir(lat, lng)
  const c = json.current ?? {}
  const aqi = c.european_aqi ?? 0
  const level = classifyAqi(aqi)
  const meta = AIR_LABELS[level]

  const air: AirQualityData = {
    europeanAqi: aqi,
    usAqi: c.us_aqi ?? 0,
    level,
    label_de: meta.label_de,
    color: meta.color,
    pm10: c.pm10 ?? 0,
    pm25: c.pm2_5 ?? 0,
    ozone: c.ozone ?? 0,
    no2: c.nitrogen_dioxide ?? 0,
    so2: c.sulphur_dioxide ?? 0,
    co: c.carbon_monoxide ?? 0,
    dust: c.dust ?? 0,
    uvIndex: c.uv_index ?? 0,
    fetchedAt: Date.now(),
  }

  // Pollen + Hourly mitspeichern für Wiederverwendung
  const pollen = await fetchPollenInternal(json)
  const hourly = mapHourly(json)
  writeCache(lat, lng, { air, pollen, hourly, ts: Date.now() })

  return air
}

function mapHourly(json: OpenMeteoAirResp): AirQualityHourly[] {
  const t = json.hourly?.time ?? []
  return t.map((time, i) => ({
    time,
    europeanAqi: json.hourly?.european_aqi?.[i] ?? 0,
    pm10: json.hourly?.pm10?.[i] ?? 0,
    pm25: json.hourly?.pm2_5?.[i] ?? 0,
    uvIndex: json.hourly?.uv_index?.[i] ?? 0,
  }))
}

async function fetchPollenInternal(json: OpenMeteoAirResp): Promise<PollenData> {
  const c = json.current ?? {}
  const alder = c.alder_pollen ?? 0
  const birch = c.birch_pollen ?? 0
  const grass = c.grass_pollen ?? 0
  const mugwort = c.mugwort_pollen ?? 0
  const olive = c.olive_pollen ?? 0
  const ragweed = c.ragweed_pollen ?? 0

  const max = Math.max(alder, birch, grass, mugwort, olive, ragweed)
  const overallLevel = classifyPollen(max)

  const dominant =
    max === 0
      ? 'Keiner'
      : max === alder ? 'Erle'
      : max === birch ? 'Birke'
      : max === grass ? 'Gräser'
      : max === mugwort ? 'Beifuß'
      : max === olive ? 'Olive'
      : 'Ambrosia'

  // Verfügbarkeit: wenn alle Werte 0 oder undefined sind → wahrscheinlich
  // außerhalb Europas (CAMS-Modell deckt nur EU ab).
  const anyDefined = (
    c.alder_pollen !== undefined || c.birch_pollen !== undefined ||
    c.grass_pollen !== undefined || c.mugwort_pollen !== undefined ||
    c.olive_pollen !== undefined || c.ragweed_pollen !== undefined
  )

  return {
    alder, birch, grass, mugwort, olive, ragweed,
    dominantPollen: dominant,
    overallLevel,
    label_de: POLLEN_LABELS[overallLevel],
    available: anyDefined,
  }
}

/**
 * Lädt aktuelle Pollendaten (nur Europa, sonst `available: false`).
 * 30-Minuten Cache pro Standort.
 */
export async function fetchPollenData(
  lat: number,
  lng: number,
): Promise<PollenData> {
  const cached = readCache(lat, lng)
  if (cached) return cached.pollen
  // Cache-Miss: über fetchAirQuality nachladen (füllt Pollen-Cache mit)
  await fetchAirQuality(lat, lng)
  const second = readCache(lat, lng)
  return second?.pollen ?? {
    alder: 0, birch: 0, grass: 0, mugwort: 0, olive: 0, ragweed: 0,
    dominantPollen: 'Keiner',
    overallLevel: 'none',
    label_de: POLLEN_LABELS.none,
    available: false,
  }
}

/**
 * Lädt 5-Tages-Stunden-Forecast für Luftqualität (PM10, PM2.5, AQI, UV).
 */
export async function fetchAirQualityForecast(
  lat: number,
  lng: number,
): Promise<AirQualityHourly[]> {
  const cached = readCache(lat, lng)
  if (cached) return cached.hourly
  await fetchAirQuality(lat, lng)
  const second = readCache(lat, lng)
  return second?.hourly ?? []
}
