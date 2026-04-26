'use client'

import { useEffect, useState, useCallback, useRef } from 'react'
import {
  Car, AlertTriangle, Construction, ShieldAlert,
  ChevronDown, ChevronUp, RefreshCw, Plus, X, Settings2,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import {
  fetchAutobahnTraffic,
  getNearbyAutobahns,
  ALL_AUTOBAHNS,
  type AutobahnWarning,
  type AutobahnRoadwork,
  type WarningType,
} from '@/lib/api/autobahn'

// ── Constants ─────────────────────────────────────────────────────────────────

const LS_ROADS_KEY    = 'mensaena_traffic_roads'
const LS_ENABLED_KEY  = 'mensaena_pendler_mode'

// ── Helpers ───────────────────────────────────────────────────────────────────

const TYPE_META: Record<WarningType, { icon: React.ReactNode; label: string; color: string; bg: string }> = {
  jam:      { icon: <Car className="w-4 h-4" />,           label: 'Stau',      color: 'text-red-600',       bg: 'bg-red-50 border-red-200' },
  closure:  { icon: <ShieldAlert className="w-4 h-4" />,   label: 'Sperrung',  color: 'text-rose-700',      bg: 'bg-rose-50 border-rose-200' },
  roadwork: { icon: <Construction className="w-4 h-4" />,  label: 'Baustelle', color: 'text-amber-600',     bg: 'bg-amber-50 border-amber-200' },
  hazard:   { icon: <AlertTriangle className="w-4 h-4" />, label: 'Gefahr',    color: 'text-orange-500',    bg: 'bg-orange-50 border-orange-200' },
  other:    { icon: <AlertTriangle className="w-4 h-4" />, label: 'Hinweis',   color: 'text-ink-500',      bg: 'bg-stone-50 border-stone-200' },
}

interface TrafficItem {
  id:          string
  roadId:      string
  title:       string
  subtitle:    string
  description: string
  type:        WarningType | 'roadwork_item'
  isBlocked?:  boolean
}

function toItems(roadId: string, warnings: AutobahnWarning[], roadworks: AutobahnRoadwork[]): TrafficItem[] {
  return [
    ...warnings.map(w => ({
      id:          w.identifier,
      roadId,
      title:       w.title,
      subtitle:    w.subtitle,
      description: w.description,
      type:        w.type as WarningType,
      isBlocked:   w.isBlocked,
    })),
    ...roadworks.map(r => ({
      id:          r.identifier,
      roadId,
      title:       r.title,
      subtitle:    r.subtitle,
      description: r.description,
      type:        'roadwork' as WarningType,
    })),
  ]
}

// ── Sub-components ────────────────────────────────────────────────────────────

function Skeleton() {
  return (
    <div className="space-y-2 animate-pulse">
      {[1, 2, 3].map(i => (
        <div key={i} className="h-12 rounded-xl bg-stone-100" />
      ))}
    </div>
  )
}

function TrafficItemRow({ item }: { item: TrafficItem }) {
  const [expanded, setExpanded] = useState(false)
  const type  = item.type === 'roadwork_item' ? 'roadwork' : item.type as WarningType
  const meta  = TYPE_META[type] ?? TYPE_META.other
  const hasDetail = !!(item.subtitle || item.description)

  return (
    <div className={cn('rounded-xl border text-sm transition-all', meta.bg)}>
      <button
        type="button"
        onClick={() => hasDetail && setExpanded(e => !e)}
        className={cn(
          'w-full flex items-center gap-2.5 px-3 py-2.5 text-left',
          hasDetail ? 'cursor-pointer' : 'cursor-default',
        )}
      >
        <span className={cn('flex-shrink-0', meta.color)}>{meta.icon}</span>
        <div className="flex-1 min-w-0">
          <span className="font-medium text-ink-900 leading-snug line-clamp-1">{item.title}</span>
        </div>
        <span className={cn('text-[10px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-full flex-shrink-0', meta.color, 'bg-white/70')}>
          {item.roadId}
        </span>
        {hasDetail && (
          <span className={cn('flex-shrink-0', meta.color)}>
            {expanded ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
          </span>
        )}
      </button>

      {expanded && hasDetail && (
        <div className="px-3 pb-3 space-y-1 border-t border-white/50 pt-2">
          {item.subtitle && (
            <p className="text-xs text-ink-600 font-medium">{item.subtitle}</p>
          )}
          {item.description && (
            <p className="text-xs text-ink-500 whitespace-pre-line leading-relaxed">
              {item.description}
            </p>
          )}
        </div>
      )}
    </div>
  )
}

function RoadSelector({
  selected,
  onAdd,
  onRemove,
}: {
  selected: string[]
  onAdd: (r: string) => void
  onRemove: (r: string) => void
}) {
  const [open, setOpen] = useState(false)
  const available = ALL_AUTOBAHNS.filter(r => !selected.includes(r))

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-700 font-medium"
      >
        <Plus className="w-3.5 h-3.5" /> Autobahn hinzufügen
      </button>

      {open && (
        <div className="absolute top-6 left-0 z-50 bg-white border border-stone-200 rounded-xl shadow-lg p-2 w-48 max-h-48 overflow-y-auto">
          {available.map(r => (
            <button
              key={r}
              type="button"
              onClick={() => { onAdd(r); setOpen(false) }}
              className="w-full text-left px-3 py-1.5 text-sm rounded-lg hover:bg-stone-50 font-medium text-ink-800"
            >
              {r}
            </button>
          ))}
          {available.length === 0 && (
            <p className="text-xs text-ink-400 px-3 py-2">Alle hinzugefügt</p>
          )}
        </div>
      )}
    </div>
  )
}

// ── Main Widget ───────────────────────────────────────────────────────────────

export default function TrafficWidget({ className }: { className?: string }) {
  const [enabled, setEnabled]     = useState(false)
  const [roads, setRoads]         = useState<string[]>([])
  const [items, setItems]         = useState<TrafficItem[]>([])
  const [loading, setLoading]     = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [editMode, setEditMode]   = useState(false)
  const [fetchedAt, setFetchedAt] = useState<number | null>(null)
  const loadedRoadsRef            = useRef<string>('')

  // Hydrate from localStorage
  useEffect(() => {
    const stored   = localStorage.getItem(LS_ENABLED_KEY)
    const isOn     = stored === 'true'
    setEnabled(isOn)
    const storedRoads = localStorage.getItem(LS_ROADS_KEY)
    if (storedRoads) {
      try { setRoads(JSON.parse(storedRoads)) } catch { /* ignore */ }
    }
  }, [])

  // When enabled first time with no roads saved, detect from profile
  useEffect(() => {
    if (!enabled || roads.length > 0) return
    let cancelled = false
    ;(async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user || cancelled) return
      const { data } = await supabase
        .from('profiles').select('latitude,longitude').eq('id', user.id).maybeSingle()
      if (cancelled) return
      if (data?.latitude != null && data?.longitude != null) {
        const detected = getNearbyAutobahns(data.latitude as number, data.longitude as number)
        setRoads(detected)
        localStorage.setItem(LS_ROADS_KEY, JSON.stringify(detected))
      } else {
        // Fallback if no location stored
        const defaultRoads = ['A1', 'A3', 'A7', 'A9']
        setRoads(defaultRoads)
        localStorage.setItem(LS_ROADS_KEY, JSON.stringify(defaultRoads))
      }
    })()
    return () => { cancelled = true }
  }, [enabled, roads.length])

  const loadTraffic = useCallback(async (roadList: string[]) => {
    if (roadList.length === 0) return
    const key = roadList.join(',')
    if (key === loadedRoadsRef.current && !refreshing) return
    loadedRoadsRef.current = key

    setLoading(true)
    const results = await Promise.all(roadList.map(fetchAutobahnTraffic))
    const allItems = results.flatMap(r => toItems(r.roadId, r.warnings, r.roadworks))
    // Sort: closures first, then jams, then hazards, then roadworks, then other
    const order: Record<WarningType, number> = { closure: 0, jam: 1, hazard: 2, roadwork: 3, other: 4 }
    allItems.sort((a, b) => {
      const ta = a.type === 'roadwork_item' ? 'roadwork' : a.type as WarningType
      const tb = b.type === 'roadwork_item' ? 'roadwork' : b.type as WarningType
      return (order[ta] ?? 4) - (order[tb] ?? 4)
    })
    setItems(allItems)
    setFetchedAt(Date.now())
    setLoading(false)
    setRefreshing(false)
  }, [refreshing])

  // Load when roads become available or change
  useEffect(() => {
    if (!enabled || roads.length === 0) return
    loadTraffic(roads)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, roads])

  const handleToggle = useCallback(() => {
    const next = !enabled
    setEnabled(next)
    localStorage.setItem(LS_ENABLED_KEY, String(next))
  }, [enabled])

  const handleRefresh = useCallback(async () => {
    // Clear cache keys so fresh data is fetched
    roads.forEach(r => {
      sessionStorage.removeItem(`autobahn_warn_${r}`)
      sessionStorage.removeItem(`autobahn_rw_${r}`)
    })
    loadedRoadsRef.current = ''
    setRefreshing(true)
    await loadTraffic(roads)
  }, [roads, loadTraffic])

  const handleAddRoad = useCallback((road: string) => {
    setRoads(prev => {
      const next = [...prev, road]
      localStorage.setItem(LS_ROADS_KEY, JSON.stringify(next))
      loadedRoadsRef.current = ''
      return next
    })
  }, [])

  const handleRemoveRoad = useCallback((road: string) => {
    setRoads(prev => {
      const next = prev.filter(r => r !== road)
      localStorage.setItem(LS_ROADS_KEY, JSON.stringify(next))
      loadedRoadsRef.current = ''
      return next
    })
  }, [])

  const closureCount  = items.filter(i => i.type === 'closure').length
  const jamCount      = items.filter(i => i.type === 'jam').length
  const roadworkCount = items.filter(i => i.type === 'roadwork').length
  const hazardCount   = items.filter(i => i.type === 'hazard').length
  const totalProblems = closureCount + jamCount + hazardCount
  const isClear       = items.length === 0

  const ageMin = fetchedAt ? Math.floor((Date.now() - fetchedAt) / 60_000) : null

  return (
    <div className={cn(
      'relative bg-white border border-stone-200 rounded-2xl overflow-hidden shadow-soft',
      className,
    )}>
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-stone-100">
        <div className={cn(
          'w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0',
          totalProblems > 0 ? 'bg-red-50' : 'bg-green-50',
        )}>
          <Car className={cn('w-5 h-5', totalProblems > 0 ? 'text-red-500' : 'text-green-600')} />
        </div>

        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-ink-900 text-sm leading-tight">Verkehrslage</h3>
          {enabled && roads.length > 0 && (
            <p className="text-[10px] text-ink-400 truncate">
              {roads.join(' · ')}
              {ageMin !== null && ` · vor ${ageMin} Min.`}
            </p>
          )}
        </div>

        <div className="flex items-center gap-1.5">
          {enabled && (
            <>
              <button
                type="button"
                onClick={() => setEditMode(e => !e)}
                className={cn('p-1.5 rounded-lg transition-colors', editMode ? 'bg-primary-100 text-primary-600' : 'text-ink-400 hover:bg-stone-100')}
                title="Autobahnen bearbeiten"
              >
                <Settings2 className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={handleRefresh}
                disabled={loading || refreshing}
                className="p-1.5 rounded-lg text-ink-400 hover:bg-stone-100 transition-colors disabled:opacity-40"
                title="Aktualisieren"
              >
                <RefreshCw className={cn('w-4 h-4', (loading || refreshing) && 'animate-spin')} />
              </button>
            </>
          )}

          {/* Pendler-Modus Toggle */}
          <button
            type="button"
            onClick={handleToggle}
            className={cn(
              'relative inline-flex h-5 w-9 items-center rounded-full border-2 transition-colors',
              enabled ? 'bg-primary-500 border-primary-500' : 'bg-stone-200 border-stone-200',
            )}
            title={enabled ? 'Pendler-Modus deaktivieren' : 'Pendler-Modus aktivieren'}
          >
            <span className={cn(
              'inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform',
              enabled ? 'translate-x-3.5' : 'translate-x-0.5',
            )} />
          </button>
        </div>
      </div>

      {/* ── Body ───────────────────────────────────────────────────────── */}
      {!enabled ? (
        <div className="px-4 py-5 text-center">
          <p className="text-sm text-ink-500">Aktiviere den <span className="font-semibold text-ink-700">Pendler-Modus</span> um Staus, Baustellen und Sperrungen auf deinen Autobahnen zu sehen.</p>
        </div>
      ) : (
        <div className="px-4 py-3 space-y-3">

          {/* Autobahn-Chips + Edit Mode */}
          {editMode && (
            <div className="space-y-2 pb-2 border-b border-stone-100">
              <div className="flex flex-wrap gap-1.5">
                {roads.map(r => (
                  <span key={r} className="inline-flex items-center gap-1 bg-primary-50 text-primary-700 text-xs font-bold px-2.5 py-1 rounded-full">
                    {r}
                    <button type="button" onClick={() => handleRemoveRoad(r)} className="hover:text-red-500 transition-colors">
                      <X className="w-3 h-3" />
                    </button>
                  </span>
                ))}
              </div>
              <RoadSelector selected={roads} onAdd={handleAddRoad} onRemove={handleRemoveRoad} />
            </div>
          )}

          {/* Stats row */}
          {!loading && enabled && roads.length > 0 && (
            <div className="grid grid-cols-4 gap-1.5 text-center">
              {[
                { count: closureCount,  label: 'Sperrungen', color: 'text-rose-600',   bg: 'bg-rose-50'   },
                { count: jamCount,      label: 'Staus',      color: 'text-red-600',    bg: 'bg-red-50'    },
                { count: hazardCount,   label: 'Gefahren',   color: 'text-orange-500', bg: 'bg-orange-50' },
                { count: roadworkCount, label: 'Baustellen', color: 'text-amber-600',  bg: 'bg-amber-50'  },
              ].map(s => (
                <div key={s.label} className={cn('rounded-xl py-1.5', s.bg)}>
                  <p className={cn('display-numeral text-sm font-bold tabular-nums', s.color)}>{s.count}</p>
                  <p className="text-[9px] text-ink-500 leading-tight">{s.label}</p>
                </div>
              ))}
            </div>
          )}

          {/* Content */}
          {loading && <Skeleton />}

          {!loading && isClear && (
            <div className="flex items-center gap-2 bg-green-50 border border-green-200 rounded-xl px-3 py-3">
              <span className="text-lg">🟢</span>
              <div>
                <p className="text-sm font-semibold text-green-800">Freie Fahrt!</p>
                <p className="text-xs text-green-600">Keine Meldungen auf {roads.join(', ')}</p>
              </div>
            </div>
          )}

          {!loading && !isClear && (
            <div className="space-y-1.5 max-h-72 overflow-y-auto pr-0.5">
              {items.map(item => (
                <TrafficItemRow key={item.id} item={item} />
              ))}
            </div>
          )}

          {roads.length === 0 && !loading && (
            <p className="text-xs text-ink-400 text-center py-2">
              Keine Autobahnen ausgewählt. Tippe auf <Settings2 className="w-3 h-3 inline" /> zum Hinzufügen.
            </p>
          )}
        </div>
      )}
    </div>
  )
}
