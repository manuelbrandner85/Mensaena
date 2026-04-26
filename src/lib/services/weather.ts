// ── Environmental data services ───────────────────────────────────────────────
// Weather  : Bright Sky / DWD (offizielle deutsche Wetterdaten)
// Air Quality: Open-Meteo Air Quality API (ersetzt abgeschaltetes OpenAQ v2)
// Sun times: Open-Meteo Forecast API daily=sunrise,sunset (ersetzt sunrise-sunset.org)
// Forecast : Bright Sky 7-day
// Alle kostenlos, kein API-Key nötig. sessionStorage-Cache mit TTL pro Datentyp.

const WEATHER_TTL  = 30 * 60 * 1000      // 30 min
const AIR_TTL      = 30 * 60 * 1000      // 30 min
const SUN_TTL      = 12 * 60 * 60 * 1000 // 12 h  (Sonnenzeiten ändern sich langsam)
const FORECAST_TTL =  3 * 60 * 60 * 1000 //  3 h
const TIMEOUT_MS   = 8_000

function readCache<T>(k: string, ttl: number): T | null {
  try {
    const raw = sessionStorage.getItem(k)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as { data: T; ts: number }
    if (Date.now() - ts < ttl) return data
  } catch { /* sessionStorage nicht verfügbar */ }
  return null
}

function writeCache<T>(k: string, data: T) {
  try { sessionStorage.setItem(k, JSON.stringify({ data, ts: Date.now() })) } catch { /* quota */ }
}

// ── Wetterdaten (Bright Sky / DWD) ───────────────────────────────────────────

export interface WeatherData {
  temperature: number
  icon: string
}

export async function fetchWeather(lat: number, lng: number): Promise<WeatherData | null> {
  const k = `weather_${lat.toFixed(2)}_${lng.toFixed(2)}`
  const cached = readCache<WeatherData>(k, WEATHER_TTL)
  if (cached) return cached

  try {
    const res = await fetch(
      `https://api.brightsky.dev/current_weather?lat=${lat}&lon=${lng}`,
      { signal: AbortSignal.timeout(TIMEOUT_MS) },
    )
    if (!res.ok) return null
    const json = await res.json()
    const w = json.weather
    if (!w || w.temperature == null) return null

    const data: WeatherData = { temperature: w.temperature, icon: w.icon ?? 'cloudy' }
    writeCache(k, data)
    return data
  } catch {
    return null
  }
}

// ── Luftqualität (Open-Meteo Air Quality API) ─────────────────────────────────
// Ersetzt OpenAQ v2 (https://api.openaq.org/v2/latest) – abgeschaltet.
// Neuer Endpunkt: https://air-quality-api.open-meteo.com/v1/air-quality

export type AirLevel =
  | 'good'
  | 'fair'
  | 'moderate'
  | 'poor'
  | 'very_poor'
  | 'extremely_poor'

export interface AirQualityData {
  europeanAqi:  number
  level:        AirLevel
  label_de:     string
  color:        string
  pm10:         number
  pm25:         number
  ozone:        number
  no2:          number
  so2:          number
  co:           number
  dust:         number
  uvIndex:      number
  fetchedAt:    number
}

function aqiToLevel(aqi: number): AirLevel {
  if (aqi <= 20)  return 'good'
  if (aqi <= 40)  return 'fair'
  if (aqi <= 60)  return 'moderate'
  if (aqi <= 80)  return 'poor'
  if (aqi <= 100) return 'very_poor'
  return 'extremely_poor'
}

const AQI_LABELS: Record<AirLevel, string> = {
  good:           'Gut',
  fair:           'Befriedigend',
  moderate:       'Mäßig',
  poor:           'Schlecht',
  very_poor:      'Sehr schlecht',
  extremely_poor: 'Extrem schlecht',
}

const AQI_COLORS: Record<AirLevel, string> = {
  good:           '#22c55e',
  fair:           '#84cc16',
  moderate:       '#eab308',
  poor:           '#f97316',
  very_poor:      '#ef4444',
  extremely_poor: '#7f1d1d',
}

interface OpenMeteoAirQualityResponse {
  current?: {
    european_aqi?:    number
    pm10?:            number
    pm2_5?:           number
    nitrogen_dioxide?: number
    ozone?:           number
    sulphur_dioxide?: number
    carbon_monoxide?: number
    dust?:            number
    uv_index?:        number
  }
}

export async function fetchAirQuality(lat: number, lng: number): Promise<AirQualityData | null> {
  const k = `mensaena_airquality_${lat.toFixed(2)}_${lng.toFixed(2)}`
  const cached = readCache<AirQualityData>(k, AIR_TTL)
  if (cached) return cached

  try {
    const url =
      'https://air-quality-api.open-meteo.com/v1/air-quality' +
      `?latitude=${lat}&longitude=${lng}` +
      '&current=european_aqi,pm10,pm2_5,nitrogen_dioxide,ozone,sulphur_dioxide,carbon_monoxide,dust,uv_index' +
      '&timezone=auto'

    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) })
    if (!res.ok) return null

    const json = (await res.json()) as OpenMeteoAirQualityResponse
    const c = json.current
    if (!c || c.european_aqi == null) return null

    const aqi   = c.european_aqi
    const level = aqiToLevel(aqi)

    const data: AirQualityData = {
      europeanAqi: aqi,
      level,
      label_de:   AQI_LABELS[level],
      color:      AQI_COLORS[level],
      pm10:       c.pm10             ?? 0,
      pm25:       c.pm2_5            ?? 0,
      ozone:      c.ozone            ?? 0,
      no2:        c.nitrogen_dioxide ?? 0,
      so2:        c.sulphur_dioxide  ?? 0,
      co:         c.carbon_monoxide  ?? 0,
      dust:       c.dust             ?? 0,
      uvIndex:    c.uv_index         ?? 0,
      fetchedAt:  Date.now(),
    }

    writeCache(k, data)
    return data
  } catch {
    return null
  }
}

// ── Sonnenzeiten (Open-Meteo Forecast API) ────────────────────────────────────
// Ersetzt sunrise-sunset.org (https://api.sunrise-sunset.org/json) – entfernt.
// Daten kommen jetzt aus dem Open-Meteo Forecast Response über daily=sunrise,sunset.

export interface SunTimes {
  /** Sonnenaufgang als lokaler Zeitstring (ISO-ähnlich, von Open-Meteo) */
  sunrise: string
  /** Sonnenuntergang als lokaler Zeitstring */
  sunset: string
}

interface OpenMeteoForecastResponse {
  daily?: {
    sunrise?: string[]
    sunset?:  string[]
  }
}

export async function fetchSunTimes(lat: number, lng: number): Promise<SunTimes | null> {
  const today = new Date().toISOString().slice(0, 10)
  const k = `sun_${today}_${lat.toFixed(2)}_${lng.toFixed(2)}`
  const cached = readCache<SunTimes>(k, SUN_TTL)
  if (cached) return cached

  try {
    const url =
      'https://api.open-meteo.com/v1/forecast' +
      `?latitude=${lat}&longitude=${lng}` +
      '&daily=sunrise,sunset' +
      '&timezone=auto' +
      '&forecast_days=1'

    const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) })
    if (!res.ok) return null

    const json = (await res.json()) as OpenMeteoForecastResponse
    const sunrise = json.daily?.sunrise?.[0]
    const sunset  = json.daily?.sunset?.[0]
    if (!sunrise || !sunset) return null

    const data: SunTimes = { sunrise, sunset }
    writeCache(k, data)
    return data
  } catch {
    return null
  }
}

// ── 7-Tage-Vorhersage (Bright Sky / DWD) ─────────────────────────────────────

export interface DayForecast {
  date:          string   // YYYY-MM-DD
  tempHigh:      number   // °C
  tempLow:       number   // °C
  icon:          string   // Bright Sky icon key
  precipitation: number   // mm Tagessumme
}

const ICON_EMOJI: Record<string, string> = {
  'clear-day':           '☀️',
  'clear-night':         '🌙',
  'partly-cloudy-day':   '⛅',
  'partly-cloudy-night': '🌙',
  cloudy:                '☁️',
  fog:                   '🌫️',
  wind:                  '💨',
  rain:                  '🌧️',
  sleet:                 '🌨️',
  snow:                  '❄️',
  hail:                  '🌨️',
  thunderstorm:          '⛈️',
  dry:                   '🌤️',
  moist:                 '🌦️',
  wet:                   '🌧️',
  icy:                   '🧊',
}

export function forecastIconEmoji(icon: string): string {
  return ICON_EMOJI[icon] ?? '🌤️'
}

export async function fetchForecast(lat: number, lng: number, days = 7): Promise<DayForecast[]> {
  const today = new Date().toISOString().slice(0, 10)
  const k = `forecast_${lat.toFixed(2)}_${lng.toFixed(2)}_${today}`
  const cached = readCache<DayForecast[]>(k, FORECAST_TTL)
  if (cached) return cached

  try {
    const lastDate = new Date()
    lastDate.setDate(lastDate.getDate() + days)
    const lastStr = lastDate.toISOString().slice(0, 10)

    const res = await fetch(
      `https://api.brightsky.dev/weather?lat=${lat}&lon=${lng}&date=${today}&last_date=${lastStr}`,
      { signal: AbortSignal.timeout(TIMEOUT_MS) },
    )
    if (!res.ok) return []

    const json = await res.json() as { weather?: Record<string, unknown>[] }

    const byDay = new Map<string, { temps: number[]; icons: Record<string, number>; precip: number[] }>()
    for (const w of json.weather ?? []) {
      const ts = (w.timestamp as string).slice(0, 10)
      if (!byDay.has(ts)) byDay.set(ts, { temps: [], icons: {}, precip: [] })
      const e = byDay.get(ts)!
      if (w.temperature != null) e.temps.push(w.temperature as number)
      const ic = (w.icon as string) || 'cloudy'
      e.icons[ic] = (e.icons[ic] ?? 0) + 1
      if (w.precipitation != null) e.precip.push(w.precipitation as number)
    }

    const forecast: DayForecast[] = []
    for (const [date, e] of byDay.entries()) {
      if (!e.temps.length) continue
      const dominantIcon = Object.entries(e.icons).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'cloudy'
      forecast.push({
        date,
        tempHigh:      Math.round(Math.max(...e.temps)),
        tempLow:       Math.round(Math.min(...e.temps)),
        icon:          dominantIcon,
        precipitation: Math.round(e.precip.reduce((a, b) => a + b, 0) * 10) / 10,
      })
    }

    const result = forecast.slice(0, days)
    writeCache(k, result)
    return result
  } catch {
    return []
  }
}
