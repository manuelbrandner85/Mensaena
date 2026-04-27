'use client'

// ── AirQualityWidget ──────────────────────────────────────────────────────────
// Zeigt aktuellen AQI als SVG-Ring + Hauptschadstoffe + UV-Index.
// Compact: nur AQI-Wert + Label.

import { useEffect, useState } from 'react'
import { Wind, Droplets, Cloud, Activity, Sun, AlertCircle } from 'lucide-react'
import { fetchAirQuality, type AirQualityData } from '@/lib/api/air-quality'

export interface AirQualityWidgetProps {
  latitude: number
  longitude: number
  compact?: boolean
  className?: string
}

const RING_RADIUS = 36
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS

function uvLabel(value: number): string {
  if (value < 3) return 'Niedrig'
  if (value < 6) return 'Mäßig'
  if (value < 8) return 'Hoch'
  if (value < 11) return 'Sehr hoch'
  return 'Extrem'
}

function uvColor(value: number): string {
  if (value < 3) return '#22c55e'
  if (value < 6) return '#eab308'
  if (value < 8) return '#f97316'
  if (value < 11) return '#ef4444'
  return '#7f1d1d'
}

export function AirQualityWidget({
  latitude,
  longitude,
  compact = false,
  className = '',
}: AirQualityWidgetProps) {
  const [data, setData] = useState<AirQualityData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetchAirQuality(latitude, longitude)
      .then(d => { if (!cancelled) setData(d) })
      .catch(() => { if (!cancelled) setError('Luftqualität konnte nicht geladen werden.') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [latitude, longitude])

  if (loading) {
    return (
      <div
        role="status"
        aria-label="Luftqualität wird geladen"
        className={`animate-pulse rounded-xl border border-stone-200 bg-white p-4 dark:border-ink-700 dark:bg-ink-800 ${className}`}
      >
        <div className="h-6 w-32 rounded bg-stone-200 dark:bg-ink-700" />
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
        <span>{error ?? 'Keine Daten verfügbar.'}</span>
      </div>
    )
  }

  const aqi = Math.max(0, Math.min(150, Math.round(data.europeanAqi)))
  const offset = RING_CIRCUMFERENCE * (1 - aqi / 100)

  if (compact) {
    return (
      <div
        className={`flex items-center gap-3 rounded-xl border border-stone-200 bg-white px-4 py-2 dark:border-ink-700 dark:bg-ink-800 ${className}`}
        aria-label={`Luftqualität: ${data.label_de}, AQI ${aqi}`}
      >
        <span
          className="flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold text-white"
          style={{ backgroundColor: data.color }}
        >
          {aqi}
        </span>
        <div className="flex flex-col leading-tight">
          <span className="text-xs text-ink-500 dark:text-ink-400">Luftqualität</span>
          <span className="text-sm font-semibold text-ink-900 dark:text-stone-100">
            {data.label_de}
          </span>
        </div>
      </div>
    )
  }

  return (
    <section
      className={`rounded-xl border border-stone-200 bg-white p-4 dark:border-ink-700 dark:bg-ink-800 ${className}`}
      aria-label="Luftqualität"
    >
      <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-ink-900 dark:text-stone-100">
        <Wind aria-hidden className="h-4 w-4 text-primary-500" />
        Luftqualität
      </h3>

      <div className="flex items-center gap-4">
        <svg width="96" height="96" viewBox="0 0 96 96" role="img" aria-label={`AQI ${aqi}`}>
          <circle
            cx="48" cy="48" r={RING_RADIUS}
            stroke="currentColor"
            className="text-stone-300 dark:text-ink-700"
            strokeWidth="8" fill="none"
          />
          <circle
            cx="48" cy="48" r={RING_RADIUS}
            stroke={data.color}
            strokeWidth="8" fill="none"
            strokeDasharray={RING_CIRCUMFERENCE}
            strokeDashoffset={offset}
            strokeLinecap="round"
            transform="rotate(-90 48 48)"
            style={{ transition: 'stroke-dashoffset 0.5s ease' }}
          />
          <text
            x="48" y="46" textAnchor="middle"
            className="fill-stone-900 dark:fill-stone-100"
            fontSize="22" fontWeight="700"
          >
            {aqi}
          </text>
          <text
            x="48" y="62" textAnchor="middle"
            className="fill-stone-500 dark:fill-stone-400"
            fontSize="9"
          >
            EU-AQI
          </text>
        </svg>

        <div className="flex-1">
          <div className="text-base font-semibold" style={{ color: data.color }}>
            {data.label_de}
          </div>
          <div className="text-xs text-ink-500 dark:text-ink-400">
            Quelle: Open-Meteo (CAMS)
          </div>
        </div>
      </div>

      {/* Schadstoffe + UV */}
      <dl className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <Pill label="PM2,5" value={`${data.pm25.toFixed(1)} µg/m³`} icon={Droplets} />
        <Pill label="PM10"  value={`${data.pm10.toFixed(1)} µg/m³`} icon={Droplets} />
        <Pill label="Ozon"  value={`${Math.round(data.ozone)} µg/m³`} icon={Cloud} />
        <Pill label="NO₂"   value={`${Math.round(data.no2)} µg/m³`} icon={Activity} />
        <Pill
          label="UV"
          value={`${Math.round(data.uvIndex)} · ${uvLabel(data.uvIndex)}`}
          icon={Sun}
          color={uvColor(data.uvIndex)}
        />
      </dl>
    </section>
  )
}

function Pill({
  label, value, icon: Icon, color,
}: {
  label: string; value: string; icon: typeof Wind; color?: string
}) {
  return (
    <div className="flex items-center gap-2 rounded-lg bg-stone-50 px-3 py-2 dark:bg-ink-900/40">
      <Icon aria-hidden className="h-3.5 w-3.5" style={{ color: color ?? '#6b7280' }} />
      <div className="flex flex-col leading-tight">
        <dt className="text-xs uppercase text-ink-500 dark:text-ink-400">{label}</dt>
        <dd className="text-xs font-semibold text-ink-900 dark:text-stone-100">{value}</dd>
      </div>
    </div>
  )
}

export default AirQualityWidget
