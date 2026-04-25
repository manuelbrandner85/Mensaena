// ── Environmental data services ───────────────────────────────────────────────
// Weather (Bright Sky / DWD) · Air Quality (OpenAQ) · Sun times (sunrise-sunset.org)
// Forecast (Bright Sky 7-day)
// All free, no key required. Cached in sessionStorage (TTL per data type).

const WEATHER_TTL  = 30 * 60 * 1000      // 30 min
const AIR_TTL      = 30 * 60 * 1000      // 30 min
const SUN_TTL      = 12 * 60 * 60 * 1000 // 12 h (changes slowly)
const FORECAST_TTL =  3 * 60 * 60 * 1000 //  3 h

function readCache<T>(k: string, ttl: number): T | null {
  try {
    const raw = sessionStorage.getItem(k)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as { data: T; ts: number }
    if (Date.now() - ts < ttl) return data
  } catch { /* sessionStorage unavailable */ }
  return null
}

function writeCache<T>(k: string, data: T) {
  try { sessionStorage.setItem(k, JSON.stringify({ data, ts: Date.now() })) } catch { /* quota */ }
}

// ── Weather (Bright Sky) ──────────────────────────────────────────────────────

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
      { signal: AbortSignal.timeout(5000) },
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

// ── Air Quality (OpenAQ v2) ───────────────────────────────────────────────────

export type AirLevel = 'good' | 'fair' | 'moderate' | 'poor' | 'very_poor'

export interface AirQualityData {
  pm25: number
  level: AirLevel
  locationName: string | null
}

function pm25ToLevel(pm25: number): AirLevel {
  if (pm25 < 10)  return 'good'
  if (pm25 < 20)  return 'fair'
  if (pm25 < 25)  return 'moderate'
  if (pm25 < 50)  return 'poor'
  return 'very_poor'
}

export async function fetchAirQuality(lat: number, lng: number): Promise<AirQualityData | null> {
  const k = `air_${lat.toFixed(2)}_${lng.toFixed(2)}`
  const cached = readCache<AirQualityData>(k, AIR_TTL)
  if (cached) return cached

  try {
    const url = `https://api.openaq.org/v2/latest?coordinates=${lat},${lng}&radius=25000&limit=1&parameter=pm25&order_by=distance`
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) })
    if (!res.ok) return null
    const json = await res.json()
    const station = json.results?.[0]
    const pm25Measurement = station?.measurements?.find(
      (m: { parameter: string; value: number }) => m.parameter === 'pm25',
    )
    if (!station || !pm25Measurement || typeof pm25Measurement.value !== 'number') return null

    const data: AirQualityData = {
      pm25: pm25Measurement.value,
      level: pm25ToLevel(pm25Measurement.value),
      locationName: station.location ?? null,
    }
    writeCache(k, data)
    return data
  } catch {
    return null
  }
}

// ── Sun times (sunrise-sunset.org) ────────────────────────────────────────────

export interface SunTimes {
  /** ISO timestamp of sunrise in UTC */
  sunrise: string
  /** ISO timestamp of sunset in UTC */
  sunset: string
}

export async function fetchSunTimes(lat: number, lng: number): Promise<SunTimes | null> {
  // Cache per day + coords (sun times change with the date)
  const today = new Date().toISOString().slice(0, 10)
  const k = `sun_${today}_${lat.toFixed(2)}_${lng.toFixed(2)}`
  const cached = readCache<SunTimes>(k, SUN_TTL)
  if (cached) return cached

  try {
    const url = `https://api.sunrise-sunset.org/json?lat=${lat}&lng=${lng}&formatted=0`
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) })
    if (!res.ok) return null
    const json = await res.json()
    if (json.status !== 'OK' || !json.results?.sunrise || !json.results?.sunset) return null

    const data: SunTimes = {
      sunrise: json.results.sunrise,
      sunset:  json.results.sunset,
    }
    writeCache(k, data)
    return data
  } catch {
    return null
  }
}

// ── 7-day forecast (Bright Sky / DWD) ────────────────────────────────────────

export interface DayForecast {
  date: string        // YYYY-MM-DD
  tempHigh: number    // °C
  tempLow: number     // °C
  icon: string        // Bright Sky icon key
  precipitation: number // mm total for day
}

const ICON_EMOJI: Record<string, string> = {
  'clear-day': '☀️', 'clear-night': '🌙',
  'partly-cloudy-day': '⛅', 'partly-cloudy-night': '🌙',
  'cloudy': '☁️', 'fog': '🌫️', 'wind': '💨',
  'rain': '🌧️', 'sleet': '🌨️', 'snow': '❄️',
  'hail': '🌨️', 'thunderstorm': '⛈️',
  'dry': '🌤️', 'moist': '🌦️', 'wet': '🌧️',
  'icy': '🧊',
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
    const lastStr  = lastDate.toISOString().slice(0, 10)

    const res = await fetch(
      `https://api.brightsky.dev/weather?lat=${lat}&lon=${lng}&date=${today}&last_date=${lastStr}`,
      { signal: AbortSignal.timeout(8000) },
    )
    if (!res.ok) return []

    const json = await res.json() as { weather?: Record<string, unknown>[] }

    // Aggregate hourly entries into daily summaries
    const byDay = new Map<string, { temps: number[]; icons: Record<string, number>; precip: number[] }>()
    for (const w of json.weather ?? []) {
      const ts  = (w.timestamp as string).slice(0, 10)
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
