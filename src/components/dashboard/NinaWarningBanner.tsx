'use client'

import { useState, useEffect, useCallback } from 'react'
import { AlertTriangle, X, ChevronDown, ChevronUp, Shield, Clock, CloudRain } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { NinaWarning } from '@/lib/nina-api'
import {
  fetchWeatherAlerts,
  mergeWeatherWarnings,
  type WeatherAlert,
  type UnifiedWarning,
} from '@/lib/api/brightsky'

const SEVERITY_STYLES: Record<NinaWarning['severity'], string> = {
  Extreme:  'bg-red-600 text-white',
  Severe:   'bg-orange-500 text-white',
  Moderate: 'bg-yellow-400 text-black',
  Minor:    'bg-blue-100 text-blue-800',
}

const BADGE_STYLES: Record<NinaWarning['severity'], string> = {
  Extreme:  'bg-white/20 text-white',
  Severe:   'bg-white/20 text-white',
  Moderate: 'bg-black/10 text-black',
  Minor:    'bg-blue-200 text-blue-900',
}

const SEVERITY_LABELS: Record<NinaWarning['severity'], string> = {
  Extreme:  'EXTREM',
  Severe:   'SCHWER',
  Moderate: 'MITTEL',
  Minor:    'GERING',
}

// Wetter-Icons für DWD-Warnungen (NINA bekommt das generische AlertTriangle)
const WEATHER_EVENT_ICONS: Array<{ pattern: RegExp; icon: string }> = [
  { pattern: /sturm|orkan|böen|wind/i,         icon: '🌪️' },
  { pattern: /gewitter|blitz/i,                icon: '⛈️' },
  { pattern: /hitze|extrem warm|tropennacht/i, icon: '🔥' },
  { pattern: /frost|extreme kälte/i,           icon: '❄️' },
  { pattern: /glätte|glatteis/i,               icon: '🧊' },
  { pattern: /nebel/i,                         icon: '🌫️' },
  { pattern: /schnee|verwehung/i,              icon: '🌨️' },
  { pattern: /regen|niederschlag|starkregen/i, icon: '🌧️' },
  { pattern: /tau|hagel/i,                     icon: '🌨️' },
]

function pickWeatherIcon(title: string, event?: string): string | null {
  const haystack = `${event ?? ''} ${title}`
  for (const entry of WEATHER_EVENT_ICONS) {
    if (entry.pattern.test(haystack)) return entry.icon
  }
  return null
}

function formatTimeRange(onset?: string, expires?: string): string | null {
  if (!onset && !expires) return null
  const fmt = (iso: string) => {
    const d = new Date(iso)
    if (isNaN(d.getTime())) return ''
    const now = new Date()
    const sameDay = d.toDateString() === now.toDateString()
    const time = d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
    if (sameDay) return time
    const date = d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' })
    return `${date} ${time}`
  }
  const from = onset   ? fmt(onset)   : ''
  const to   = expires ? fmt(expires) : ''
  if (from && to) return `Von ${from} bis ${to} Uhr`
  if (from)       return `Ab ${from} Uhr`
  if (to)         return `Bis ${to} Uhr`
  return null
}

// ── Cache: 15 min TTL, shared across mounts ────────────────────────────────

const CACHE_TTL = 15 * 60 * 1000
const NINA_CACHE_KEY = 'mensaena_nina_warnings'

interface NinaCacheEntry { data: NinaWarning[]; timestamp: number }
let ninaModuleCache: NinaCacheEntry | null = null
let ninaInflight: Promise<NinaWarning[]> | null = null

function readNinaCache(): NinaWarning[] | null {
  if (ninaModuleCache && Date.now() - ninaModuleCache.timestamp < CACHE_TTL) {
    return ninaModuleCache.data
  }
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(NINA_CACHE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as NinaCacheEntry
    if (Date.now() - parsed.timestamp < CACHE_TTL) {
      ninaModuleCache = parsed
      return parsed.data
    }
  } catch {}
  return null
}

function writeNinaCache(data: NinaWarning[]) {
  const entry: NinaCacheEntry = { data, timestamp: Date.now() }
  ninaModuleCache = entry
  try { localStorage.setItem(NINA_CACHE_KEY, JSON.stringify(entry)) } catch {}
}

async function loadNinaWarnings(): Promise<NinaWarning[]> {
  if (ninaInflight) return ninaInflight
  ninaInflight = (async () => {
    try {
      const res = await fetch('/api/nina/warnings')
      if (!res.ok) return []
      const data = await res.json()
      const warnings = Array.isArray(data.warnings) ? data.warnings as NinaWarning[] : []
      writeNinaCache(warnings)
      return warnings
    } catch {
      return []
    } finally {
      ninaInflight = null
    }
  })()
  return ninaInflight
}

// ── Component ──────────────────────────────────────────────────────────────

export interface NinaWarningBannerProps {
  /**
   * Optional: Breitengrad zum zusätzlichen Laden offizieller DWD-Wetterwarnungen.
   * Wenn lat/lng vorhanden, werden NINA + DWD parallel geladen und gemergt.
   */
  lat?: number
  /** Optional: Längengrad für DWD-Wetterwarnungen */
  lng?: number
}

export default function NinaWarningBanner({ lat, lng }: NinaWarningBannerProps = {}) {
  const cachedNina = typeof window !== 'undefined' ? readNinaCache() : null
  const [warnings, setWarnings] = useState<UnifiedWarning[]>(
    cachedNina ? cachedNina.map(w => ({ ...w, source: 'nina' as const })) : [],
  )
  const [loading, setLoading]     = useState(cachedNina === null)
  const [dismissed, setDismissed] = useState<Set<string>>(new Set())
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const loadAll = useCallback(async () => {
    const ninaPromise = loadNinaWarnings()

    const dwdPromise: Promise<WeatherAlert[]> =
      lat != null && lng != null
        ? fetchWeatherAlerts(lat, lng).catch(() => [])
        : Promise.resolve([])

    const [nina, dwd] = await Promise.all([ninaPromise, dwdPromise])
    setWarnings(mergeWeatherWarnings(nina, dwd))
    setLoading(false)
  }, [lat, lng])

  useEffect(() => {
    // Skip fetch if cached data is fresh AND we don't need DWD
    if (
      ninaModuleCache &&
      Date.now() - ninaModuleCache.timestamp < CACHE_TTL &&
      lat == null &&
      lng == null
    ) {
      setLoading(false)
      return
    }
    loadAll()
    const interval = setInterval(loadAll, CACHE_TTL)
    return () => clearInterval(interval)
  }, [loadAll, lat, lng])

  const dismiss = (id: string) => {
    setDismissed(prev => new Set(prev).add(id))
    if (expandedId === id) setExpandedId(null)
  }

  const toggleExpand = (id: string) => {
    setExpandedId(prev => (prev === id ? null : id))
  }

  const visible = warnings.filter(w => !dismissed.has(w.id))

  if (loading || visible.length === 0) return null

  return (
    <div className="space-y-1 mb-4" role="region" aria-label="Aktuelle Warnungen">
      {visible.map(warning => {
        const isExpanded = expandedId === warning.id
        const isExtreme  = warning.severity === 'Extreme'
        const isDwd      = warning.source === 'dwd'
        const weatherIcon = isDwd ? pickWeatherIcon(warning.title, warning.event) : null
        const timeRange   = isDwd ? formatTimeRange(warning.onset, warning.expires) : null

        return (
          <article
            key={warning.id}
            className={cn(
              'rounded-xl overflow-hidden shadow-sm',
              SEVERITY_STYLES[warning.severity],
              isExtreme && 'ring-2 ring-red-400',
            )}
            aria-label={`${isDwd ? 'Wetterwarnung' : 'Warnung'}: ${warning.title}`}
          >
            {/* Compact row */}
            <div className="flex items-center gap-2 px-4 py-2.5">
              {weatherIcon ? (
                <span className="text-base flex-shrink-0" aria-hidden="true">{weatherIcon}</span>
              ) : (
                <AlertTriangle
                  className={cn('w-4 h-4 flex-shrink-0', isExtreme && 'animate-pulse')}
                  aria-hidden="true"
                />
              )}

              <span
                className={cn(
                  'text-[10px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wide flex-shrink-0',
                  BADGE_STYLES[warning.severity],
                )}
              >
                {SEVERITY_LABELS[warning.severity]}
              </span>

              <button
                onClick={() => toggleExpand(warning.id)}
                className="flex-1 flex items-center gap-2 text-left min-w-0"
                aria-expanded={isExpanded}
                aria-controls={`warning-${warning.id}`}
              >
                <span className="text-sm font-medium truncate">{warning.title}</span>
                {timeRange && (
                  <span className="hidden sm:inline-flex items-center gap-1 text-xs opacity-75 flex-shrink-0">
                    <Clock className="w-3 h-3" aria-hidden="true" />
                    {timeRange}
                  </span>
                )}
                {!timeRange && warning.area && (
                  <span className="hidden sm:inline text-xs opacity-75 truncate flex-shrink-0">
                    · {warning.area}
                  </span>
                )}
                <span className="flex-shrink-0 ml-auto opacity-75">
                  {isExpanded
                    ? <ChevronUp className="w-3.5 h-3.5" aria-hidden="true" />
                    : <ChevronDown className="w-3.5 h-3.5" aria-hidden="true" />}
                </span>
              </button>

              <button
                onClick={() => dismiss(warning.id)}
                aria-label="Warnung schließen"
                className="p-1 rounded-lg opacity-70 hover:opacity-100 transition-opacity flex-shrink-0 min-w-[32px] min-h-[32px] flex items-center justify-center"
              >
                <X className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>

            {/* Mobile: Time range as separate line for DWD */}
            {timeRange && (
              <div className="sm:hidden px-4 pb-2 -mt-1 flex items-center gap-1.5 text-[11px] opacity-80">
                <Clock className="w-3 h-3" aria-hidden="true" />
                {timeRange}
              </div>
            )}

            {/* Expanded details */}
            {isExpanded && (
              <div
                id={`warning-${warning.id}`}
                className="px-4 pb-4 pt-1 border-t border-white/20 space-y-2"
              >
                <div className="flex items-center gap-2 text-[11px] uppercase tracking-wider opacity-75 mt-2">
                  {isDwd ? (
                    <>
                      <CloudRain className="w-3 h-3" aria-hidden="true" />
                      <span>Quelle: DWD</span>
                    </>
                  ) : (
                    <>
                      <Shield className="w-3 h-3" aria-hidden="true" />
                      <span>Quelle: NINA · Bevölkerungsschutz</span>
                    </>
                  )}
                </div>

                {warning.description && (
                  <p className="text-sm opacity-90 leading-relaxed">{warning.description}</p>
                )}
                {warning.instruction && (
                  <div className="flex items-start gap-2 mt-2 bg-white/10 rounded-lg p-3">
                    <Shield className="w-4 h-4 flex-shrink-0 mt-0.5 opacity-90" aria-hidden="true" />
                    <div>
                      <p className="text-[11px] uppercase tracking-wider opacity-80 mb-1">
                        Was du tun solltest
                      </p>
                      <p className="text-sm font-medium leading-relaxed">{warning.instruction}</p>
                    </div>
                  </div>
                )}
                {warning.area && (
                  <p className="text-xs opacity-60">Betroffenes Gebiet: {warning.area}</p>
                )}
              </div>
            )}
          </article>
        )
      })}
    </div>
  )
}
