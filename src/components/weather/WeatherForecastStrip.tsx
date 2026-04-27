'use client'

import { useState, useEffect } from 'react'
import { Cloud, Droplets } from 'lucide-react'
import { cn } from '@/lib/utils'
import { fetchForecast, forecastIconEmoji, type DayForecast } from '@/lib/services/weather'

function dayLabel(dateStr: string): string {
  const d = new Date(dateStr + 'T12:00:00')
  const today     = new Date(); today.setHours(12, 0, 0, 0)
  const tomorrow  = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)

  if (d.toDateString() === today.toDateString())    return 'Heute'
  if (d.toDateString() === tomorrow.toDateString()) return 'Morgen'
  return d.toLocaleDateString('de-DE', { weekday: 'short' })
}

function DayCard({ day, highlighted }: { day: DayForecast; highlighted?: boolean }) {
  return (
    <div className={cn(
      'flex-shrink-0 flex flex-col items-center gap-1 px-3 py-2.5 rounded-xl border transition-colors',
      highlighted
        ? 'bg-purple-50 border-purple-200'
        : 'bg-white border-stone-100 hover:border-stone-200',
    )}>
      <span className="text-[11px] font-semibold text-stone-500 uppercase tracking-wide">
        {dayLabel(day.date)}
      </span>
      <span className="text-2xl leading-none mt-0.5">{forecastIconEmoji(day.icon)}</span>
      <div className="flex items-center gap-1 mt-0.5">
        <span className="text-sm font-bold text-ink-900">{day.tempHigh}°</span>
        <span className="text-xs text-stone-400">{day.tempLow}°</span>
      </div>
      {day.precipitation > 0 && (
        <div className="flex items-center gap-0.5 text-xs text-blue-500">
          <Droplets className="w-2.5 h-2.5" />
          <span>{day.precipitation}mm</span>
        </div>
      )}
    </div>
  )
}

interface WeatherForecastStripProps {
  className?: string
  /** If provided, uses these coords instead of geolocation */
  lat?: number
  lng?: number
  /** Highlighted date (YYYY-MM-DD) – e.g. selected event date */
  highlightDate?: string
  days?: number
}

export default function WeatherForecastStrip({
  className,
  lat: propLat,
  lng: propLng,
  highlightDate,
  days = 7,
}: WeatherForecastStripProps) {
  const [forecast, setForecast] = useState<DayForecast[]>([])
  const [loading,  setLoading]  = useState(true)

  useEffect(() => {
    const load = async (la: number, ln: number) => {
      const result = await fetchForecast(la, ln, days)
      setForecast(result)
      setLoading(false)
    }

    if (propLat != null && propLng != null) {
      load(propLat, propLng)
      return
    }

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => load(pos.coords.latitude, pos.coords.longitude),
        ()    => load(51.165, 10.451),  // centre of Germany
        { timeout: 4000 },
      )
    } else {
      load(51.165, 10.451)
    }
  }, [propLat, propLng, days])

  if (loading) {
    return (
      <div className={cn('flex gap-2 overflow-x-auto no-scrollbar py-0.5', className)}>
        {Array.from({ length: 7 }).map((_, i) => (
          <div key={i} className="flex-shrink-0 w-[68px] h-[92px] rounded-xl bg-stone-100 animate-pulse" />
        ))}
      </div>
    )
  }

  if (!forecast.length) return null

  return (
    <div className={cn('space-y-2', className)}>
      <div className="flex items-center gap-1.5 text-xs text-stone-400">
        <Cloud className="w-3.5 h-3.5" />
        <span>7-Tage-Wettervorhersage · DWD</span>
      </div>
      <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
        {forecast.map((day) => (
          <DayCard
            key={day.date}
            day={day}
            highlighted={!!highlightDate && day.date === highlightDate}
          />
        ))}
      </div>
    </div>
  )
}
