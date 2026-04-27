'use client'

// ─────────────────────────────────────────────────────────────────────────────
// WeatherAlertBanner – Offizielle DWD-Wetterwarnungen via Bright Sky API
//
// Anders als der NinaWarningBanner (Bevölkerungsschutz) zeigt diese Komponente
// wetter-spezifische Warnungen mit Gültigkeitszeitraum und konkreten
// Handlungsanweisungen, gewichtet nach Wetter-Event-Typ.
//
// Verwendung:
//   <WeatherAlertBanner lat={profile.latitude} lng={profile.longitude} />
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useEffect, useCallback, useMemo } from 'react'
import {
  AlertTriangle, X, ChevronDown, ChevronUp,
  Shield, Clock, CloudRain, Wind,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { fetchWeatherAlerts, type WeatherAlert, type AlertSeverity } from '@/lib/api/brightsky'

// ── Lookup-Tables ──────────────────────────────────────────────────────────

const SEVERITY_BG: Record<AlertSeverity, string> = {
  extreme:  'bg-red-600 text-white',
  severe:   'bg-orange-500 text-white',
  moderate: 'bg-yellow-400 text-black',
  minor:    'bg-blue-100 text-blue-800',
}

const SEVERITY_RING: Record<AlertSeverity, string> = {
  extreme:  'ring-2 ring-red-400',
  severe:   '',
  moderate: '',
  minor:    '',
}

const SEVERITY_BADGE: Record<AlertSeverity, string> = {
  extreme:  'bg-white/20 text-white',
  severe:   'bg-white/20 text-white',
  moderate: 'bg-black/10 text-black',
  minor:    'bg-blue-200 text-blue-900',
}

const SEVERITY_LABEL: Record<AlertSeverity, string> = {
  extreme:  'EXTREM',
  severe:   'SCHWER',
  moderate: 'MITTEL',
  minor:    'GERING',
}

/**
 * Wetter-spezifische Emoji-Icons – matchen das Event-Wording vom DWD.
 * Wird per Substring-Match auf event/headline gemappt.
 */
const WEATHER_EVENT_ICONS: Array<{ pattern: RegExp; icon: string; label: string }> = [
  { pattern: /sturm|orkan|böen|wind/i,        icon: '🌪️', label: 'Sturm'    },
  { pattern: /gewitter|blitz/i,               icon: '⛈️', label: 'Gewitter' },
  { pattern: /hitze|extrem warm|tropennacht/i, icon: '🔥', label: 'Hitze'    },
  { pattern: /frost|extreme kälte/i,          icon: '❄️', label: 'Frost'    },
  { pattern: /glätte|glatteis/i,              icon: '🧊', label: 'Glätte'   },
  { pattern: /nebel/i,                        icon: '🌫️', label: 'Nebel'    },
  { pattern: /schnee|schneefall|verwehung/i,  icon: '🌨️', label: 'Schnee'   },
  { pattern: /regen|niederschlag|starkregen/i, icon: '🌧️', label: 'Regen'   },
  { pattern: /tau|hagel/i,                    icon: '🌨️', label: 'Hagel'    },
  { pattern: /uv/i,                           icon: '☀️', label: 'UV'       },
]

function pickWeatherIcon(alert: WeatherAlert): { icon: string; label: string } {
  const haystack = `${alert.event} ${alert.headline}`
  for (const entry of WEATHER_EVENT_ICONS) {
    if (entry.pattern.test(haystack)) return { icon: entry.icon, label: entry.label }
  }
  return { icon: '⚠️', label: 'Wetter' }
}

function formatTimeRange(onset: string, expires: string): string | null {
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

// ── Component ──────────────────────────────────────────────────────────────

export interface WeatherAlertBannerProps {
  /** Breitengrad – wenn nicht gesetzt, wird Geolocation versucht */
  lat?: number
  /** Längengrad – wenn nicht gesetzt, wird Geolocation versucht */
  lng?: number
  /** Maximale Anzahl gleichzeitig angezeigter Warnungen */
  maxAlerts?: number
  /** Optionaler className für Wrapper */
  className?: string
}

export default function WeatherAlertBanner({
  lat: latProp,
  lng: lngProp,
  maxAlerts = 3,
  className,
}: WeatherAlertBannerProps) {
  const [alerts, setAlerts] = useState<WeatherAlert[]>([])
  const [loading, setLoading] = useState(true)
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(
    latProp != null && lngProp != null ? { lat: latProp, lng: lngProp } : null,
  )
  const [dismissed, setDismissed] = useState<Set<string>>(new Set())
  const [expandedId, setExpandedId] = useState<string | null>(null)

  // Falls keine Props da sind: Geolocation versuchen (still – kein Prompt-Banner)
  useEffect(() => {
    if (coords) return
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setLoading(false)
      return
    }
    navigator.geolocation.getCurrentPosition(
      pos => setCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setLoading(false),
      { timeout: 8_000, maximumAge: 5 * 60 * 1000 },
    )
  }, [coords])

  // Alerts holen sobald Koordinaten verfügbar
  const loadAlerts = useCallback(async () => {
    if (!coords) return
    const data = await fetchWeatherAlerts(coords.lat, coords.lng)
    setAlerts(data)
    setLoading(false)
  }, [coords])

  useEffect(() => {
    if (!coords) return
    loadAlerts()
    const interval = setInterval(loadAlerts, 15 * 60 * 1000)  // 15 min refresh
    return () => clearInterval(interval)
  }, [coords, loadAlerts])

  const dismiss = (id: string) => {
    setDismissed(prev => new Set(prev).add(id))
    if (expandedId === id) setExpandedId(null)
  }

  const toggleExpand = (id: string) => setExpandedId(prev => (prev === id ? null : id))

  const visible = useMemo(
    () => alerts.filter(a => !dismissed.has(a.id)).slice(0, maxAlerts),
    [alerts, dismissed, maxAlerts],
  )

  if (loading || visible.length === 0) return null

  return (
    <div className={cn('space-y-1.5', className)} role="region" aria-label="Wetterwarnungen">
      {visible.map(alert => {
        const isExpanded = expandedId === alert.id
        const isExtreme  = alert.severity === 'extreme'
        const { icon, label: weatherLabel } = pickWeatherIcon(alert)
        const timeRange = formatTimeRange(alert.onset, alert.expires)

        return (
          <article
            key={alert.id}
            className={cn(
              'rounded-xl overflow-hidden shadow-sm transition-shadow',
              SEVERITY_BG[alert.severity],
              SEVERITY_RING[alert.severity],
              isExtreme && 'shadow-red-200/60 dark:shadow-red-900/30',
            )}
            aria-label={`Wetterwarnung: ${alert.headline}`}
          >
            {/* ── Compact row ───────────────────────────────────────── */}
            <div className="flex items-center gap-2 px-4 py-2.5">
              <span className="text-base flex-shrink-0" aria-hidden="true">{icon}</span>

              <span
                className={cn(
                  'text-xs font-bold px-1.5 py-0.5 rounded uppercase tracking-wide flex-shrink-0',
                  SEVERITY_BADGE[alert.severity],
                )}
              >
                {SEVERITY_LABEL[alert.severity]}
              </span>

              <button
                onClick={() => toggleExpand(alert.id)}
                className="flex-1 flex items-center gap-2 text-left min-w-0"
                aria-expanded={isExpanded}
                aria-controls={`weather-alert-${alert.id}`}
              >
                <span className="text-sm font-medium truncate">
                  {alert.headline || alert.event}
                </span>
                {timeRange && (
                  <span className="hidden sm:inline-flex items-center gap-1 text-xs opacity-75 flex-shrink-0">
                    <Clock className="w-3 h-3" aria-hidden="true" />
                    {timeRange}
                  </span>
                )}
                <span className="flex-shrink-0 ml-auto opacity-75">
                  {isExpanded
                    ? <ChevronUp className="w-3.5 h-3.5" aria-hidden="true" />
                    : <ChevronDown className="w-3.5 h-3.5" aria-hidden="true" />}
                </span>
              </button>

              <button
                onClick={() => dismiss(alert.id)}
                aria-label="Wetterwarnung schließen"
                className="p-1 rounded-lg opacity-70 hover:opacity-100 transition-opacity flex-shrink-0 min-w-[32px] min-h-[32px] flex items-center justify-center"
              >
                <X className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>

            {/* ── Mobile: Time range as separate line ───────────────── */}
            {timeRange && (
              <div className="sm:hidden px-4 pb-2 -mt-1 flex items-center gap-1.5 text-[11px] opacity-80">
                <Clock className="w-3 h-3" aria-hidden="true" />
                {timeRange}
              </div>
            )}

            {/* ── Expanded details ──────────────────────────────────── */}
            {isExpanded && (
              <div
                id={`weather-alert-${alert.id}`}
                className="px-4 pb-4 pt-1 border-t border-white/20 space-y-3"
              >
                <div className="flex items-center gap-2 text-[11px] uppercase tracking-wider opacity-75 mt-2">
                  <span className="inline-flex items-center gap-1">
                    <CloudRain className="w-3 h-3" aria-hidden="true" />
                    {weatherLabel}
                  </span>
                  <span aria-hidden="true">·</span>
                  <span>Quelle: DWD</span>
                </div>

                {alert.description && (
                  <p className="text-sm opacity-95 leading-relaxed">{alert.description}</p>
                )}

                {alert.instruction && (
                  <div className="flex items-start gap-2 mt-2 bg-white/10 rounded-lg p-3">
                    <Shield className="w-4 h-4 flex-shrink-0 mt-0.5 opacity-90" aria-hidden="true" />
                    <div>
                      <p className="text-[11px] uppercase tracking-wider opacity-80 mb-1">
                        Was du tun solltest
                      </p>
                      <p className="text-sm font-medium leading-relaxed">{alert.instruction}</p>
                    </div>
                  </div>
                )}

                {timeRange && (
                  <p className="text-[11px] opacity-75 inline-flex items-center gap-1.5 mt-1">
                    <Wind className="w-3 h-3" aria-hidden="true" />
                    {timeRange}
                  </p>
                )}
              </div>
            )}
          </article>
        )
      })}
    </div>
  )
}

// ── Re-export für externe Nutzung (z. B. in NinaWarningBanner) ─────────────

export { fetchWeatherAlerts } from '@/lib/api/brightsky'
export type { WeatherAlert, AlertSeverity } from '@/lib/api/brightsky'
