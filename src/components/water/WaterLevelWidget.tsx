'use client'

import { useEffect, useState } from 'react'
import { Waves, TrendingUp, TrendingDown, Minus, AlertTriangle, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import {
  fetchNearbyStations,
  fetchStationMeasurements,
  getWarningLevel,
  WARNING_COLORS,
  type WaterStation,
  type WaterMeasurement,
} from '@/lib/api/waterlevel'

const NEARBY_RADIUS_KM = 50
const STATION_COUNT = 3

function formatDate(iso: string): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return d.toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function TrendIcon({ trend }: { trend: WaterStation['trend'] }) {
  if (trend === 'rising')  return <TrendingUp   className="w-3.5 h-3.5 text-orange-500"   aria-label="steigend" />
  if (trend === 'falling') return <TrendingDown className="w-3.5 h-3.5 text-emerald-500"  aria-label="fallend" />
  return                          <Minus        className="w-3.5 h-3.5 text-stone-400"    aria-label="stabil" />
}

function Sparkline({ data, color }: { data: WaterMeasurement[]; color: string }) {
  if (data.length < 2) return <div className="h-12 flex items-center justify-center text-[10px] text-stone-400">Keine Verlaufsdaten</div>

  const W = 280, H = 48, P = 2
  const values = data.map(d => d.value)
  const min = Math.min(...values)
  const max = Math.max(...values)
  const range = max - min || 1

  const points = data.map((d, i) => {
    const x = P + (i / (data.length - 1)) * (W - 2 * P)
    const y = H - P - ((d.value - min) / range) * (H - 2 * P)
    return `${x.toFixed(1)},${y.toFixed(1)}`
  }).join(' ')

  // Filled area below line
  const area = `${P},${H} ${points} ${(W - P)},${H}`

  return (
    <div className="relative">
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-12" preserveAspectRatio="none">
        <polygon points={area} fill={color} fillOpacity="0.15" />
        <polyline points={points} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
        {/* Latest point */}
        {points && (() => {
          const [lx, ly] = points.split(' ').pop()!.split(',')
          return <circle cx={lx} cy={ly} r="2.5" fill={color} stroke="white" strokeWidth="1" />
        })()}
      </svg>
      <div className="flex justify-between text-[9px] text-stone-400 px-0.5 -mt-0.5">
        <span>vor 24h: {min}–{max} cm</span>
        <span>jetzt: {values[values.length - 1]} cm</span>
      </div>
    </div>
  )
}

function StationItem({ station }: { station: WaterStation }) {
  const [expanded, setExpanded] = useState(false)
  const [measurements, setMeasurements] = useState<WaterMeasurement[] | null>(null)
  const [loadingMs, setLoadingMs] = useState(false)
  const level = getWarningLevel(station.currentLevel)
  const c = WARNING_COLORS[level]

  useEffect(() => {
    if (!expanded || measurements) return
    setLoadingMs(true)
    fetchStationMeasurements(station.uuid)
      .then(setMeasurements)
      .catch(() => setMeasurements([]))
      .finally(() => setLoadingMs(false))
  }, [expanded, station.uuid, measurements])

  return (
    <div className={cn('rounded-xl border transition-colors', c.bg, level === 'normal' ? 'border-stone-200' : 'border-current')}>
      <button
        type="button"
        onClick={() => setExpanded(e => !e)}
        className="w-full flex items-center gap-2.5 px-3 py-2.5 text-left"
        aria-expanded={expanded}
      >
        <div className={cn('w-2.5 h-2.5 rounded-full ring-2 ring-white flex-shrink-0', level !== 'normal' && 'animate-pulse')}
             style={{ background: c.hex }} />
        <div className="flex-1 min-w-0">
          <p className="text-xs font-medium text-stone-700 truncate">
            {station.name}
            {station.waterName && <span className="text-stone-400 font-normal"> · {station.waterName}</span>}
          </p>
          <p className="text-[10px] text-stone-500 truncate">
            {c.label} · {formatDate(station.timestamp)}
          </p>
        </div>
        <div className="flex items-center gap-1.5 flex-shrink-0">
          <span className={cn('text-base font-bold tabular-nums', c.text)}>
            {station.currentLevel}
          </span>
          <span className="text-[10px] text-stone-500">{station.unit}</span>
          <TrendIcon trend={station.trend} />
          <ChevronDown className={cn('w-3.5 h-3.5 text-stone-400 transition-transform', expanded && 'rotate-180')} />
        </div>
      </button>

      {expanded && (
        <div className="px-3 pb-3 pt-1 border-t border-white/60">
          {loadingMs ? (
            <div className="h-12 bg-white/50 rounded animate-pulse" />
          ) : (
            <Sparkline data={measurements ?? []} color={c.hex} />
          )}
        </div>
      )}
    </div>
  )
}

function Skeleton() {
  return (
    <div className="space-y-2">
      {[1, 2, 3].map(i => (
        <div key={i} className="animate-pulse flex gap-2.5 p-3 rounded-xl bg-stone-50">
          <div className="w-2.5 h-2.5 rounded-full bg-stone-200 mt-1 flex-shrink-0" />
          <div className="flex-1 space-y-1.5">
            <div className="h-3 bg-stone-200 rounded w-2/3" />
            <div className="h-2.5 bg-stone-200 rounded w-1/2" />
          </div>
          <div className="w-12 h-4 bg-stone-200 rounded" />
        </div>
      ))}
    </div>
  )
}

export default function WaterLevelWidget() {
  const [stations, setStations]   = useState<WaterStation[] | null>(null)
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState<string | null>(null)
  const [hasLocation, setHasLocation] = useState<boolean | null>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) { setLoading(false); setHasLocation(false); return }
      supabase.from('profiles').select('latitude, longitude').eq('id', user.id).maybeSingle()
        .then(({ data }) => {
          if (!data?.latitude || !data?.longitude) {
            setHasLocation(false)
            setLoading(false)
            return
          }
          setHasLocation(true)
          fetchNearbyStations(data.latitude, data.longitude, NEARBY_RADIUS_KM)
            .then(s => setStations(s.slice(0, STATION_COUNT)))
            .catch(() => setError('Pegelstände konnten nicht geladen werden.'))
            .finally(() => setLoading(false))
        })
    })
  }, [])

  // Don't render anything if user has no location or no stations within 50km
  if (!loading && (!hasLocation || (stations && stations.length === 0))) return null

  const hasWarning = stations?.some(s => getWarningLevel(s.currentLevel) !== 'normal') ?? false

  return (
    <div className={cn(
      'bg-white rounded-2xl border shadow-soft overflow-hidden transition-all',
      hasWarning
        ? 'border-orange-300 ring-2 ring-orange-100 animate-pulse-slow'
        : 'border-warm-100',
    )}>
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-warm-100">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-blue-100 flex items-center justify-center flex-shrink-0">
            <Waves className="w-4 h-4 text-blue-600" />
          </div>
          <h2 className="text-sm font-semibold text-gray-900">Pegelstände in deiner Nähe</h2>
        </div>
        {hasWarning && (
          <AlertTriangle className="w-4 h-4 text-orange-500 flex-shrink-0" aria-label="Warnung" />
        )}
      </div>

      {/* Body */}
      <div className="p-3 space-y-2">
        {loading ? (
          <Skeleton />
        ) : error ? (
          <p className="text-xs text-red-500 py-2">{error}</p>
        ) : stations && stations.length > 0 ? (
          <>
            {stations.map(s => <StationItem key={s.uuid} station={s} />)}
            {!hasWarning && (
              <p className="text-[11px] text-emerald-600 text-center pt-1">
                Alle Pegel im Normalbereich ✓
              </p>
            )}
          </>
        ) : null}
      </div>
    </div>
  )
}
