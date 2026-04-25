'use client'

import { useEffect, useMemo, useState } from 'react'
import Image from 'next/image'
import {
  AlertTriangle,
  ExternalLink,
  ImageOff,
  MapPin,
  ShieldAlert,
  RefreshCw,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { isRelevantForState, type FoodWarning } from '@/lib/api/foodwarnings'

interface FoodWarningFeedProps {
  /** Anzahl initial sichtbarer Warnungen. Default 5. */
  initialLimit?: number
  /** Schritt für "Alle anzeigen" / "Mehr laden". Default 10. */
  loadMoreStep?: number
  /** Optionale Vorgabe des User-Bundeslands. Wenn nicht gesetzt, wird das Profil geladen. */
  userState?: string
}

interface CardProps {
  warning: FoodWarning
}

function formatDate(iso: string): string {
  const ts = Date.parse(iso)
  if (Number.isNaN(ts)) return ''
  return new Date(ts).toLocaleDateString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

function FoodWarningCardSkeleton() {
  return (
    <div className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 overflow-hidden animate-pulse">
      <div className="aspect-[16/9] bg-stone-100 dark:bg-stone-800" />
      <div className="p-4 space-y-2">
        <div className="h-4 w-3/4 bg-stone-200 dark:bg-stone-700 rounded" />
        <div className="h-3 w-1/2 bg-stone-200 dark:bg-stone-700 rounded" />
        <div className="h-3 w-full bg-stone-200 dark:bg-stone-700 rounded" />
        <div className="h-3 w-5/6 bg-stone-200 dark:bg-stone-700 rounded" />
      </div>
    </div>
  )
}

function FoodWarningCard({ warning }: CardProps) {
  const [imgError, setImgError] = useState(false)
  const isRecall = warning.severity === 'high'

  return (
    <article
      role="alert"
      aria-labelledby={`fw-title-${warning.id}`}
      className={cn(
        'rounded-2xl border-2 overflow-hidden bg-white dark:bg-stone-900 shadow-sm hover:shadow-md transition-shadow flex flex-col',
        isRecall
          ? 'border-red-300 dark:border-red-700/70'
          : 'border-orange-300 dark:border-orange-700/70',
      )}
    >
      <div className="relative aspect-[16/9] bg-stone-100 dark:bg-stone-800">
        {warning.imageUrl && !imgError ? (
          <Image
            src={warning.imageUrl}
            alt={warning.productName || warning.title}
            fill
            className="object-cover"
            sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
            onError={() => setImgError(true)}
            unoptimized
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-stone-300 dark:text-stone-600">
            <ImageOff className="w-12 h-12" aria-hidden="true" />
          </div>
        )}
        <span
          className={cn(
            'absolute top-3 left-3 inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-wide shadow',
            isRecall ? 'bg-red-600 text-white' : 'bg-orange-500 text-white',
          )}
        >
          {isRecall ? <ShieldAlert className="w-3 h-3" aria-hidden="true" /> : <AlertTriangle className="w-3 h-3" aria-hidden="true" />}
          {isRecall ? 'Rückruf' : 'Warnung'}
        </span>
      </div>

      <div className="p-4 flex flex-col gap-2 flex-1">
        <h3
          id={`fw-title-${warning.id}`}
          className="font-semibold text-stone-900 dark:text-stone-50 leading-snug line-clamp-2"
        >
          {warning.productName || warning.title}
        </h3>

        <div className="flex items-center gap-2 text-xs text-stone-500 dark:text-stone-400 flex-wrap">
          {warning.manufacturer && warning.manufacturer !== 'Unbekannt' && (
            <span className="font-medium text-stone-700 dark:text-stone-200">
              {warning.manufacturer}
            </span>
          )}
          <span aria-hidden="true">·</span>
          <time dateTime={warning.publishedDate}>{formatDate(warning.publishedDate)}</time>
        </div>

        {warning.description && (
          <p className="text-sm text-stone-600 dark:text-stone-300 leading-relaxed line-clamp-3">
            {warning.description}
          </p>
        )}

        {warning.affectedStates.length > 0 && (
          <div className="flex items-start gap-1.5 text-xs text-stone-500 dark:text-stone-400">
            <MapPin className="w-3.5 h-3.5 flex-shrink-0 mt-0.5" aria-hidden="true" />
            <span className="line-clamp-1">{warning.affectedStates.join(', ')}</span>
          </div>
        )}

        {warning.link && (
          <a
            href={warning.link}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-auto inline-flex items-center gap-1 self-start text-sm font-medium text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300 transition-colors"
          >
            Mehr erfahren
            <ExternalLink className="w-3.5 h-3.5" aria-hidden="true" />
          </a>
        )}
      </div>
    </article>
  )
}

export default function FoodWarningFeed({
  initialLimit = 5,
  loadMoreStep = 10,
  userState,
}: FoodWarningFeedProps) {
  const [warnings, setWarnings] = useState<FoodWarning[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [stateOnly, setStateOnly] = useState(false)
  const [visibleCount, setVisibleCount] = useState(initialLimit)
  const [resolvedState, setResolvedState] = useState<string>(userState ?? '')
  const [refreshing, setRefreshing] = useState(false)

  // ── Profilseitiges Bundesland nachladen, wenn Prop nicht gesetzt ──
  useEffect(() => {
    if (userState !== undefined) {
      setResolvedState(userState)
      return
    }
    let cancelled = false
    ;(async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) return
        const { data: profile } = await supabase
          .from('profiles')
          .select('location, state')
          .eq('id', user.id)
          .maybeSingle()
        if (cancelled || !profile) return
        // `state` falls vorhanden, sonst aus location heraus erkennen
        const raw =
          (profile as { state?: string | null; location?: string | null }).state ??
          (profile as { location?: string | null }).location ??
          ''
        if (raw) setResolvedState(String(raw))
      } catch {
        // silent
      }
    })()
    return () => { cancelled = true }
  }, [userState])

  const loadWarnings = async (force = false) => {
    if (force) setRefreshing(true)
    try {
      const res = await fetch(`/api/foodwarnings?limit=50${force ? `&t=${Date.now()}` : ''}`, {
        cache: force ? 'no-store' : 'default',
      })
      if (!res.ok) {
        setError('Warnungen konnten nicht geladen werden.')
        setWarnings([])
        return
      }
      const data = await res.json()
      const list = Array.isArray(data?.warnings) ? (data.warnings as FoodWarning[]) : []
      setWarnings(list)
      setError(null)
    } catch {
      setError('Warnungen konnten nicht geladen werden.')
      setWarnings([])
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }

  useEffect(() => {
    loadWarnings()
  }, [])

  const filtered = useMemo(() => {
    if (!stateOnly || !resolvedState) return warnings
    return warnings.filter(w => isRelevantForState(w, resolvedState))
  }, [warnings, stateOnly, resolvedState])

  const visible = filtered.slice(0, visibleCount)
  const hasMore = visible.length < filtered.length

  // ── Loading-State ──
  if (loading) {
    return (
      <section aria-busy="true" aria-label="Lebensmittelwarnungen werden geladen">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <FoodWarningCardSkeleton key={i} />
          ))}
        </div>
      </section>
    )
  }

  // ── Error / Empty ──
  if (error) {
    return (
      <div
        role="alert"
        className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 p-6 text-center"
      >
        <AlertTriangle className="w-8 h-8 mx-auto text-stone-400 dark:text-stone-500 mb-2" aria-hidden="true" />
        <p className="text-sm text-stone-600 dark:text-stone-300 mb-3">{error}</p>
        <button
          type="button"
          onClick={() => loadWarnings(true)}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary-600 hover:bg-primary-700 text-white text-sm font-medium transition-colors"
        >
          <RefreshCw className="w-4 h-4" aria-hidden="true" />
          Erneut versuchen
        </button>
      </div>
    )
  }

  if (warnings.length === 0) {
    return (
      <div className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 p-8 text-center">
        <ShieldAlert className="w-10 h-10 mx-auto text-emerald-500 mb-3" aria-hidden="true" />
        <h3 className="font-semibold text-stone-900 dark:text-stone-50 mb-1">
          Keine aktuellen Warnungen
        </h3>
        <p className="text-sm text-stone-600 dark:text-stone-300">
          In den letzten 30 Tagen gab es keine Lebensmittel- oder Produktwarnungen.
        </p>
      </div>
    )
  }

  return (
    <section aria-label="Aktuelle Lebensmittel- und Produktwarnungen">
      {/* Header / Toolbar */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
        <p className="text-sm text-stone-600 dark:text-stone-300">
          {filtered.length} {filtered.length === 1 ? 'Warnung' : 'Warnungen'}
          {stateOnly && resolvedState && (
            <span className="text-stone-400 dark:text-stone-500"> · gefiltert nach {resolvedState}</span>
          )}
        </p>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => loadWarnings(true)}
            disabled={refreshing}
            aria-label="Warnungen aktualisieren"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium text-stone-700 dark:text-stone-200 bg-white dark:bg-stone-800 border border-stone-200 dark:border-stone-700 hover:bg-stone-50 dark:hover:bg-stone-700 disabled:opacity-50 transition-colors"
          >
            <RefreshCw className={cn('w-3.5 h-3.5', refreshing && 'animate-spin')} aria-hidden="true" />
            Aktualisieren
          </button>

          {resolvedState && (
            <label className="inline-flex items-center gap-2 cursor-pointer select-none px-3 py-1.5 rounded-xl text-xs font-medium bg-white dark:bg-stone-800 border border-stone-200 dark:border-stone-700">
              <input
                type="checkbox"
                checked={stateOnly}
                onChange={e => {
                  setStateOnly(e.target.checked)
                  setVisibleCount(initialLimit)
                }}
                className="w-3.5 h-3.5 rounded border-stone-300 dark:border-stone-600 text-primary-600 focus:ring-primary-500"
              />
              <span className="text-stone-700 dark:text-stone-200">Nur mein Bundesland</span>
            </label>
          )}
        </div>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 p-6 text-center">
          <p className="text-sm text-stone-600 dark:text-stone-300">
            Keine Warnungen für dein Bundesland.
          </p>
          <button
            type="button"
            onClick={() => setStateOnly(false)}
            className="mt-3 text-sm font-medium text-primary-600 dark:text-primary-400 hover:underline"
          >
            Alle Warnungen anzeigen
          </button>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {visible.map(w => (
              <FoodWarningCard key={w.id} warning={w} />
            ))}
          </div>

          {hasMore && (
            <div className="mt-6 flex justify-center">
              <button
                type="button"
                onClick={() => setVisibleCount(c => c + loadMoreStep)}
                className="px-5 py-2.5 rounded-xl bg-primary-600 hover:bg-primary-700 text-white text-sm font-medium transition-colors shadow-sm"
              >
                {visibleCount >= initialLimit + loadMoreStep ? 'Mehr laden' : 'Alle anzeigen'}
              </button>
            </div>
          )}
        </>
      )}
    </section>
  )
}
