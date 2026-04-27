'use client'

import { useEffect, useState, useCallback } from 'react'
import { Library, Image as ImageIcon, ExternalLink, X, ChevronLeft, ChevronRight, FileText, Video, Music, Box } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { getCityFromCoords } from '@/lib/api/wikidata'
import {
  searchCulturalItems,
  searchHistoricalItems,
  isDdbConfigured,
  type CulturalItem,
  type CulturalItemType,
} from '@/lib/api/ddb'

// ── Type → Icon Map ───────────────────────────────────────────────────────────

const TYPE_ICONS: Record<CulturalItemType, React.ComponentType<{ className?: string }>> = {
  image:    ImageIcon,
  document: FileText,
  audio:    Music,
  video:    Video,
  object:   Box,
  unknown:  ImageIcon,
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function GallerySkeleton() {
  return (
    <div className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 p-4 shadow-soft animate-pulse">
      <div className="h-5 bg-stone-100 dark:bg-stone-800 rounded-lg w-2/3 mb-3" />
      <div className="flex gap-3 overflow-hidden">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="w-32 h-40 bg-stone-100 dark:bg-stone-800 rounded-xl flex-shrink-0" />
        ))}
      </div>
    </div>
  )
}

// ── Card ──────────────────────────────────────────────────────────────────────

function GalleryCard({
  item,
  onClick,
}: {
  item: CulturalItem
  onClick: () => void
}) {
  const Icon = TYPE_ICONS[item.type]
  return (
    <button
      onClick={onClick}
      className="group relative w-32 sm:w-36 flex-shrink-0 rounded-xl overflow-hidden bg-stone-100 dark:bg-stone-800 border border-stone-200 dark:border-stone-700 shadow-soft hover:shadow-card transition-all hover:scale-[1.02] active:scale-95 text-left"
      title={item.title}
    >
      <div className="aspect-[3/4] relative bg-gradient-to-br from-stone-200 to-stone-100 dark:from-stone-800 dark:to-stone-900">
        {item.thumbnailUrl ? (
          /* eslint-disable-next-line @next/next/no-img-element */
          <img
            src={item.thumbnailUrl}
            alt={item.title}
            className="w-full h-full object-cover"
            loading="lazy"
            onError={e => { (e.currentTarget.style.display = 'none') }}
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <Icon className="w-8 h-8 text-stone-400" />
          </div>
        )}
        {item.year && (
          <span className="absolute top-1.5 right-1.5 px-1.5 py-0.5 bg-black/60 text-white text-xs font-bold rounded backdrop-blur-sm tabular-nums">
            {item.year}
          </span>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/0 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
      </div>
      <div className="p-2 bg-white dark:bg-stone-900">
        <p className="text-xs font-semibold text-ink-900 dark:text-stone-100 line-clamp-2 leading-tight">
          {item.title}
        </p>
        {item.subtitle && (
          <p className="text-xs text-ink-500 dark:text-stone-400 line-clamp-1 mt-0.5">
            {item.subtitle}
          </p>
        )}
      </div>
    </button>
  )
}

// ── Detail Modal ──────────────────────────────────────────────────────────────

function DetailModal({
  item,
  onClose,
  onPrev,
  onNext,
  hasPrev,
  hasNext,
}: {
  item: CulturalItem
  onClose: () => void
  onPrev?: () => void
  onNext?: () => void
  hasPrev: boolean
  hasNext: boolean
}) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft' && hasPrev && onPrev)  onPrev()
      if (e.key === 'ArrowRight' && hasNext && onNext) onNext()
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose, onPrev, onNext, hasPrev, hasNext])

  return (
    <div
      className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label={item.title}
    >
      <div
        className="bg-white dark:bg-stone-900 rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-2xl animate-scale-in"
        onClick={e => e.stopPropagation()}
      >
        {/* Image */}
        <div className="relative bg-stone-900 flex items-center justify-center min-h-[300px] max-h-[60vh]">
          {item.thumbnailUrl ? (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img
              src={item.thumbnailUrl}
              alt={item.title}
              className="max-w-full max-h-[60vh] object-contain"
              onError={e => { (e.currentTarget.style.display = 'none') }}
            />
          ) : (
            <Library className="w-16 h-16 text-stone-500" />
          )}

          {/* Close button */}
          <button
            onClick={onClose}
            className="absolute top-3 right-3 w-9 h-9 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors backdrop-blur-sm"
            aria-label="Schließen"
          >
            <X className="w-5 h-5" />
          </button>

          {/* Prev/Next */}
          {hasPrev && onPrev && (
            <button
              onClick={onPrev}
              className="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors backdrop-blur-sm"
              aria-label="Vorheriges"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
          )}
          {hasNext && onNext && (
            <button
              onClick={onNext}
              className="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors backdrop-blur-sm"
              aria-label="Nächstes"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          )}

          {/* Year badge */}
          {item.year && (
            <span className="absolute top-3 left-3 px-2.5 py-1 bg-black/60 text-white text-xs font-bold rounded-lg backdrop-blur-sm tabular-nums">
              {item.year}
            </span>
          )}
        </div>

        {/* Meta */}
        <div className="p-5 space-y-3">
          <div>
            <h3 className="text-lg font-bold text-ink-900 dark:text-stone-100 leading-tight">
              {item.title}
            </h3>
            {item.subtitle && (
              <p className="text-sm text-ink-600 dark:text-stone-400 mt-1">{item.subtitle}</p>
            )}
          </div>

          <div className="flex items-center gap-2 flex-wrap pt-1">
            <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-primary-50 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 rounded-full text-xs font-medium capitalize">
              {item.type === 'image'    && '🖼️ Bild'}
              {item.type === 'document' && '📄 Dokument'}
              {item.type === 'audio'    && '🎵 Audio'}
              {item.type === 'video'    && '🎬 Video'}
              {item.type === 'object'   && '🏺 Objekt'}
              {item.type === 'unknown'  && '📦 Kulturgut'}
            </span>
            {item.year && (
              <span className="text-xs text-ink-500 dark:text-stone-400 tabular-nums">
                Jahr: <strong>{item.year}</strong>
              </span>
            )}
          </div>

          <a
            href={item.detailUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-primary-500 to-primary-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 mt-1"
          >
            <ExternalLink className="w-4 h-4" />
            Auf DDB ansehen
          </a>

          <p className="text-xs text-ink-400 dark:text-stone-500 pt-2 border-t border-stone-100 dark:border-stone-800">
            Quelle: Deutsche Digitale Bibliothek
          </p>
        </div>
      </div>
    </div>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────

interface Props {
  /** Override auto-detected city – useful for testing */
  cityName?: string
  /** "Heute vor 100 Jahren"-Modus */
  historicalMode?: boolean
  /** Anzahl der Treffer */
  limit?: number
  className?: string
  /** Kompakte Variante ohne Header-Beschreibung */
  compact?: boolean
  /** Custom Headline */
  title?: string
}

export default function HistoricalGallery({
  cityName: cityNameProp,
  historicalMode = false,
  limit = 8,
  className,
  compact,
  title: titleProp,
}: Props) {
  const [cityName, setCityName] = useState<string | null>(cityNameProp ?? null)
  const [items, setItems]       = useState<CulturalItem[]>([])
  const [loading, setLoading]   = useState(true)
  const [activeIdx, setActiveIdx] = useState<number | null>(null)
  const [historyYear, setHistoryYear] = useState<number | null>(null)

  // ── City resolution ──
  useEffect(() => {
    if (cityNameProp) { setCityName(cityNameProp); return }

    let cancelled = false
    ;(async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) return

        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude, address, location')
          .eq('id', user.id)
          .maybeSingle()

        if (cancelled) return

        if (profile?.latitude != null && profile?.longitude != null) {
          const detected = await getCityFromCoords(
            profile.latitude as number,
            profile.longitude as number,
          )
          if (!cancelled && detected) { setCityName(detected); return }
        }

        const addr = (profile?.address ?? profile?.location ?? '') as string
        if (addr) {
          const parts    = addr.split(',').map(p => p.trim())
          const last     = parts[parts.length - 1] ?? ''
          const stripped = last.replace(/^\d{4,5}\s*/, '').trim()
          if (stripped.length > 2 && !cancelled) { setCityName(stripped); return }
        }
      } catch { /* silent */ }
      if (!cancelled) setLoading(false)
    })()

    return () => { cancelled = true }
  }, [cityNameProp])

  // ── Item fetch ──
  useEffect(() => {
    if (!cityName) return
    if (!isDdbConfigured()) { setLoading(false); return }

    let cancelled = false
    setLoading(true)
    ;(async () => {
      try {
        if (historicalMode) {
          const { year, items: hist } = await searchHistoricalItems(cityName, 100, limit)
          if (cancelled) return
          setHistoryYear(year)
          setItems(hist)
        } else {
          const result = await searchCulturalItems(cityName, limit, { mediaType: 'image' })
          if (cancelled) return
          setItems(result)
        }
      } catch { /* silent */ }
      if (!cancelled) setLoading(false)
    })()
    return () => { cancelled = true }
  }, [cityName, historicalMode, limit])

  const handlePrev = useCallback(() => {
    setActiveIdx(idx => (idx == null ? null : Math.max(0, idx - 1)))
  }, [])
  const handleNext = useCallback(() => {
    setActiveIdx(idx => (idx == null ? null : Math.min(items.length - 1, idx + 1)))
  }, [items.length])

  if (loading) return <GallerySkeleton />
  if (!isDdbConfigured() || items.length === 0 || !cityName) return null

  const headline = titleProp ?? (
    historicalMode && historyYear
      ? `Heute vor 100 Jahren in ${cityName} (${historyYear})`
      : `Historisches aus ${cityName}`
  )

  return (
    <div className={`relative bg-white dark:bg-stone-900 border border-stone-200 dark:border-stone-700 rounded-2xl shadow-soft overflow-hidden ${className ?? ''}`}>
      <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-amber-500 via-amber-400 to-amber-200" />

      <div className="p-4 space-y-3">
        {/* Header */}
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-amber-50 dark:bg-amber-900/30 flex items-center justify-center flex-shrink-0">
              <Library className="w-4 h-4 text-amber-600 dark:text-amber-400" />
            </div>
            <div>
              <h3 className="font-bold text-ink-900 dark:text-stone-100 leading-tight text-sm">
                {headline}
              </h3>
              {!compact && (
                <p className="text-[11px] text-ink-500 dark:text-stone-400 mt-0.5">
                  Historische Fotos & Kulturgüter aus der Deutschen Digitalen Bibliothek
                </p>
              )}
            </div>
          </div>
          <a
            href={`https://www.deutsche-digitale-bibliothek.de/searchresults?query=${encodeURIComponent(cityName)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex-shrink-0 p-1.5 rounded-lg text-ink-400 hover:text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-900/20 transition-colors"
            title="Mehr auf DDB"
          >
            <ExternalLink className="w-4 h-4" />
          </a>
        </div>

        {/* Horizontal Scroll Gallery */}
        <div className="-mx-1 px-1 overflow-x-auto">
          <div className="flex gap-3 pb-2">
            {items.map((item, idx) => (
              <GalleryCard
                key={item.id}
                item={item}
                onClick={() => setActiveIdx(idx)}
              />
            ))}
          </div>
        </div>

        {/* Attribution */}
        <p className="text-xs text-ink-400 dark:text-stone-500 pt-1">
          Quelle: Deutsche Digitale Bibliothek
        </p>
      </div>

      {/* Detail Modal */}
      {activeIdx != null && items[activeIdx] && (
        <DetailModal
          item={items[activeIdx]}
          onClose={() => setActiveIdx(null)}
          onPrev={activeIdx > 0 ? handlePrev : undefined}
          onNext={activeIdx < items.length - 1 ? handleNext : undefined}
          hasPrev={activeIdx > 0}
          hasNext={activeIdx < items.length - 1}
        />
      )}
    </div>
  )
}
