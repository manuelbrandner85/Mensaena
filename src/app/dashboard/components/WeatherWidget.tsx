'use client'

import { useEffect, useState } from 'react'
import { Sunrise, Sunset, Wind } from 'lucide-react'
import {
  fetchAirQuality,
  fetchSunTimes,
  fetchWeather,
  type AirLevel,
  type AirQualityData,
  type SunTimes,
  type WeatherData,
} from '@/lib/services/weather'

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

const AIR_LABEL: Record<AirLevel, string> = {
  good:           'Gute Luft',
  fair:           'Ordentlich',
  moderate:       'Mäßig',
  poor:           'Schlecht',
  very_poor:      'Sehr schlecht',
  extremely_poor: 'Extrem schlecht',
}

const AIR_COLOR: Record<AirLevel, string> = {
  good:           'text-green-700 bg-green-50 border-green-200',
  fair:           'text-lime-700 bg-lime-50 border-lime-200',
  moderate:       'text-amber-700 bg-amber-50 border-amber-200',
  poor:           'text-orange-700 bg-orange-50 border-orange-200',
  very_poor:      'text-red-700 bg-red-50 border-red-200',
  extremely_poor: 'text-red-900 bg-red-100 border-red-400',
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
}

function hint(w: WeatherData, air: AirQualityData | null): string | null {
  const { temperature: t, icon } = w
  if (icon === 'thunderstorm')                  return 'Gewitter – drinnen bleiben und Nachbarn informieren. ⚡'
  if (icon === 'snow' || icon === 'sleet')      return 'Schnee – Gehwege freihalten! Hilf älteren Nachbarn. 🏠'
  if (t < 0)                                    return 'Frost! Hilf älteren Nachbarn beim Räumen. 🧤'
  if (air?.level === 'extremely_poor' ||
      air?.level === 'very_poor')               return 'Luft sehr schlecht – drinnen bleiben, besonders bei Asthma oder Herzleiden. 🫁'
  if (air?.level === 'poor')                    return 'Luft schlecht – Fenster schließen, schaue nach älteren Nachbarn. 🌫️'
  if (icon === 'rain')                          return 'Hast du einen Regenschirm übrig? Deine Nachbarn danken es dir. ☂️'
  if (icon === 'fog')                           return 'Nebel – Vorsicht beim Radfahren und zu Fuß. 🚶'
  if (icon === 'wind')                          return 'Wind – Blumentöpfe und Gartenmöbel sichern! 🌀'
  if (t >= 30)                                  return 'Heiß! Biete deinen Nachbarn etwas Wasser an. 💧'
  return null
}

// ── Component ──────────────────────────────────────────────────────────────────

interface WeatherWidgetProps {
  lat: number
  lng: number
}

export default function WeatherWidget({ lat, lng }: WeatherWidgetProps) {
  const [weather, setWeather] = useState<WeatherData | null | 'loading'>('loading')
  const [air, setAir]         = useState<AirQualityData | null>(null)
  const [sun, setSun]         = useState<SunTimes | null>(null)

  useEffect(() => {
    fetchWeather(lat, lng).then(setWeather)
    fetchAirQuality(lat, lng).then(setAir)
    fetchSunTimes(lat, lng).then(setSun)
  }, [lat, lng])

  if (weather === 'loading') {
    return <div className="rounded-2xl bg-stone-100 animate-pulse h-28" />
  }

  if (!weather) return null

  const emoji = EMOJI[weather.icon] ?? '🌡️'
  const label = LABEL[weather.icon] ?? weather.icon
  const tip   = hint(weather, air)

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

      {/* Air quality + sun times */}
      {(air || sun) && (
        <div className="mt-3 flex flex-wrap items-center gap-2 text-[11px]">
          {air && (
            <span
              title={`Luftqualität (EU AQI: ${air.europeanAqi}) · PM2.5: ${air.pm25.toFixed(0)} µg/m³ · PM10: ${air.pm10.toFixed(0)} µg/m³`}
              className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border font-medium ${AIR_COLOR[air.level]}`}
            >
              <Wind className="w-3 h-3" />
              {AIR_LABEL[air.level]}
            </span>
          )}
          {sun && (
            <>
              <span className="inline-flex items-center gap-1 text-ink-500">
                <Sunrise className="w-3 h-3 text-amber-500" />
                {formatTime(sun.sunrise)}
              </span>
              <span className="inline-flex items-center gap-1 text-ink-500">
                <Sunset className="w-3 h-3 text-orange-500" />
                {formatTime(sun.sunset)}
              </span>
            </>
          )}
        </div>
      )}

      {/* Contextual neighbour hint */}
      {tip && (
        <p className="mt-3 text-xs text-ink-600 leading-relaxed bg-primary-50 rounded-xl px-3 py-2 border border-primary-100">
          {tip}
        </p>
      )}
    </div>
  )
}
