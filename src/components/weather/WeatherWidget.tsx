'use client'

// ── WeatherWidget ─────────────────────────────────────────────────────────────
// Lädt fetchWeather(lat, lng) und zeigt Aktuelle Werte + 7-Tage Forecast.
// In compact-Modus nur Temperatur + Icon + Beschreibung (für Header/Sidebar).
// Voll-Modus: aktuelle Karte + horizontaler Forecast-Scroller + Sunrise/Sunset.

import { useEffect, useState } from 'react'
import {
  Sun, Moon, Sunrise, Sunset, Wind, Droplets, Thermometer,
  CloudSun, Cloud, CloudFog, CloudDrizzle, CloudHail, CloudRain,
  CloudSnow, Snowflake, CloudLightning, CloudOff, AlertCircle,
  type LucideIcon,
} from 'lucide-react'
import { fetchWeather, type WeatherData } from '@/lib/api/weather'
import { WeatherForecastCard } from './WeatherForecastCard'

const ICON_MAP: Record<string, LucideIcon> = {
  Sun, CloudSun, Cloud, CloudFog, CloudDrizzle, CloudHail, CloudRain,
  CloudSnow, Snowflake, CloudLightning, CloudOff,
}

export interface WeatherWidgetProps {
  latitude: number
  longitude: number
  compact?: boolean
  className?: string
}

function formatTime(iso: string): string {
  if (!iso) return '–'
  try {
    const d = new Date(iso)
    return d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
  } catch {
    return '–'
  }
}

export function WeatherWidget({
  latitude,
  longitude,
  compact = false,
  className = '',
}: WeatherWidgetProps) {
  const [data, setData] = useState<WeatherData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    fetchWeather(latitude, longitude, 7)
      .then(d => {
        if (!cancelled) setData(d)
      })
      .catch(() => {
        if (!cancelled) setError('Wetterdaten konnten nicht geladen werden.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [latitude, longitude])

  if (loading) {
    return (
      <div
        role="status"
        aria-label="Wetter wird geladen"
        className={`animate-pulse rounded-xl border border-stone-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800 ${className}`}
      >
        <div className="mb-3 h-6 w-32 rounded bg-stone-200 dark:bg-gray-700" />
        <div className="h-12 w-24 rounded bg-stone-200 dark:bg-gray-700" />
      </div>
    )
  }

  if (error || !data) {
    return (
      <div
        role="alert"
        className={`flex items-center gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-100 ${className}`}
      >
        <AlertCircle aria-hidden className="h-4 w-4 flex-shrink-0" />
        <span>{error ?? 'Keine Wetterdaten verfügbar.'}</span>
      </div>
    )
  }

  const { current, daily, source } = data
  const Icon = ICON_MAP[current.icon] ?? CloudOff
  const sourceLabel =
    source === 'brightsky'
      ? 'Daten: DWD via Bright Sky'
      : 'Daten: Open-Meteo'

  if (compact) {
    return (
      <div
        className={`flex items-center gap-3 rounded-xl border border-stone-200 bg-white px-4 py-2 shadow-sm dark:border-gray-700 dark:bg-gray-800 ${className}`}
        aria-label={`Aktuelles Wetter: ${current.description}, ${Math.round(current.temperature)} Grad`}
      >
        <Icon aria-hidden className="h-6 w-6 text-primary-500" />
        <div className="flex flex-col leading-tight">
          <span className="text-base font-semibold text-ink-900 dark:text-gray-100">
            {Math.round(current.temperature)}°C
          </span>
          <span className="text-xs text-ink-500 dark:text-ink-400">
            {current.description}
          </span>
        </div>
      </div>
    )
  }

  const today = daily[0]

  return (
    <section
      className={`rounded-xl border border-stone-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800 ${className}`}
      aria-label="Wetterübersicht"
    >
      {/* Aktuell */}
      <div className="mb-4 flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Icon aria-hidden className="h-12 w-12 text-primary-500" />
          <div>
            <div className="text-3xl font-bold text-ink-900 dark:text-gray-100">
              {Math.round(current.temperature)}°C
            </div>
            <div className="text-sm text-ink-600 dark:text-stone-400">
              {current.description}
            </div>
            <div className="text-xs text-ink-500 dark:text-ink-400">
              gefühlt {Math.round(current.feelsLike)}°
            </div>
          </div>
        </div>
        <div className="hidden text-right text-xs text-ink-500 dark:text-ink-400 sm:block">
          <div className="flex items-center justify-end gap-1">
            <Wind aria-hidden className="h-3 w-3" /> {Math.round(current.windSpeed)} km/h
          </div>
          <div className="flex items-center justify-end gap-1">
            <Droplets aria-hidden className="h-3 w-3" /> {current.humidity}%
          </div>
          <div className="flex items-center justify-end gap-1">
            <Thermometer aria-hidden className="h-3 w-3" /> {current.cloudCover}% Wolken
          </div>
        </div>
      </div>

      {/* Sunrise/Sunset (nur wenn vorhanden) */}
      {today && today.sunrise && today.sunset && (
        <div className="mb-3 flex items-center justify-between rounded-lg bg-stone-50 px-3 py-2 text-xs text-ink-600 dark:bg-gray-900/60 dark:text-stone-400">
          <span className="flex items-center gap-1">
            <Sunrise aria-hidden className="h-3 w-3 text-amber-500" />
            Sonnenaufgang {formatTime(today.sunrise)}
          </span>
          <span className="flex items-center gap-1">
            <Sunset aria-hidden className="h-3 w-3 text-orange-500" />
            Sonnenuntergang {formatTime(today.sunset)}
          </span>
          <span className="hidden sm:flex items-center gap-1">
            {current.isDay ? (
              <Sun aria-hidden className="h-3 w-3 text-yellow-500" />
            ) : (
              <Moon aria-hidden className="h-3 w-3 text-indigo-400" />
            )}
            {current.isDay ? 'Tag' : 'Nacht'}
          </span>
        </div>
      )}

      {/* 7-Tage Forecast */}
      <div className="mb-2 -mx-2 flex gap-2 overflow-x-auto px-2 pb-1">
        {daily.slice(0, 7).map(day => (
          <WeatherForecastCard key={day.date} day={day} />
        ))}
      </div>

      <p className="mt-2 text-[11px] text-ink-400 dark:text-ink-500">
        {sourceLabel}
      </p>
    </section>
  )
}

export default WeatherWidget
