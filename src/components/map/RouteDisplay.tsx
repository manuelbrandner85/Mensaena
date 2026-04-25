'use client'

import { useState } from 'react'
import { Car, Bike, Footprints, X, Loader2, Navigation } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatDistance, formatDuration, type RouteProfile, type RouteResult } from '@/lib/api/routing'

interface RouteDisplayProps {
  routeResult: RouteResult | null
  isLoading: boolean
  profile: RouteProfile
  onProfileChange: (p: RouteProfile) => void
  onCalculate: () => void
  onClear: () => void
  /** If false, hide the entire overlay */
  visible: boolean
  error?: string | null
}

const PROFILES: { key: RouteProfile; icon: React.ReactNode; label: string; color: string }[] = [
  { key: 'car',  icon: <Car  className="w-3.5 h-3.5" />, label: 'Auto',       color: '#3B82F6' },
  { key: 'bike', icon: <Bike className="w-3.5 h-3.5" />, label: 'Fahrrad',    color: '#22C55E' },
  { key: 'foot', icon: <Footprints className="w-3.5 h-3.5" />, label: 'Fuß', color: '#F97316' },
]

const PROFILE_EMOJI: Record<RouteProfile, string> = {
  car:  '🚗',
  bike: '🚴',
  foot: '🚶',
}

export default function RouteDisplay({
  routeResult,
  isLoading,
  profile,
  onProfileChange,
  onCalculate,
  onClear,
  visible,
  error,
}: RouteDisplayProps) {
  const [showSteps, setShowSteps] = useState(false)

  if (!visible) return null

  const activeColor = PROFILES.find(p => p.key === profile)?.color ?? '#3B82F6'

  return (
    <div className="absolute top-3 left-1/2 -translate-x-1/2 z-[500] w-[min(380px,calc(100vw-2rem))] pointer-events-none">
      <div className="bg-white/95 dark:bg-stone-900/95 backdrop-blur-md rounded-2xl shadow-xl border border-stone-200 dark:border-stone-700 overflow-hidden pointer-events-auto">

        {/* Profile tabs */}
        <div className="flex border-b border-stone-100 dark:border-stone-800">
          {PROFILES.map(p => (
            <button
              key={p.key}
              onClick={() => onProfileChange(p.key)}
              className={cn(
                'flex-1 flex items-center justify-center gap-1.5 py-2.5 text-xs font-medium transition-colors',
                profile === p.key
                  ? 'text-white'
                  : 'text-stone-500 dark:text-stone-400 hover:bg-stone-50 dark:hover:bg-stone-800',
              )}
              style={profile === p.key ? { background: p.color } : undefined}
            >
              {p.icon}
              <span className="hidden sm:inline">{p.label}</span>
            </button>
          ))}
        </div>

        {/* Body */}
        <div className="p-3">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-stone-600 dark:text-stone-300 py-1">
              <Loader2 className="w-4 h-4 animate-spin flex-shrink-0" aria-hidden="true" />
              Route wird berechnet…
            </div>
          )}

          {error && !isLoading && (
            <p className="text-sm text-red-600 dark:text-red-400 py-1">{error}</p>
          )}

          {routeResult && !isLoading && (
            <div>
              {/* Summary row */}
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <span
                    className="text-xl leading-none"
                    role="img"
                    aria-label={PROFILES.find(p => p.key === profile)?.label}
                  >
                    {PROFILE_EMOJI[profile]}
                  </span>
                  <div>
                    <p
                      className="text-base font-bold"
                      style={{ color: activeColor }}
                    >
                      {formatDuration(routeResult.durationMin * 60)}
                    </p>
                    <p className="text-xs text-stone-500 dark:text-stone-400">
                      {formatDistance(routeResult.distanceKm * 1000)}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-1">
                  {routeResult.steps && routeResult.steps.length > 0 && (
                    <button
                      onClick={() => setShowSteps(s => !s)}
                      className="px-2 py-1 rounded-lg text-xs font-medium text-stone-600 dark:text-stone-300 hover:bg-stone-100 dark:hover:bg-stone-800 transition-colors"
                    >
                      {showSteps ? 'Weniger' : 'Wegbeschreibung'}
                    </button>
                  )}
                  <button
                    onClick={onClear}
                    aria-label="Route löschen"
                    className="p-1.5 rounded-lg text-stone-400 hover:text-stone-700 dark:hover:text-stone-200 hover:bg-stone-100 dark:hover:bg-stone-800 transition-colors"
                  >
                    <X className="w-4 h-4" aria-hidden="true" />
                  </button>
                </div>
              </div>

              {/* Steps */}
              {showSteps && routeResult.steps && (
                <ol className="mt-3 space-y-1 max-h-48 overflow-y-auto pr-1">
                  {routeResult.steps.map((step, i) => (
                    <li
                      key={i}
                      className="flex items-start gap-2 text-xs text-stone-600 dark:text-stone-300 py-1 border-b border-stone-50 dark:border-stone-800 last:border-0"
                    >
                      <span className="flex-shrink-0 w-4 h-4 rounded-full flex items-center justify-center text-[9px] font-bold text-white mt-0.5"
                            style={{ background: activeColor }}>
                        {i + 1}
                      </span>
                      <span className="flex-1 leading-snug">{step.instruction}</span>
                      <span className="flex-shrink-0 text-stone-400">{formatDistance(step.distance)}</span>
                    </li>
                  ))}
                </ol>
              )}
            </div>
          )}

          {!routeResult && !isLoading && !error && (
            <button
              onClick={onCalculate}
              className="w-full flex items-center justify-center gap-2 py-2 rounded-xl text-sm font-medium text-white transition-colors"
              style={{ background: activeColor }}
            >
              <Navigation className="w-4 h-4" aria-hidden="true" />
              Route berechnen
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
