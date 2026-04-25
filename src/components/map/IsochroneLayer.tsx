'use client'

import { Car, Bike, Footprints, Loader2, Eye, EyeOff } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { RouteProfile } from '@/lib/api/routing'

interface IsochroneLayerProps {
  isVisible: boolean
  isLoading: boolean
  profile: RouteProfile
  onToggle: () => void
  onProfileChange: (p: RouteProfile) => void
  /** Called when user clicks "Berechnen" or switches profile while visible */
  onCalculate: () => void
  error?: string | null
}

const PROFILES: { key: RouteProfile; icon: React.ReactNode; label: string }[] = [
  { key: 'foot', icon: <Footprints className="w-3.5 h-3.5" />, label: 'Fuß' },
  { key: 'bike', icon: <Bike        className="w-3.5 h-3.5" />, label: 'Rad' },
  { key: 'car',  icon: <Car         className="w-3.5 h-3.5" />, label: 'Auto' },
]

export default function IsochroneLayer({
  isVisible,
  isLoading,
  profile,
  onToggle,
  onProfileChange,
  onCalculate,
  error,
}: IsochroneLayerProps) {
  return (
    <div className="bg-white/95 dark:bg-stone-900/95 backdrop-blur-md rounded-2xl shadow-xl border border-stone-200 dark:border-stone-700 overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2.5 border-b border-stone-100 dark:border-stone-800">
        <span className="text-xs font-semibold text-stone-700 dark:text-stone-200">
          Erreichbarkeit
        </span>
        <button
          onClick={onToggle}
          aria-pressed={isVisible}
          aria-label={isVisible ? 'Erreichbarkeit ausblenden' : 'Erreichbarkeit anzeigen'}
          className={cn(
            'flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium transition-colors',
            isVisible
              ? 'bg-primary-600 text-white'
              : 'bg-stone-100 dark:bg-stone-800 text-stone-600 dark:text-stone-300 hover:bg-stone-200 dark:hover:bg-stone-700',
          )}
        >
          {isLoading
            ? <Loader2 className="w-3.5 h-3.5 animate-spin" aria-hidden="true" />
            : isVisible
              ? <Eye    className="w-3.5 h-3.5" aria-hidden="true" />
              : <EyeOff className="w-3.5 h-3.5" aria-hidden="true" />
          }
          {isVisible ? 'An' : 'Aus'}
        </button>
      </div>

      {/* Profile tabs */}
      <div className="flex border-b border-stone-100 dark:border-stone-800">
        {PROFILES.map(p => (
          <button
            key={p.key}
            onClick={() => {
              onProfileChange(p.key)
              if (isVisible) onCalculate()
            }}
            className={cn(
              'flex-1 flex items-center justify-center gap-1 py-2 text-[11px] font-medium transition-colors',
              profile === p.key
                ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300'
                : 'text-stone-500 dark:text-stone-400 hover:bg-stone-50 dark:hover:bg-stone-800',
            )}
          >
            {p.icon}
            <span>{p.label}</span>
          </button>
        ))}
      </div>

      {/* Legend */}
      <div className="px-3 py-2 space-y-1">
        {[
          { label: '5 Min.',  opacity: 0.55 },
          { label: '10 Min.', opacity: 0.35 },
          { label: '15 Min.', opacity: 0.2  },
        ].map(({ label, opacity }) => (
          <div key={label} className="flex items-center gap-2 text-[11px] text-stone-600 dark:text-stone-300">
            <span
              className="w-3 h-3 rounded-sm flex-shrink-0 border border-primary-400"
              style={{ background: `rgba(30,170,166,${opacity})` }}
            />
            {label}
          </div>
        ))}
      </div>

      {error && (
        <p className="px-3 pb-2 text-[11px] text-red-600 dark:text-red-400">{error}</p>
      )}
    </div>
  )
}
