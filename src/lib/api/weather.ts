// ─────────────────────────────────────────────────────────────────────────────
// Wetter-API – Open-Meteo (weltweit) + Bright Sky DE (DWD-Daten) als Fallback
//
//   Open-Meteo:  https://open-meteo.com — keine Registrierung, ~10.000 req/Tag
//   Bright Sky:  https://brightsky.dev  — DWD-Daten, kein Key, fair-use
//
// Die Funktion fetchWeather() entscheidet anhand der Koordinaten:
//   - In Deutschland: zuerst Bright Sky (offizielle DWD-Daten, höhere
//     Granularität), bei Fehler/Timeout Fallback Open-Meteo.
//   - Außerhalb Deutschlands: direkt Open-Meteo.
//
// Beide Quellen werden auf das interne `WeatherData`-Schema gemappt, sodass
// Konsumenten nicht wissen müssen, woher die Daten stammen (außer via
// `source`-Feld).
// ─────────────────────────────────────────────────────────────────────────────

// ── Public Types ─────────────────────────────────────────────────────────────

export interface WeatherCurrent {
  temperature: number      // °C
  feelsLike: number        // °C
  humidity: number         // %
  windSpeed: number        // km/h
  windDirection: number    // ° (0 = N, 90 = O)
  cloudCover: number       // %
  precipitation: number    // mm/h
  weatherCode: number      // WMO
  isDay: boolean
  description: string      // Deutsche Beschreibung
  icon: string             // Lucide-Icon-Name
}

export interface WeatherDaily {
  date: string             // YYYY-MM-DD
  tempMax: number
  tempMin: number
  feelsLikeMax: number
  feelsLikeMin: number
  sunrise: string          // ISO 8601
  sunset: string           // ISO 8601
  precipitationSum: number // mm
  precipitationProbability: number // %
  weatherCode: number
  windSpeedMax: number     // km/h
  uvIndexMax: number
  description: string
  icon: string
}

export interface WeatherHourly {
  time: string             // ISO 8601
  temperature: number
  feelsLike: number
  humidity: number
  precipitation: number    // mm
  precipitationProbability: number // %
  weatherCode: number
  windSpeed: number
  cloudCover: number
  visibility: number       // m
  description: string
  icon: string
}

export interface WeatherData {
  current: WeatherCurrent
  daily: WeatherDaily[]
  hourly: WeatherHourly[]
  source: 'open-meteo' | 'brightsky'
  fetchedAt: number        // Unix ms
}

// ── WMO-Wettercodes ──────────────────────────────────────────────────────────

interface WmoCodeInfo { description: string; icon: string }

const WMO_CODES: Record<number, WmoCodeInfo> = {
  0:  { description: 'Klar',                          icon: 'Sun' },
  1:  { description: 'Überwiegend klar',              icon: 'Sun' },
  2:  { description: 'Teilweise bewölkt',             icon: 'CloudSun' },
  3:  { description: 'Bewölkt',                       icon: 'Cloud' },
  45: { description: 'Nebel',                         icon: 'CloudFog' },
  48: { description: 'Reifnebel',                     icon: 'CloudFog' },
  51: { description: 'Leichter Nieselregen',          icon: 'CloudDrizzle' },
  53: { description: 'Mäßiger Nieselregen',           icon: 'CloudDrizzle' },
  55: { description: 'Starker Nieselregen',           icon: 'CloudDrizzle' },
  56: { description: 'Gefrierender Nieselregen',      icon: 'CloudHail' },
  57: { description: 'Starker gefrierender Nieselregen', icon: 'CloudHail' },
  61: { description: 'Leichter Regen',                icon: 'CloudRain' },
  63: { description: 'Mäßiger Regen',                 icon: 'CloudRain' },
  65: { description: 'Starker Regen',                 icon: 'CloudRain' },
  66: { description: 'Gefrierender Regen',            icon: 'CloudHail' },
  67: { description: 'Starker gefrierender Regen',    icon: 'CloudHail' },
  71: { description: 'Leichter Schneefall',           icon: 'CloudSnow' },
  73: { description: 'Mäßiger Schneefall',            icon: 'CloudSnow' },
  75: { description: 'Starker Schneefall',            icon: 'CloudSnow' },
  77: { description: 'Schneekörner',                  icon: 'Snowflake' },
  80: { description: 'Leichte Regenschauer',          icon: 'CloudRain' },
  81: { description: 'Mäßige Regenschauer',           icon: 'CloudRain' },
  82: { description: 'Heftige Regenschauer',          icon: 'CloudRain' },
  85: { description: 'Leichte Schneeschauer',         icon: 'CloudSnow' },
  86: { description: 'Starke Schneeschauer',          icon: 'CloudSnow' },
  95: { description: 'Gewitter',                      icon: 'CloudLightning' },
  96: { description: 'Gewitter mit Hagel',            icon: 'CloudLightning' },
  99: { description: 'Schweres Gewitter mit Hagel',   icon: 'CloudLightning' },
}

function describeWmo(code: number): WmoCodeInfo {
  return WMO_CODES[code] ?? { description: 'Unbekannt', icon: 'CloudOff' }
}

// ── Geo-Helper ───────────────────────────────────────────────────────────────

/** Schnelltest: liegt der Punkt grob in Deutschland? */
export function isInGermany(lat: number, lng: number): boolean {
  return lat >= 47.27 && lat <= 55.06 && lng >= 5.87 && lng <= 15.04
}

// ── Caching (sessionStorage) ─────────────────────────────────────────────────

const CACHE_TTL_MS = 30 * 60 * 1000 // 30 Min
const TIMEOUT_MS = 8_000

interface CacheEntry { data: WeatherData; ts: number }

function cacheKey(lat: number, lng: number): string {
  return `mensaena_weather_${lat.toFixed(2)}_${lng.toFixed(2)}`
}

function readCache(lat: number, lng: number): WeatherData | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(cacheKey(lat, lng))
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as CacheEntry
    if (Date.now() - ts < CACHE_TTL_MS) return data
  } catch { /* ignore */ }
  return null
}

function writeCache(lat: number, lng: number, data: WeatherData): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(
      cacheKey(lat, lng),
      JSON.stringify({ data, ts: Date.now() } satisfies CacheEntry),
    )
  } catch { /* quota / privacy */ }
}

// ── Fetch-Helper ─────────────────────────────────────────────────────────────

async function fetchJson<T>(url: string, signal: AbortSignal): Promise<T> {
  const res = await fetch(url, {
    signal,
    headers: {
      Accept: 'application/json',
      'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)',
    },
  })
  if (!res.ok) throw new Error(`${url} → ${res.status}`)
  return (await res.json()) as T
}

function withTimeout<T>(p: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  return p(controller.signal).finally(() => clearTimeout(timer))
}

// ── Open-Meteo Implementierung ───────────────────────────────────────────────

interface OpenMeteoResponse {
  current?: {
    temperature_2m: number
    relative_humidity_2m: number
    apparent_temperature: number
    is_day: number
    precipitation: number
    weather_code: number
    cloud_cover: number
    wind_speed_10m: number
    wind_direction_10m: number
  }
  hourly?: {
    time: string[]
    temperature_2m: number[]
    relative_humidity_2m: number[]
    apparent_temperature: number[]
    precipitation_probability: number[]
    precipitation: number[]
    weather_code: number[]
    wind_speed_10m: number[]
    cloud_cover: number[]
    visibility: number[]
  }
  daily?: {
    time: string[]
    weather_code: number[]
    temperature_2m_max: number[]
    temperature_2m_min: number[]
    apparent_temperature_max: number[]
    apparent_temperature_min: number[]
    sunrise: string[]
    sunset: string[]
    precipitation_sum: number[]
    precipitation_probability_max: number[]
    wind_speed_10m_max: number[]
    uv_index_max: number[]
  }
}

/**
 * Lädt Wetterdaten von Open-Meteo (weltweit, kein API-Key).
 * @param lat   Breitengrad
 * @param lng   Längengrad
 * @param days  Anzahl Forecast-Tage (1–16, Default 7)
 */
export async function fetchWeatherOpenMeteo(
  lat: number,
  lng: number,
  days: number = 7,
): Promise<WeatherData> {
  const url =
    `https://api.open-meteo.com/v1/forecast` +
    `?latitude=${lat}&longitude=${lng}` +
    `&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m` +
    `&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,wind_speed_10m,cloud_cover,visibility` +
    `&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,uv_index_max` +
    `&timezone=auto&forecast_days=${days}`

  const json = await withTimeout(s => fetchJson<OpenMeteoResponse>(url, s))

  const c = json.current
  if (!c) throw new Error('Open-Meteo: kein current-Block')
  const cInfo = describeWmo(c.weather_code)

  const current: WeatherCurrent = {
    temperature: c.temperature_2m,
    feelsLike: c.apparent_temperature,
    humidity: c.relative_humidity_2m,
    windSpeed: c.wind_speed_10m,
    windDirection: c.wind_direction_10m,
    cloudCover: c.cloud_cover,
    precipitation: c.precipitation,
    weatherCode: c.weather_code,
    isDay: c.is_day === 1,
    description: cInfo.description,
    icon: cInfo.icon,
  }

  const daily: WeatherDaily[] = (json.daily?.time ?? []).map((date, i) => {
    const d = json.daily!
    const info = describeWmo(d.weather_code[i])
    return {
      date,
      tempMax: d.temperature_2m_max[i],
      tempMin: d.temperature_2m_min[i],
      feelsLikeMax: d.apparent_temperature_max[i],
      feelsLikeMin: d.apparent_temperature_min[i],
      sunrise: d.sunrise[i],
      sunset: d.sunset[i],
      precipitationSum: d.precipitation_sum[i],
      precipitationProbability: d.precipitation_probability_max[i] ?? 0,
      weatherCode: d.weather_code[i],
      windSpeedMax: d.wind_speed_10m_max[i],
      uvIndexMax: d.uv_index_max[i] ?? 0,
      description: info.description,
      icon: info.icon,
    }
  })

  const hourly: WeatherHourly[] = (json.hourly?.time ?? []).map((time, i) => {
    const h = json.hourly!
    const info = describeWmo(h.weather_code[i])
    return {
      time,
      temperature: h.temperature_2m[i],
      feelsLike: h.apparent_temperature[i],
      humidity: h.relative_humidity_2m[i],
      precipitation: h.precipitation[i] ?? 0,
      precipitationProbability: h.precipitation_probability[i] ?? 0,
      weatherCode: h.weather_code[i],
      windSpeed: h.wind_speed_10m[i],
      cloudCover: h.cloud_cover[i] ?? 0,
      visibility: h.visibility[i] ?? 0,
      description: info.description,
      icon: info.icon,
    }
  })

  return {
    current,
    daily,
    hourly,
    source: 'open-meteo',
    fetchedAt: Date.now(),
  }
}

// ── Bright Sky Implementierung ───────────────────────────────────────────────

interface BrightSkyCurrentResp {
  weather: {
    temperature: number | null
    relative_humidity: number | null
    wind_speed: number | null
    wind_direction: number | null
    cloud_cover: number | null
    precipitation_60: number | null
    icon: string | null
    condition: string | null
  } | null
}

interface BrightSkyDailyResp {
  weather: Array<{
    timestamp: string
    temperature: number | null
    precipitation: number | null
    wind_speed: number | null
    wind_direction: number | null
    relative_humidity: number | null
    cloud_cover: number | null
    visibility: number | null
    icon: string | null
    condition: string | null
  }>
}

const BRIGHTSKY_ICON_TO_WMO: Record<string, number> = {
  'clear-day': 0,
  'clear-night': 0,
  'partly-cloudy-day': 2,
  'partly-cloudy-night': 2,
  cloudy: 3,
  fog: 45,
  wind: 3,
  rain: 63,
  sleet: 67,
  snow: 73,
  hail: 96,
  thunderstorm: 95,
}

function brightskyToWmo(icon: string | null): number {
  if (!icon) return 3
  return BRIGHTSKY_ICON_TO_WMO[icon] ?? 3
}

/**
 * Lädt Wetterdaten von Bright Sky (DWD, nur DE).
 * Liefert current + 7 Tage daily + 24h hourly.
 */
export async function fetchWeatherBrightSky(
  lat: number,
  lng: number,
): Promise<WeatherData> {
  const today = new Date()
  const lastDate = new Date(today)
  lastDate.setDate(today.getDate() + 7)
  const fmt = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

  const currentUrl  = `https://api.brightsky.dev/current_weather?lat=${lat}&lon=${lng}`
  const forecastUrl = `https://api.brightsky.dev/weather?lat=${lat}&lon=${lng}&date=${fmt(today)}&last_date=${fmt(lastDate)}`

  const [curJson, fcJson] = await withTimeout(async signal => {
    const [a, b] = await Promise.all([
      fetchJson<BrightSkyCurrentResp>(currentUrl, signal),
      fetchJson<BrightSkyDailyResp>(forecastUrl, signal),
    ])
    return [a, b] as const
  })

  const cw = curJson.weather
  if (!cw) throw new Error('Bright Sky: kein current weather')
  const curWmo = brightskyToWmo(cw.icon)
  const curInfo = describeWmo(curWmo)

  const current: WeatherCurrent = {
    temperature: cw.temperature ?? 0,
    feelsLike: cw.temperature ?? 0,
    humidity: cw.relative_humidity ?? 0,
    windSpeed: cw.wind_speed ?? 0,
    windDirection: cw.wind_direction ?? 0,
    cloudCover: cw.cloud_cover ?? 0,
    precipitation: cw.precipitation_60 ?? 0,
    weatherCode: curWmo,
    isDay: !!cw.icon && !cw.icon.includes('night'),
    description: curInfo.description,
    icon: curInfo.icon,
  }

  // hourly: alle Stunden aus fcJson
  const hourly: WeatherHourly[] = fcJson.weather.map(h => {
    const wmo = brightskyToWmo(h.icon)
    const info = describeWmo(wmo)
    return {
      time: h.timestamp,
      temperature: h.temperature ?? 0,
      feelsLike: h.temperature ?? 0,
      humidity: h.relative_humidity ?? 0,
      precipitation: h.precipitation ?? 0,
      precipitationProbability: 0, // Bright Sky liefert keine Probability
      weatherCode: wmo,
      windSpeed: h.wind_speed ?? 0,
      cloudCover: h.cloud_cover ?? 0,
      visibility: h.visibility ?? 0,
      description: info.description,
      icon: info.icon,
    }
  })

  // daily: aus hourly aggregieren (min/max pro Datum)
  const dailyMap = new Map<string, WeatherHourly[]>()
  for (const h of hourly) {
    const date = h.time.slice(0, 10)
    const arr = dailyMap.get(date) ?? []
    arr.push(h)
    dailyMap.set(date, arr)
  }

  const daily: WeatherDaily[] = Array.from(dailyMap.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, items]) => {
      const temps = items.map(i => i.temperature)
      const winds = items.map(i => i.windSpeed)
      const precips = items.map(i => i.precipitation)
      const dominant = items[Math.floor(items.length / 2)] ?? items[0]
      const info = describeWmo(dominant.weatherCode)
      return {
        date,
        tempMax: Math.max(...temps),
        tempMin: Math.min(...temps),
        feelsLikeMax: Math.max(...temps),
        feelsLikeMin: Math.min(...temps),
        sunrise: '',
        sunset: '',
        precipitationSum: precips.reduce((a, b) => a + b, 0),
        precipitationProbability: 0,
        weatherCode: dominant.weatherCode,
        windSpeedMax: Math.max(...winds),
        uvIndexMax: 0,
        description: info.description,
        icon: info.icon,
      }
    })

  return {
    current,
    daily,
    hourly,
    source: 'brightsky',
    fetchedAt: Date.now(),
  }
}

// ── Public Entry-Point ───────────────────────────────────────────────────────

/**
 * Liefert Wetterdaten für die Koordinaten.
 *
 * Strategie:
 *  - In DE: Bright Sky zuerst, bei Fehler/Timeout Fallback Open-Meteo.
 *  - Außerhalb DE: direkt Open-Meteo.
 *
 * Cached 30 Minuten in sessionStorage (Schlüssel auf 2 Nachkommastellen).
 */
export async function fetchWeather(
  lat: number,
  lng: number,
  days: number = 7,
): Promise<WeatherData> {
  const cached = readCache(lat, lng)
  if (cached) return cached

  if (isInGermany(lat, lng)) {
    try {
      const brightsky = await fetchWeatherBrightSky(lat, lng)
      writeCache(lat, lng, brightsky)
      return brightsky
    } catch {
      // Fallback Open-Meteo
    }
  }

  const data = await fetchWeatherOpenMeteo(lat, lng, days)
  writeCache(lat, lng, data)
  return data
}
