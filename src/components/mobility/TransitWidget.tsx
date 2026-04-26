'use client'

import { useState, useEffect, useCallback } from 'react'
import { Train, Bus, MapPin, Clock, RefreshCw, ChevronRight, AlertCircle, Navigation } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchNearbyStops, fetchDepartures, formatTime, formatDelay,
  type TransitStop, type TransitDeparture,
} from '@/lib/api/transit'

// ── Line badge ────────────────────────────────────────────────────────────────

function LineBadge({ line, color }: { line: string; color: string | null }) {
  const bg = color ?? '#2563EB'
  return (
    <span
      className="inline-flex items-center justify-center min-w-[32px] px-1.5 h-6 rounded-md text-white text-[11px] font-bold flex-shrink-0 tabular-nums"
      style={{ backgroundColor: bg }}
    >
      {line}
    </span>
  )
}

// ── Departure row ─────────────────────────────────────────────────────────────

function DepartureRow({ dep }: { dep: TransitDeparture }) {
  const delay = formatDelay(dep.delay)
  const time  = formatTime(dep.when ?? dep.plannedWhen)
  return (
    <div className={cn(
      'flex items-center gap-2.5 py-1.5 border-b border-stone-100 last:border-0',
      dep.cancelled && 'opacity-40 line-through',
    )}>
      <LineBadge line={dep.line} color={dep.color} />
      <span className="flex-1 text-sm text-ink-700 truncate">{dep.direction ?? '–'}</span>
      {dep.platform && (
        <span className="text-[11px] text-stone-400 hidden sm:block">Gl. {dep.platform}</span>
      )}
      <span className={cn(
        'text-sm font-semibold tabular-nums flex-shrink-0',
        delay ? 'text-orange-600' : 'text-ink-900',
      )}>
        {time}
      </span>
      {delay && (
        <span className="text-[10px] font-medium text-orange-500 flex-shrink-0 hidden sm:block">
          {delay}
        </span>
      )}
    </div>
  )
}

// ── Stop panel ────────────────────────────────────────────────────────────────

function StopPanel({
  stop,
  expanded,
  onToggle,
}: {
  stop: TransitStop
  expanded: boolean
  onToggle: () => void
}) {
  const [departures, setDepartures] = useState<TransitDeparture[]>([])
  const [loading, setLoading]       = useState(false)

  useEffect(() => {
    if (!expanded) return
    setLoading(true)
    fetchDepartures(stop.id, 6).then((deps) => {
      setDepartures(deps)
      setLoading(false)
    })
  }, [expanded, stop.id])

  const hasTransit = stop.products.some(p => ['subway', 'suburban', 'tram'].includes(p))
  const Icon = hasTransit ? Train : Bus

  return (
    <div className="border border-stone-200 rounded-xl overflow-hidden">
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center gap-2.5 px-3 py-2.5 bg-white hover:bg-stone-50 transition-colors text-left"
      >
        <Icon className="w-4 h-4 text-indigo-500 flex-shrink-0" />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-ink-900 truncate">{stop.name}</p>
          <p className="text-[11px] text-stone-400">{Math.round(stop.distance)} m entfernt</p>
        </div>
        <ChevronRight className={cn(
          'w-4 h-4 text-stone-400 transition-transform',
          expanded && 'rotate-90',
        )} />
      </button>

      {expanded && (
        <div className="px-3 pb-3 pt-1 bg-stone-50/80">
          {loading ? (
            <div className="flex items-center gap-2 py-2 text-xs text-stone-400">
              <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              Abfahrten werden geladen…
            </div>
          ) : departures.length === 0 ? (
            <p className="text-xs text-stone-400 py-2">Keine Abfahrten in den nächsten 60 Minuten</p>
          ) : (
            <div className="divide-y divide-stone-100">
              {departures.map((dep, i) => <DepartureRow key={`${dep.tripId}-${i}`} dep={dep} />)}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// ── Main widget ───────────────────────────────────────────────────────────────

export default function TransitWidget() {
  const [stops,        setStops]        = useState<TransitStop[]>([])
  const [loading,      setLoading]      = useState(true)
  const [error,        setError]        = useState<string | null>(null)
  const [expandedStop, setExpandedStop] = useState<string | null>(null)

  const loadStops = useCallback((lat: number, lng: number) => {
    setLoading(true)
    setError(null)
    fetchNearbyStops(lat, lng, 4).then((result) => {
      setStops(result)
      if (result.length > 0) setExpandedStop(result[0].id) // auto-open nearest
      setLoading(false)
    })
  }, [])

  useEffect(() => {
    if (!navigator.geolocation) {
      // Default to geographic center of Germany
      loadStops(51.165, 10.451)
      return
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => loadStops(pos.coords.latitude, pos.coords.longitude),
      ()    => loadStops(51.165, 10.451), // fallback on denied/error
      { timeout: 5000 },
    )
  }, [loadStops])

  if (loading) {
    return (
      <div className="relative bg-indigo-50 border border-indigo-200 rounded-2xl p-5 shadow-soft">
        <div className="flex items-center gap-2 mb-4">
          <Train className="w-5 h-5 text-indigo-600" />
          <h3 className="font-bold text-indigo-900">ÖPNV in der Nähe</h3>
        </div>
        <div className="space-y-2">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-12 bg-indigo-100/60 rounded-xl animate-pulse" />
          ))}
        </div>
      </div>
    )
  }

  if (error || stops.length === 0) {
    return (
      <div className="flex items-center gap-2.5 p-4 rounded-xl bg-stone-50 border border-stone-200">
        <AlertCircle className="w-4 h-4 text-stone-400 flex-shrink-0" />
        <p className="text-sm text-stone-500">Keine ÖPNV-Haltestellen in der Nähe gefunden.</p>
      </div>
    )
  }

  return (
    <div className="relative bg-gradient-to-br from-indigo-50 to-blue-50/60 border border-indigo-200 rounded-2xl p-5 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #6366F1, #6366F133)' }}
      />

      <div className="flex items-center gap-2 mb-4">
        <Train className="w-5 h-5 text-indigo-600 float-idle" />
        <h3 className="font-bold text-indigo-900">ÖPNV in der Nähe</h3>
        <span className="ml-auto flex items-center gap-1 text-[11px] text-indigo-500">
          <Navigation className="w-3 h-3" />
          Live
        </span>
      </div>

      <div className="space-y-2">
        {stops.map((stop) => (
          <StopPanel
            key={stop.id}
            stop={stop}
            expanded={expandedStop === stop.id}
            onToggle={() => setExpandedStop(prev => prev === stop.id ? null : stop.id)}
          />
        ))}
      </div>

      <p className="mt-3 flex items-center gap-1 text-[11px] text-indigo-400">
        <Clock className="w-3 h-3" />
        Echtzeit-Abfahrten · Deutsche Bahn Open Data
      </p>
    </div>
  )
}
