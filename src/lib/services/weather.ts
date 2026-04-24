export interface WeatherData {
  temperature: number
  icon: string
}

interface CacheEntry {
  data: WeatherData
  ts: number
}

const TTL = 30 * 60 * 1000

function key(lat: number, lng: number) {
  return `weather_${lat.toFixed(2)}_${lng.toFixed(2)}`
}

export async function fetchWeather(lat: number, lng: number): Promise<WeatherData | null> {
  const k = key(lat, lng)

  try {
    const raw = sessionStorage.getItem(k)
    if (raw) {
      const entry: CacheEntry = JSON.parse(raw)
      if (Date.now() - entry.ts < TTL) return entry.data
    }
  } catch { /* sessionStorage unavailable */ }

  try {
    const res = await fetch(
      `https://api.brightsky.dev/current_weather?lat=${lat}&lon=${lng}`,
      { signal: AbortSignal.timeout(5000) },
    )
    if (!res.ok) return null
    const json = await res.json()
    const w = json.weather
    if (!w || w.temperature == null) return null

    const data: WeatherData = {
      temperature: w.temperature,
      icon: w.icon ?? 'cloudy',
    }

    try { sessionStorage.setItem(k, JSON.stringify({ data, ts: Date.now() })) } catch { /* quota */ }

    return data
  } catch {
    return null
  }
}
