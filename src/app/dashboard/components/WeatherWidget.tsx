'use client'

import { useEffect, useState } from 'react'
import { fetchWeather, type WeatherData } from '@/lib/services/weather'

// ── Lookup tables ──────────────────────────────────────────────────────────────

const EMOJI: Record<string, string> = {
  'clear-day':           '☀️',
  'clear-night':         '🌙',
  'partly-cloudy-day':   '⛅',
  'partly-cloudy-night': '🌥️',
  cloudy:                '☁️',
  fog:                   '🌫️',
  wind:                  '💨',
  rain:                  '🌧️',
  sleet:                 '🌨️',
  snow:                  '❄️',
  hail:                  '🌨️',
  thunderstorm:          '⛈️',
}

const LABEL: Record<string, string> = {
  'clear-day':           'Sonnig',
  'clear-night':         'Klare Nacht',
  'partly-cloudy-day':   'Teilweise bewölkt',
  'partly-cloudy-night': 'Teilweise bewölkt',
  cloudy:                'Bewölkt',
  fog:                   'Neblig',
  wind:                  'Windig',
  rain:                  'Regen',
  sleet:                 'Schneeregen',
  snow:                  'Schnee',
  hail:                  'Hagel',
  thunderstorm:          'Gewitter',
}

function hint(w: WeatherData): string | null {
  const { temperature: t, icon } = w
  if (icon === 'thunderstorm')            return 'Gewitter – drinnen bleiben und Nachbarn informieren. ⚡'
  if (icon === 'snow' || icon === 'sleet') return 'Schnee – Gehwege freihalten! Hilf älteren Nachbarn. 🏠'
  if (t < 0)                              return 'Frost! Hilf älteren Nachbarn beim Räumen. 🧤'
  if (icon === 'rain')                    return 'Hast du einen Regenschirm übrig? Deine Nachbarn danken es dir. ☂️'
  if (icon === 'fog')                     return 'Nebel – Vorsicht beim Radfahren und zu Fuß. 🚶'
  if (icon === 'wind')                    return 'Wind – Blumentöpfe und Gartenmöbel sichern! 🌀'
  if (t >= 30)                            return 'Heiß! Biete deinen Nachbarn etwas Wasser an. 💧'
  return null
}

// ── Component ──────────────────────────────────────────────────────────────────

interface WeatherWidgetProps {
  lat: number
  lng: number
}

export default function WeatherWidget({ lat, lng }: WeatherWidgetProps) {
  const [weather, setWeather] = useState<WeatherData | null | 'loading'>('loading')

  useEffect(() => {
    fetchWeather(lat, lng).then(setWeather)
  }, [lat, lng])

  if (weather === 'loading') {
    return <div className="rounded-2xl bg-stone-100 animate-pulse h-24" />
  }

  if (!weather) return null

  const emoji = EMOJI[weather.icon] ?? '🌡️'
  const label = LABEL[weather.icon] ?? weather.icon
  const tip   = hint(weather)

  return (
    <div className="bg-white rounded-2xl border border-stone-200 shadow-soft p-4">
      {/* Header row */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2.5">
          <span className="text-3xl leading-none" aria-hidden>{emoji}</span>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-ink-500">
              Aktuelles Wetter
            </p>
            <p className="text-base font-bold text-ink-800 leading-tight">
              {Math.round(weather.temperature)} °C
              <span className="ml-1.5 text-sm font-normal text-ink-500">{label}</span>
            </p>
          </div>
        </div>

        <span className="text-[10px] text-ink-400 flex-shrink-0">DWD</span>
      </div>

      {/* Contextual neighbour hint */}
      {tip && (
        <p className="mt-3 text-xs text-ink-600 leading-relaxed bg-primary-50 rounded-xl px-3 py-2 border border-primary-100">
          {tip}
        </p>
      )}
    </div>
  )
}
