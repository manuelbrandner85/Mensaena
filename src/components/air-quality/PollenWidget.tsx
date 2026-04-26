'use client'

// ── PollenWidget ──────────────────────────────────────────────────────────────
// Balkendiagramm der 6 Pollenarten + dominantes Pollen + Hinweis außerhalb EU.

import { useEffect, useState } from 'react'
import { Flower2, TreeDeciduous, Sprout, AlertCircle, Info } from 'lucide-react'
import { fetchPollenData, type PollenData, type PollenLevel } from '@/lib/api/air-quality'

export interface PollenWidgetProps {
  latitude: number
  longitude: number
  className?: string
}

const POLLEN_COLORS: Record<PollenLevel, string> = {
  none: '#e5e7eb',
  low: '#86efac',
  moderate: '#fbbf24',
  high: '#fb923c',
  very_high: '#ef4444',
}

function levelOf(value: number): PollenLevel {
  if (value <= 0) return 'none'
  if (value < 10) return 'low'
  if (value < 30) return 'moderate'
  if (value < 60) return 'high'
  return 'very_high'
}

interface PollenBar {
  key: keyof Omit<PollenData, 'dominantPollen' | 'overallLevel' | 'label_de' | 'available'>
  label: string
}

const BARS: PollenBar[] = [
  { key: 'alder', label: 'Erle' },
  { key: 'birch', label: 'Birke' },
  { key: 'grass', label: 'Gräser' },
  { key: 'mugwort', label: 'Beifuß' },
  { key: 'olive', label: 'Olive' },
  { key: 'ragweed', label: 'Ambrosia' },
]

export function PollenWidget({
  latitude,
  longitude,
  className = '',
}: PollenWidgetProps) {
  const [data, setData] = useState<PollenData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetchPollenData(latitude, longitude)
      .then(d => { if (!cancelled) setData(d) })
      .catch(() => { if (!cancelled) setError('Pollendaten konnten nicht geladen werden.') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [latitude, longitude])

  if (loading) {
    return (
      <div
        role="status"
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
        <span>{error ?? 'Keine Pollendaten.'}</span>
      </div>
    )
  }

  if (!data.available) {
    return (
      <div
        role="status"
        className={`flex items-start gap-2 rounded-xl border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-900 dark:border-blue-800 dark:bg-blue-950/40 dark:text-blue-100 ${className}`}
      >
        <Info aria-hidden className="mt-0.5 h-4 w-4 flex-shrink-0" />
        <span>Pollenwerte sind nur in Europa verfügbar.</span>
      </div>
    )
  }

  const max = Math.max(...BARS.map(b => Number(data[b.key])))
  const scale = max > 0 ? max : 60

  return (
    <section
      className={`rounded-xl border border-stone-200 bg-white p-4 dark:border-ink-700 dark:bg-ink-800 ${className}`}
      aria-label="Pollenflug"
    >
      <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-ink-900 dark:text-stone-100">
        <Flower2 aria-hidden className="h-4 w-4 text-pink-500" />
        Pollenflug
      </h3>

      {data.dominantPollen !== 'Keiner' && (
        <p className="mb-3 flex items-center gap-2 text-xs text-ink-600 dark:text-stone-400">
          <TreeDeciduous aria-hidden className="h-3.5 w-3.5 text-primary-600" />
          Dominant: <span className="font-semibold">{data.dominantPollen}</span>
          <span className="opacity-60">· {data.label_de}</span>
        </p>
      )}

      <ul className="space-y-2">
        {BARS.map(b => {
          const value = Number(data[b.key])
          const lvl = levelOf(value)
          const widthPct = scale > 0 ? Math.min(100, (value / scale) * 100) : 0
          return (
            <li key={b.key} className="flex items-center gap-2 text-xs">
              <span className="w-16 text-ink-600 dark:text-stone-400">{b.label}</span>
              <div className="relative h-3 flex-1 overflow-hidden rounded-full bg-stone-100 dark:bg-ink-700">
                <div
                  aria-label={`${b.label}: ${value.toFixed(1)} Körner/m³`}
                  className="h-full rounded-full transition-all"
                  style={{ width: `${widthPct}%`, backgroundColor: POLLEN_COLORS[lvl] }}
                />
              </div>
              <span
                className="w-10 text-right text-[11px] font-medium text-ink-700 dark:text-stone-300"
                aria-hidden
              >
                {value.toFixed(0)}
              </span>
            </li>
          )
        })}
      </ul>

      <p className="mt-3 flex items-center gap-1 text-[11px] text-ink-400 dark:text-ink-500">
        <Sprout aria-hidden className="h-3 w-3" />
        Daten: Open-Meteo (CAMS Europa, Körner/m³)
      </p>
    </section>
  )
}

export default PollenWidget
