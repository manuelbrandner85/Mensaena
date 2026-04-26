'use client'

// ── UnifiedWarningBanner ──────────────────────────────────────────────────────
// Zeigt aggregierte Warnungen (NINA + MeteoAlarm) mit dem schwerwiegendsten
// Eintrag prominent oben. Weitere Warnungen aufklappbar. Dismiss persistiert
// in localStorage (pro Warnungs-ID, läuft bei `expires` aus).

import { useEffect, useMemo, useState } from 'react'
import {
  AlertTriangle, CloudLightning, Waves, Flame, ShieldAlert, Activity, X,
  ChevronDown, ChevronUp, ExternalLink, type LucideIcon,
} from 'lucide-react'
import { fetchAllWarnings, type UnifiedWarning } from '@/lib/api/unified-warnings'

const TYPE_ICON: Record<UnifiedWarning['type'], LucideIcon> = {
  weather: CloudLightning,
  flood: Waves,
  fire: Flame,
  health: Activity,
  civil: ShieldAlert,
  other: AlertTriangle,
}

const SEVERITY_STYLE: Record<
  UnifiedWarning['severity'],
  { bg: string; border: string; text: string; icon: string; label: string; pulse?: boolean }
> = {
  minor:    { bg: 'bg-yellow-50 dark:bg-yellow-950/40',  border: 'border-yellow-200 dark:border-yellow-800',  text: 'text-yellow-900 dark:text-yellow-100',   icon: 'text-yellow-600 dark:text-yellow-300',   label: 'Hinweis' },
  moderate: { bg: 'bg-orange-50 dark:bg-orange-950/40', border: 'border-orange-200 dark:border-orange-800', text: 'text-orange-900 dark:text-orange-100', icon: 'text-orange-600 dark:text-orange-300', label: 'Warnung' },
  severe:   { bg: 'bg-red-50 dark:bg-red-950/40',       border: 'border-red-200 dark:border-red-800',       text: 'text-red-900 dark:text-red-100',         icon: 'text-red-600 dark:text-red-300',         label: 'Schwere Warnung' },
  extreme:  { bg: 'bg-red-100 dark:bg-red-950/60',      border: 'border-red-400 dark:border-red-600',       text: 'text-red-900 dark:text-red-100',         icon: 'text-red-700 dark:text-red-300',         label: 'Extreme Gefahr', pulse: true },
}

const DISMISS_PREFIX = 'mensaena_warning_dismissed_'

function isDismissed(id: string): boolean {
  if (typeof window === 'undefined') return false
  try {
    const raw = window.localStorage.getItem(DISMISS_PREFIX + id)
    if (!raw) return false
    const expiresAt = parseInt(raw, 10)
    if (isFinite(expiresAt) && expiresAt > 0 && Date.now() > expiresAt) {
      window.localStorage.removeItem(DISMISS_PREFIX + id)
      return false
    }
    return true
  } catch {
    return false
  }
}

function markDismissed(id: string, expires: string) {
  if (typeof window === 'undefined') return
  try {
    const t = expires ? Date.parse(expires) : 0
    window.localStorage.setItem(DISMISS_PREFIX + id, String(isFinite(t) ? t : 0))
  } catch { /* ignore */ }
}

export interface UnifiedWarningBannerProps {
  lat: number
  lng: number
  countryCode: string
  /** Optionale PLZ — verbessert NINA-Genauigkeit via AGS */
  plz?: string
  /** Maximale Anzahl im Detail-Aufklapper (Default: 5) */
  maxDetails?: number
  className?: string
}

export function UnifiedWarningBanner({
  lat,
  lng,
  countryCode,
  plz,
  maxDetails = 5,
  className = '',
}: UnifiedWarningBannerProps) {
  const [warnings, setWarnings] = useState<UnifiedWarning[]>([])
  const [loaded, setLoaded] = useState(false)
  const [expanded, setExpanded] = useState(false)
  const [dismissedIds, setDismissedIds] = useState<Set<string>>(() => new Set())

  useEffect(() => {
    let cancelled = false
    fetchAllWarnings(lat, lng, countryCode, plz)
      .then(list => { if (!cancelled) setWarnings(list) })
      .catch(() => { if (!cancelled) setWarnings([]) })
      .finally(() => { if (!cancelled) setLoaded(true) })
    return () => { cancelled = true }
  }, [lat, lng, countryCode, plz])

  const visible = useMemo(
    () => warnings.filter(w => !dismissedIds.has(w.id) && !isDismissed(w.id)),
    [warnings, dismissedIds],
  )

  if (!loaded || visible.length === 0) return null

  const [primary, ...rest] = visible
  const style = SEVERITY_STYLE[primary.severity]
  const Icon = TYPE_ICON[primary.type]

  function handleDismiss(w: UnifiedWarning) {
    markDismissed(w.id, w.expires)
    setDismissedIds(prev => {
      const next = new Set(prev)
      next.add(w.id)
      return next
    })
  }

  return (
    <div
      role="alert"
      aria-live="polite"
      className={`flex flex-col gap-3 rounded-xl border ${style.border} ${style.bg} ${style.text} px-4 py-3 ${style.pulse ? 'animate-pulse' : ''} ${className}`}
    >
      <div className="flex items-start gap-3">
        <Icon aria-hidden className={`mt-0.5 h-5 w-5 flex-shrink-0 ${style.icon}`} />
        <div className="flex-1 min-w-0">
          <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide opacity-80">
            <span>{style.label}</span>
            <span className="opacity-60">· {primary.source.toUpperCase()}</span>
          </div>
          <h3 className="text-sm font-semibold leading-snug">{primary.title}</h3>
          {primary.area && (
            <p className="mt-0.5 text-xs opacity-80">Region: {primary.area}</p>
          )}
          {primary.description && (
            <p className="mt-1 line-clamp-3 text-xs leading-relaxed opacity-90">
              {primary.description}
            </p>
          )}
          {primary.instruction && (
            <p className="mt-1 text-xs font-medium opacity-90">
              Empfehlung: {primary.instruction}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={() => handleDismiss(primary)}
          aria-label="Warnung ausblenden"
          className="flex-shrink-0 rounded-md p-1 transition-colors hover:bg-black/10 dark:hover:bg-white/10"
        >
          <X aria-hidden className="h-4 w-4" />
        </button>
      </div>

      {rest.length > 0 && (
        <div>
          <button
            type="button"
            onClick={() => setExpanded(e => !e)}
            aria-expanded={expanded}
            className="flex w-full items-center justify-between rounded-md border border-current/20 px-3 py-1.5 text-xs font-medium transition-colors hover:bg-black/5 dark:hover:bg-white/5"
          >
            <span>{rest.length} weitere Warnung{rest.length === 1 ? '' : 'en'}</span>
            {expanded ? <ChevronUp aria-hidden className="h-3.5 w-3.5" /> : <ChevronDown aria-hidden className="h-3.5 w-3.5" />}
          </button>
          {expanded && (
            <ul className="mt-2 space-y-2">
              {rest.slice(0, maxDetails).map(w => {
                const ws = SEVERITY_STYLE[w.severity]
                const WIcon = TYPE_ICON[w.type]
                return (
                  <li
                    key={w.id}
                    className={`flex items-start gap-2 rounded-md border ${ws.border} bg-white/40 px-3 py-2 text-xs ${ws.text} dark:bg-black/20`}
                  >
                    <WIcon aria-hidden className={`mt-0.5 h-3.5 w-3.5 flex-shrink-0 ${ws.icon}`} />
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold">{w.title}</div>
                      {w.area && <div className="opacity-70">{w.area}</div>}
                    </div>
                    {w.url && (
                      <a
                        href={w.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        aria-label="Details öffnen"
                        className="rounded p-1 hover:bg-black/10 dark:hover:bg-white/10"
                      >
                        <ExternalLink aria-hidden className="h-3 w-3" />
                      </a>
                    )}
                    <button
                      type="button"
                      onClick={() => handleDismiss(w)}
                      aria-label="Diese Warnung ausblenden"
                      className="rounded p-1 hover:bg-black/10 dark:hover:bg-white/10"
                    >
                      <X aria-hidden className="h-3 w-3" />
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  )
}

export default UnifiedWarningBanner
