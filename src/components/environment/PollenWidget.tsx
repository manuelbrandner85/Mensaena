'use client'

import { useState, useEffect } from 'react'
import { Wind, RefreshCw, MapPin, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchPollenRegion, fetchPollenPeak, closestRegionId,
  pollenLevelLabel, pollenLevelDot, pollenLevelColorClass,
  type PollenEntry, type PollenRegion,
} from '@/lib/api/pollen'

// ── DWD regions for manual selection ─────────────────────────────────────────

const REGIONS: { id: number; label: string }[] = [
  { id: 10, label: 'Schleswig-Holstein & Hamburg' },
  { id: 11, label: 'Mecklenburg-Vorpommern' },
  { id: 12, label: 'Brandenburg & Berlin' },
  { id: 20, label: 'Niedersachsen & Bremen' },
  { id: 31, label: 'Sachsen-Anhalt' },
  { id: 32, label: 'Thüringen' },
  { id: 33, label: 'Sachsen' },
  { id: 41, label: 'Westfalen' },
  { id: 42, label: 'Rheinland & Ruhrgebiet' },
  { id: 50, label: 'Hessen & Rhein-Main' },
  { id: 61, label: 'Bayern (Nord)' },
  { id: 62, label: 'Bayern (Süd)' },
  { id: 71, label: 'Alpen & Alpenvorland' },
  { id: 91, label: 'Rheinland-Pfalz' },
  { id: 92, label: 'Saarland' },
  { id: 93, label: 'Baden-Württemberg' },
]

// ── Single pollen row ─────────────────────────────────────────────────────────

function PollenRow({ entry }: { entry: PollenEntry }) {
  const maxLevel = Math.max(entry.today, entry.tomorrow, 0)
  if (maxLevel <= 0) return null
  return (
    <div className="flex items-center gap-2 py-1.5 border-b border-stone-100 last:border-0">
      <span className="text-base flex-shrink-0 w-6 text-center">{entry.emoji}</span>
      <span className="flex-1 text-sm text-ink-700">{entry.label}</span>
      {/* Today */}
      <div className="text-right w-16">
        <span className={cn(
          'inline-flex items-center gap-1 text-[11px] font-medium px-1.5 py-0.5 rounded-full border',
          pollenLevelColorClass(entry.today),
        )}>
          <span className={cn('w-1.5 h-1.5 rounded-full flex-shrink-0', pollenLevelDot(entry.today))} />
          {pollenLevelLabel(entry.today)}
        </span>
      </div>
      {/* Tomorrow arrow */}
      <div className="text-right w-16 hidden sm:block">
        <span className={cn(
          'inline-flex items-center gap-1 text-[11px] px-1.5 py-0.5 rounded-full border',
          pollenLevelColorClass(entry.tomorrow),
        )}>
          {pollenLevelLabel(entry.tomorrow)}
        </span>
      </div>
    </div>
  )
}

// ── Widget ────────────────────────────────────────────────────────────────────

interface PollenWidgetProps {
  className?: string
  compact?: boolean  // show only active high-level pollens
}

export default function PollenWidget({ className, compact = false }: PollenWidgetProps) {
  const [region,          setRegion]    = useState<PollenRegion | null>(null)
  const [loading,         setLoading]   = useState(true)
  const [showSelector,    setSelector]  = useState(false)
  const [selectedId,      setSelectedId] = useState<number | null>(null)
  const [locationLabel,   setLocLabel]  = useState('Aktueller Standort')

  useEffect(() => {
    const loadForLocation = (lat: number, lng: number) => {
      const id = closestRegionId(lat, lng)
      setSelectedId(id)
      fetchPollenRegion(id).then((r) => { setRegion(r); setLoading(false) })
    }
    const loadPeak = () => {
      fetchPollenPeak().then((peaks) => {
        // Wrap peak entries into a pseudo-region
        setRegion({
          regionId: 0,
          regionName: 'Deutschland (Höchstwerte)',
          pollens: peaks,
          lastUpdate: '',
        })
        setLocLabel('Deutschland')
        setLoading(false)
      })
    }

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          setLocLabel('Dein Standort')
          loadForLocation(pos.coords.latitude, pos.coords.longitude)
        },
        loadPeak,
        { timeout: 4000 },
      )
    } else {
      loadPeak()
    }
  }, [])

  const handleRegionChange = (id: number) => {
    setSelectedId(id)
    setSelector(false)
    setLoading(true)
    const label = REGIONS.find(r => r.id === id)?.label ?? ''
    setLocLabel(label)
    fetchPollenRegion(id).then((r) => { setRegion(r); setLoading(false) })
  }

  const activePollens = (region?.pollens ?? []).filter(p => p.today > 0 || p.tomorrow > 0)

  if (loading) {
    return (
      <div className={cn('rounded-2xl border border-green-200 bg-green-50 p-4', className)}>
        <div className="flex items-center gap-2 mb-3">
          <Wind className="w-4 h-4 text-green-600" />
          <h3 className="text-sm font-bold text-green-900">Pollenflug</h3>
        </div>
        <div className="space-y-1.5">
          {[1, 2, 3].map(i => <div key={i} className="h-8 bg-green-100 rounded-lg animate-pulse" />)}
        </div>
      </div>
    )
  }

  if (!region || activePollens.length === 0) {
    return (
      <div className={cn('rounded-2xl border border-green-200 bg-green-50 p-4', className)}>
        <div className="flex items-center gap-2">
          <Wind className="w-4 h-4 text-green-600" />
          <h3 className="text-sm font-bold text-green-900">Pollenflug</h3>
        </div>
        <p className="mt-2 text-xs text-green-700">
          Derzeit kein nennenswerter Pollenflug in deiner Region.
        </p>
      </div>
    )
  }

  const displayPollens = compact ? activePollens.filter(p => p.today >= 2) : activePollens

  return (
    <div className={cn('rounded-2xl border border-primary-200 bg-gradient-to-br from-primary-50 to-primary-50/40 overflow-hidden', className)}>
      <div className="flex items-center gap-2 px-4 pt-4 pb-2">
        <Wind className="w-4 h-4 text-green-600 flex-shrink-0" />
        <h3 className="text-sm font-bold text-green-900">Pollenflug</h3>
        <button
          type="button"
          onClick={() => setSelector(prev => !prev)}
          className="ml-auto flex items-center gap-1 text-[11px] text-green-600 hover:text-green-800 transition-colors"
        >
          <MapPin className="w-3 h-3" />
          <span className="max-w-[120px] truncate">{locationLabel}</span>
          <ChevronDown className={cn('w-3 h-3 transition-transform', showSelector && 'rotate-180')} />
        </button>
      </div>

      {/* Region selector */}
      {showSelector && (
        <div className="mx-4 mb-2 rounded-xl border border-green-200 bg-white shadow-sm overflow-hidden max-h-44 overflow-y-auto">
          {REGIONS.map(r => (
            <button
              key={r.id}
              type="button"
              onClick={() => handleRegionChange(r.id)}
              className={cn(
                'w-full text-left px-3 py-2 text-xs hover:bg-green-50 transition-colors border-b border-stone-50 last:border-0',
                selectedId === r.id && 'bg-green-50 font-semibold text-green-800',
              )}
            >
              {r.label}
            </button>
          ))}
        </div>
      )}

      {/* Column headers */}
      <div className="flex items-center gap-2 px-4 pb-1">
        <span className="flex-1 text-xs text-stone-400 uppercase tracking-wide" />
        <span className="w-16 text-xs text-stone-400 uppercase tracking-wide text-right">Heute</span>
        <span className="w-16 text-xs text-stone-400 uppercase tracking-wide text-right hidden sm:block">Morgen</span>
      </div>

      <div className="px-4 pb-4">
        {(displayPollens.length === 0 ? activePollens : displayPollens).map(p => (
          <PollenRow key={p.key} entry={p} />
        ))}
        {compact && activePollens.filter(p => p.today < 2).length > 0 && (
          <p className="text-[11px] text-stone-400 mt-1.5">
            + {activePollens.filter(p => p.today < 2).length} weitere mit geringer Belastung
          </p>
        )}
      </div>

      <div className="flex items-center gap-1 px-4 pb-3 text-[11px] text-green-500">
        <RefreshCw className="w-3 h-3" />
        DWD Pollenflug-Gefahrenindex · tägl. aktualisiert
      </div>
    </div>
  )
}
