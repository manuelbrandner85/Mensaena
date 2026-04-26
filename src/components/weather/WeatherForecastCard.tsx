'use client'

// ── 7-Tage Forecast Card ──────────────────────────────────────────────────────
// Kompakte Karte für den horizontalen Wochenvorhersage-Scroller.

import {
  Sun, CloudSun, Cloud, CloudFog, CloudDrizzle, CloudHail, CloudRain,
  CloudSnow, Snowflake, CloudLightning, CloudOff, Droplets,
  type LucideIcon,
} from 'lucide-react'
import type { WeatherDaily } from '@/lib/api/weather'

const ICON_MAP: Record<string, LucideIcon> = {
  Sun, CloudSun, Cloud, CloudFog, CloudDrizzle, CloudHail, CloudRain,
  CloudSnow, Snowflake, CloudLightning, CloudOff,
}

export interface WeatherForecastCardProps {
  day: WeatherDaily
}

export function WeatherForecastCard({ day }: WeatherForecastCardProps) {
  const Icon = ICON_MAP[day.icon] ?? CloudOff
  const date = new Date(day.date + 'T00:00:00')
  const weekday = new Intl.DateTimeFormat('de-DE', { weekday: 'short' }).format(date)
  const showUv = day.uvIndexMax >= 3

  return (
    <div
      className="flex min-w-[88px] flex-col items-center gap-1 rounded-xl border border-stone-200 bg-white px-3 py-3 shadow-sm dark:border-ink-700 dark:bg-ink-800"
      aria-label={`${weekday}, ${day.description}, ${Math.round(day.tempMax)}° max, ${Math.round(day.tempMin)}° min`}
    >
      <span className="text-xs font-medium text-ink-500 dark:text-ink-400">
        {weekday}
      </span>
      <Icon aria-hidden className="h-7 w-7 text-primary-500" />
      <div className="text-sm font-semibold text-ink-900 dark:text-stone-100">
        {Math.round(day.tempMax)}°
      </div>
      <div className="text-xs text-ink-500 dark:text-ink-400">
        {Math.round(day.tempMin)}°
      </div>
      {day.precipitationProbability > 20 && (
        <div className="flex items-center gap-1 text-[11px] text-blue-600 dark:text-blue-300">
          <Droplets aria-hidden className="h-3 w-3" />
          {Math.round(day.precipitationProbability)}%
        </div>
      )}
      {showUv && (
        <span
          className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
          aria-label={`UV-Index ${Math.round(day.uvIndexMax)}`}
        >
          UV {Math.round(day.uvIndexMax)}
        </span>
      )}
    </div>
  )
}

export default WeatherForecastCard
