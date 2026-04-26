'use client'

import { useEffect, useState } from 'react'
import { AlertTriangle, X, ExternalLink } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { FoodWarning } from '@/lib/api/foodwarnings'

const FRESH_WINDOW_MS = 48 * 60 * 60 * 1000 // 48h in ms
const DISMISS_STORAGE_KEY = 'mensaena_foodwarnings_dismissed'

/**
 * Robust date parser: handles ISO 8601, Unix timestamps (s and ms),
 * and German date format (TT.MM.JJJJ or TT.MM.JJJJ HH:MM).
 * Returns NaN if the date is genuinely unparseable.
 */
function parseDateRobust(value: string): number {
  if (!value) return NaN

  // 1. ISO 8601 / RFC 2822 / most standard formats
  const standard = Date.parse(value)
  if (!isNaN(standard)) return standard

  // 2. Unix timestamp as string (seconds or milliseconds)
  const asNum = Number(value)
  if (!isNaN(asNum) && asNum > 0) {
    return asNum > 1e12 ? asNum : asNum * 1000
  }

  // 3. German date format: TT.MM.JJJJ or TT.MM.JJJJ HH:MM[:SS]
  const germanMatch = value.match(
    /^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[T\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?/,
  )
  if (germanMatch) {
    const [, day, month, year, hour = '0', minute = '0', second = '0'] = germanMatch
    const ts = Date.UTC(
      parseInt(year, 10),
      parseInt(month, 10) - 1,
      parseInt(day, 10),
      parseInt(hour, 10),
      parseInt(minute, 10),
      parseInt(second, 10),
    )
    if (!isNaN(ts)) return ts
  }

  return NaN
}

function loadDismissed(): Set<string> {
  if (typeof window === 'undefined') return new Set()
  try {
    const raw = window.localStorage.getItem(DISMISS_STORAGE_KEY)
    if (!raw) return new Set()
    const parsed = JSON.parse(raw) as string[]
    return new Set(Array.isArray(parsed) ? parsed : [])
  } catch {
    return new Set()
  }
}

function persistDismissed(ids: Set<string>) {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(DISMISS_STORAGE_KEY, JSON.stringify(Array.from(ids)))
  } catch {
    // ignore
  }
}

function formatRelative(dateStr: string): string {
  const ts = parseDateRobust(dateStr)
  if (isNaN(ts)) return ''
  const diffH = Math.round((Date.now() - ts) / (60 * 60 * 1000))
  if (diffH < 1) return 'gerade eben'
  if (diffH < 24) return `vor ${diffH} h`
  const diffD = Math.round(diffH / 24)
  return `vor ${diffD} Tag${diffD === 1 ? '' : 'en'}`
}

export default function FoodWarningBanner() {
  const [warning, setWarning] = useState<FoodWarning | null>(null)
  const [loading, setLoading] = useState(true)
  const [dismissed, setDismissed] = useState<Set<string>>(() => new Set())

  useEffect(() => {
    setDismissed(loadDismissed())
  }, [])

  useEffect(() => {
    let cancelled = false
    async function load() {
      try {
        const res = await fetch('/api/foodwarnings?limit=10')
        if (!res.ok) return
        const data = await res.json()
        const list = Array.isArray(data?.warnings) ? (data.warnings as FoodWarning[]) : []
        const fresh = list.find(w => {
          const ts = parseDateRobust(w.publishedDate)
          // Ungültiges Datum: lieber anzeigen als schweigen
          if (isNaN(ts)) return true
          return Date.now() - ts <= FRESH_WINDOW_MS
        })
        if (!cancelled) setWarning(fresh ?? null)
      } catch {
        // silent
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading || !warning) return null
  if (dismissed.has(warning.id)) return null

  const handleDismiss = () => {
    const next = new Set(dismissed)
    next.add(warning.id)
    setDismissed(next)
    persistDismissed(next)
  }

  const isRecall = warning.severity === 'high'
  const productLabel = warning.productName || warning.title

  return (
    <div
      role="alert"
      aria-live="polite"
      className={cn(
        'rounded-2xl border shadow-sm overflow-hidden mb-3',
        isRecall
          ? 'border-orange-300 bg-gradient-to-r from-orange-50 to-amber-50 dark:from-orange-950/40 dark:to-amber-950/40 dark:border-orange-700/60'
          : 'border-amber-200 bg-amber-50 dark:bg-amber-950/40 dark:border-amber-700/60',
      )}
    >
      <div className="flex items-start gap-3 px-4 py-3">
        <div
          className={cn(
            'flex-shrink-0 mt-0.5 rounded-lg p-2',
            isRecall
              ? 'bg-orange-100 text-orange-700 dark:bg-orange-900/60 dark:text-orange-200'
              : 'bg-amber-100 text-amber-700 dark:bg-amber-900/60 dark:text-amber-200',
          )}
        >
          <AlertTriangle className="w-4 h-4" aria-hidden="true" />
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span
              className={cn(
                'text-[10px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wide',
                isRecall
                  ? 'bg-orange-600 text-white'
                  : 'bg-amber-500 text-white',
              )}
            >
              {isRecall ? 'Produktrückruf' : 'Warnung'}
            </span>
            <span className="text-[11px] text-stone-500 dark:text-stone-400">
              {formatRelative(warning.publishedDate)}
            </span>
          </div>

          <p className="mt-1 text-sm font-semibold text-stone-900 dark:text-stone-50 line-clamp-2">
            {productLabel}
          </p>

          {warning.manufacturer && warning.manufacturer !== 'Unbekannt' && (
            <p className="text-xs text-stone-600 dark:text-stone-300 truncate">
              {warning.manufacturer}
            </p>
          )}

          <div className="mt-2 flex items-center gap-3 text-xs">
            <a
              href="/dashboard/warnungen"
              className="font-medium text-orange-700 hover:text-orange-800 dark:text-orange-300 dark:hover:text-orange-200 transition-colors"
            >
              Mehr Warnungen
            </a>
            {warning.link && (
              <a
                href={warning.link}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 font-medium text-stone-600 hover:text-stone-800 dark:text-stone-300 dark:hover:text-stone-100 transition-colors"
              >
                Details
                <ExternalLink className="w-3 h-3" aria-hidden="true" />
              </a>
            )}
          </div>
        </div>

        <button
          type="button"
          onClick={handleDismiss}
          aria-label="Warnung schließen"
          className="flex-shrink-0 p-1.5 rounded-lg text-stone-500 hover:bg-black/5 dark:text-stone-400 dark:hover:bg-white/10 transition-colors min-w-[32px] min-h-[32px] flex items-center justify-center"
        >
          <X className="w-4 h-4" aria-hidden="true" />
        </button>
      </div>
    </div>
  )
}
