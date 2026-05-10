'use client'

import { useEffect, useState, useCallback } from 'react'
import { Library, Image as ImageIcon, ExternalLink, X, ChevronLeft, ChevronRight } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { getCityFromCoords } from '@/lib/api/wikidata'

// ── Types ─────────────────────────────────────────────────────────────────────

interface HistoricalPhoto {
  id:           string
  title:        string
  thumbnailUrl: string
  detailUrl:    string
  year:         string | null
  description:  string | null
}

// ── Wikimedia Commons API ─────────────────────────────────────────────────────

const COMMONS_API = 'https://commons.wikimedia.org/w/api.php'
const CACHE_TTL   = 24 * 60 * 60 * 1000

function cacheRead<T>(key: string): T | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw) as { data: T; ts: number }
    if (Date.now() - ts < CACHE_TTL) return data
    localStorage.removeItem(key)
  } catch { /* ignore */ }
  return null
}

function cacheWrite<T>(key: string, data: T) {
  if (typeof window === 'undefined') return
  try { localStorage.setItem(key, JSON.stringify({ data, ts: Date.now() })) } catch { /* quota */ }
}

async function fetchCommonsPhotos(city: string, limit = 8): Promise<HistoricalPhoto[]> {
  const cacheKey = `commons_hist_${city.toLowerCase().replace(/\s+/g, '_')}_${limit}`
  const cached = cacheRead<HistoricalPhoto[]>(cacheKey)
  if (cached) return cached

  const queries = [
    `${city} historisch`,
    `${city} Geschichte`,
    `${city} 1900`,
  ]

  for (const q of queries) {
    try {
      const params = new URLSearchParams({
        action:      'query',
        generator:   'search',
        gsrsearch:   q,
        gsrnamespace: '6',
        gsrlimit:    String(Math.min(limit * 2, 20)),
        prop:        'imageinfo',
        iiprop:      'url|extmetadata',
        iiurlwidth:  '300',
        format:      'json',
        origin:      '*',
      })
      const res = await fetch(`${COMMONS_API}?${params}`, {
        signal:  AbortSignal.timeout(8_000),
        headers: { 'User-Agent': 'MensaEna/1.0 (https://www.mensaena.de)' },
      })
      if (!res.ok) continue

      const json = await res.json() as {
        query?: {
          pages?: Record<string, {
            pageid: number
            title:  string
            imageinfo?: {
              url:           string
              extmetadata?: {
                DateTimeOriginal?: { value: string }
                DateTime?:         { value: string }
                ImageDescription?: { value: string }
                ObjectName?:       { value: string }
              }
            }[]
          }>
        }
      }

      const pages = Object.values(json.query?.pages ?? {})
      const photos: HistoricalPhoto[] = pages
        .filter(p => p.imageinfo?.[0]?.url && /\.(jpg|jpeg|png|gif)$/i.test(p.imageinfo[0].url))
        .map(p => {
          const info = p.imageinfo![0]
          const meta = info.extmetadata ?? {}
          const rawDesc = meta.ImageDescription?.value ?? meta.ObjectName?.value ?? ''
          const desc = rawDesc.replace(/<[^>]+>/g, '').trim().slice(0, 120) || null
          const rawYear = meta.DateTimeOriginal?.value ?? meta.DateTime?.value ?? ''
          const yearMatch = rawYear.match(/\b(1[6-9]\d{2}|20[0-2]\d)\b/)
          return {
            id:          String(p.pageid),
            title:       p.title.replace(/^File:/, '').replace(/\.\w{2,4}$/, ''),
            thumbnailUrl: info.url,
            detailUrl:   `https://commons.wikimedia.org/wiki/${encodeURIComponent(p.title)}`,
            year:        yearMatch?.[1] ?? null,
            description: desc,
          }
        })
        .slice(0, limit)

      if (photos.length >= 3) {
        cacheWrite(cacheKey, photos)
        return photos
      }
    } catch { /* try next query */ }
  }
  return []
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function GallerySkeleton() {
  return (
    <div className="bg-mn-elevated rounded-2xl border border-white/5 p-4 shadow-soft animate-pulse">
      <div className="h-5 bg-mn-raised rounded-lg w-2/3 mb-3" />
      <div className="flex gap-3 overflow-hidden">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="w-32 h-40 bg-mn-raised rounded-xl flex-shrink-0" />
        ))}
      </div>
    </div>
  )
}

// ── Card ──────────────────────────────────────────────────────────────────────

function GalleryCard({ photo, onClick }: { photo: HistoricalPhoto; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="group relative w-32 sm:w-36 flex-shrink-0 rounded-xl overflow-hidden bg-mn-elevated border border-white/5 shadow-soft hover:shadow-card transition-all hover:scale-[1.02] active:scale-95 text-left"
      title={photo.title}
    >
      <div className="aspect-[3/4] relative bg-mn-raised">
        <img
          src={photo.thumbnailUrl}
          alt={photo.title}
          className="w-full h-full object-cover"
          loading="lazy"
          onError={e => { (e.currentTarget.parentElement!.style.background = '#1a2235') ; e.currentTarget.style.display = 'none' }}
        />
        {photo.year && (
          <span className="absolute top-1.5 right-1.5 px-1.5 py-0.5 bg-black/60 text-white text-xs font-bold rounded backdrop-blur-sm tabular-nums">
            {photo.year}
          </span>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/0 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
      </div>
      <div className="p-2 bg-mn-elevated">
        <p className="text-xs font-semibold text-mn-ink line-clamp-2 leading-tight">{photo.title}</p>
      </div>
    </button>
  )
}

// ── Detail Modal ──────────────────────────────────────────────────────────────

function DetailModal({
  photo,
  onClose,
  onPrev,
  onNext,
  hasPrev,
  hasNext,
}: {
  photo:   HistoricalPhoto
  onClose: () => void
  onPrev?: () => void
  onNext?: () => void
  hasPrev: boolean
  hasNext: boolean
}) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft'  && hasPrev && onPrev) onPrev()
      if (e.key === 'ArrowRight' && hasNext && onNext) onNext()
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose, onPrev, onNext, hasPrev, hasNext])

  return (
    <div
      className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
    >
      <div
        className="bg-mn-elevated rounded-2xl max-w-3xl w-full max-h-[90dvh] overflow-y-auto shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        <div className="relative bg-mn-deep flex items-center justify-center min-h-[300px] max-h-[60vh]">
          <img
            src={photo.thumbnailUrl}
            alt={photo.title}
            className="max-w-full max-h-[60vh] object-contain"
          />
          <button
            onClick={onClose}
            className="absolute top-3 right-3 w-9 h-9 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors"
            aria-label="Schließen"
          >
            <X className="w-5 h-5" />
          </button>
          {hasPrev && onPrev && (
            <button onClick={onPrev} className="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors" aria-label="Vorheriges">
              <ChevronLeft className="w-5 h-5" />
            </button>
          )}
          {hasNext && onNext && (
            <button onClick={onNext} className="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 text-white flex items-center justify-center transition-colors" aria-label="Nächstes">
              <ChevronRight className="w-5 h-5" />
            </button>
          )}
          {photo.year && (
            <span className="absolute top-3 left-3 px-2.5 py-1 bg-black/60 text-white text-xs font-bold rounded-lg backdrop-blur-sm">
              {photo.year}
            </span>
          )}
        </div>

        <div className="p-5 space-y-3">
          <h3 className="text-lg font-bold text-mn-ink leading-tight">{photo.title}</h3>
          {photo.description && (
            <p className="text-sm text-mn-ink-soft leading-relaxed">{photo.description}</p>
          )}
          <a
            href={photo.detailUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-primary-500 to-primary-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all"
          >
            <ExternalLink className="w-4 h-4" />
            Auf Wikimedia Commons ansehen
          </a>
          <p className="text-xs text-mn-mute pt-2 border-t border-white/5">
            Quelle: Wikimedia Commons (CC-Lizenz)
          </p>
        </div>
      </div>
    </div>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────

interface Props {
  cityName?:      string
  historicalMode?: boolean
  limit?:         number
  className?:     string
  compact?:       boolean
  title?:         string
}

export default function HistoricalGallery({
  cityName: cityNameProp,
  limit = 8,
  className,
  compact,
  title: titleProp,
}: Props) {
  const [cityName, setCityName]     = useState<string | null>(cityNameProp ?? null)
  const [photos, setPhotos]         = useState<HistoricalPhoto[]>([])
  const [loading, setLoading]       = useState(true)
  const [activeIdx, setActiveIdx]   = useState<number | null>(null)

  // ── City resolution ──
  useEffect(() => {
    if (cityNameProp) { setCityName(cityNameProp); return }

    let cancelled = false
    ;(async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) { setLoading(false); return }

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

        // Fallback: use Berlin for display even without profile location
        if (!cancelled) setCityName('Berlin')
      } catch {
        if (!cancelled) setCityName('Berlin')
      }
    })()
    return () => { cancelled = true }
  }, [cityNameProp])

  // ── Fetch photos ──
  useEffect(() => {
    if (!cityName) return
    let cancelled = false
    setLoading(true)
    ;(async () => {
      const results = await fetchCommonsPhotos(cityName, limit)
      if (!cancelled) {
        setPhotos(results)
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [cityName, limit])

  const handlePrev = useCallback(() => {
    setActiveIdx(idx => (idx == null ? null : Math.max(0, idx - 1)))
  }, [])
  const handleNext = useCallback(() => {
    setActiveIdx(idx => (idx == null ? null : Math.min(photos.length - 1, idx + 1)))
  }, [photos.length])

  if (loading) return <GallerySkeleton />

  if (photos.length === 0) {
    return (
      <div className={`bg-mn-elevated border border-white/5 rounded-2xl p-4 shadow-soft ${className ?? ''}`}>
        <div className="flex items-center gap-2 mb-2">
          <div className="w-9 h-9 rounded-xl bg-mn-amber/5 flex items-center justify-center flex-shrink-0">
            <Library className="w-4 h-4 text-mn-amber" />
          </div>
          <h3 className="text-sm font-bold text-mn-ink">
            {titleProp ?? `Historisches${cityName ? ` aus ${cityName}` : ''}`}
          </h3>
        </div>
        <div className="flex flex-col items-center justify-center py-4 gap-2">
          <ImageIcon className="w-8 h-8 text-mn-ghost" />
          <p className="text-xs text-mn-mute text-center">Keine historischen Fotos gefunden.</p>
          {cityName && (
            <a
              href={`https://commons.wikimedia.org/w/index.php?search=${encodeURIComponent(cityName + ' historisch')}&title=Special:MediaSearch&ns6=1`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-mn-amber hover:underline flex items-center gap-1"
            >
              Auf Wikimedia suchen <ExternalLink className="w-3 h-3" />
            </a>
          )}
        </div>
      </div>
    )
  }

  const headline = titleProp ?? `Historisches aus ${cityName}`

  return (
    <div className={`relative bg-mn-elevated border border-white/5 rounded-2xl shadow-soft overflow-hidden ${className ?? ''}`}>
      <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-mn-amber/12 via-mn-amber/4 to-transparent" />

      <div className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-mn-amber/5 flex items-center justify-center flex-shrink-0">
              <Library className="w-4 h-4 text-mn-amber" />
            </div>
            <div>
              <h3 className="font-bold text-mn-ink leading-tight text-sm">{headline}</h3>
              {!compact && (
                <p className="text-[11px] text-mn-mute mt-0.5">
                  Historische Fotos aus Wikimedia Commons
                </p>
              )}
            </div>
          </div>
          {cityName && (
            <a
              href={`https://commons.wikimedia.org/w/index.php?search=${encodeURIComponent(cityName + ' historisch')}&title=Special:MediaSearch&ns6=1`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-shrink-0 p-1.5 rounded-lg text-mn-mute hover:text-mn-amber transition-colors"
              title="Mehr auf Wikimedia Commons"
            >
              <ExternalLink className="w-4 h-4" />
            </a>
          )}
        </div>

        <div className="-mx-1 px-1 overflow-x-auto">
          <div className="flex gap-3 pb-2">
            {photos.map((photo, idx) => (
              <GalleryCard
                key={photo.id}
                photo={photo}
                onClick={() => setActiveIdx(idx)}
              />
            ))}
          </div>
        </div>

        <p className="text-xs text-mn-mute pt-1">
          Quelle: Wikimedia Commons (CC-Lizenz)
        </p>
      </div>

      {activeIdx != null && photos[activeIdx] && (
        <DetailModal
          photo={photos[activeIdx]}
          onClose={() => setActiveIdx(null)}
          onPrev={activeIdx > 0 ? handlePrev : undefined}
          onNext={activeIdx < photos.length - 1 ? handleNext : undefined}
          hasPrev={activeIdx > 0}
          hasNext={activeIdx < photos.length - 1}
        />
      )}
    </div>
  )
}
