'use client'

import { useState, useMemo } from 'react'
import { Heart, Smartphone, ExternalLink, Search, X, Info, Share2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  DIGAS,
  DIGA_CATEGORIES,
  filterDigas,
  getDigaCategories,
  type DiGA,
  type DigaCategory,
} from '@/lib/data/digas'

// ── Helpers ───────────────────────────────────────────────────────────────────

function hasApp(d: DiGA): boolean {
  return !!(d.appStoreUrl || d.playStoreUrl)
}

// ── Share banner for Community integration ────────────────────────────────────

function ShareBanner({ diga }: { diga: DiGA }) {
  const [shared, setShared] = useState(false)

  const handleShare = async () => {
    const text = `📱 DiGA-Tipp: "${diga.name}" – ${diga.indication}.\nKostenlos auf Rezept vom Arzt! Mehr infos: ${diga.url}`
    if (navigator.share) {
      await navigator.share({ title: diga.name, text, url: diga.url })
    } else {
      await navigator.clipboard.writeText(text)
    }
    setShared(true)
    setTimeout(() => setShared(false), 2000)
  }

  return (
    <button
      onClick={handleShare}
      className="flex items-center gap-1 text-[10px] text-ink-400 hover:text-primary-600 transition-colors"
      title="Teilen"
    >
      <Share2 className="w-3 h-3" />
      {shared ? 'Kopiert!' : 'Teilen'}
    </button>
  )
}

// ── DiGA Card ─────────────────────────────────────────────────────────────────

function DigaCard({ diga, showShare }: { diga: DiGA; showShare?: boolean }) {
  const cat   = DIGA_CATEGORIES[diga.category]
  const color = cat.color

  return (
    <div className="relative bg-white border border-stone-200 rounded-2xl overflow-hidden shadow-soft hover:shadow-card transition-shadow flex flex-col">
      {/* Top accent */}
      <div className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: `linear-gradient(90deg, ${color}, ${color}33)` }}
      />

      <div className="p-4 flex flex-col gap-3 flex-1">
        {/* Header */}
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-start gap-2.5 min-w-0">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-lg"
              style={{ background: `${color}15` }}
            >
              {cat.emoji}
            </div>
            <div className="min-w-0">
              <h3 className="font-bold text-ink-900 text-sm leading-tight">{diga.name}</h3>
              <p className="text-[11px] text-ink-500 mt-0.5 truncate">{diga.manufacturer}</p>
            </div>
          </div>
          {hasApp(diga) && (
            <span className="flex-shrink-0 flex items-center gap-0.5 text-[10px] font-medium px-2 py-0.5 rounded-full"
              style={{ background: `${color}12`, color }}
            >
              <Smartphone className="w-2.5 h-2.5" /> App
            </span>
          )}
        </div>

        {/* Indication badge */}
        <div className="flex items-center gap-1.5">
          <Heart className="w-3 h-3 flex-shrink-0" style={{ color }} />
          <span className="text-[11px] font-semibold" style={{ color }}>
            {diga.indication}
          </span>
        </div>

        {/* Description */}
        <p className="text-xs text-ink-600 leading-relaxed line-clamp-3 flex-1">
          {diga.description}
        </p>

        {/* Footer */}
        <div className="flex items-center justify-between gap-2 pt-1 border-t border-stone-100">
          <div className="flex items-center gap-2">
            {diga.playStoreUrl && (
              <a href={diga.playStoreUrl} target="_blank" rel="noopener noreferrer"
                className="text-[10px] text-ink-400 hover:text-primary-600 transition-colors underline underline-offset-2"
              >
                Android
              </a>
            )}
            {diga.appStoreUrl && (
              <a href={diga.appStoreUrl} target="_blank" rel="noopener noreferrer"
                className="text-[10px] text-ink-400 hover:text-primary-600 transition-colors underline underline-offset-2"
              >
                iOS
              </a>
            )}
            {showShare && <ShareBanner diga={diga} />}
          </div>
          <a
            href={diga.url}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 text-xs font-semibold transition-colors hover:opacity-80"
            style={{ color }}
          >
            Mehr erfahren <ExternalLink className="w-3 h-3" />
          </a>
        </div>
      </div>
    </div>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────

interface DigaDirectoryProps {
  /** community=true adds share button to each card */
  community?: boolean
  /** compact=true shows only 4 cards without search/filter */
  compact?: boolean
  className?: string
}

export default function DigaDirectory({ community, compact, className }: DigaDirectoryProps) {
  const [activeCategory, setActiveCategory] = useState<DigaCategory | 'all'>('all')
  const [query, setQuery]                   = useState('')

  const categories = useMemo(() => getDigaCategories(), [])

  const filtered = useMemo(
    () => filterDigas(
      activeCategory === 'all' ? undefined : activeCategory,
      query || undefined,
    ),
    [activeCategory, query],
  )

  const displayed = compact ? DIGAS.slice(0, 4) : filtered

  return (
    <div className={cn('space-y-4', className)}>
      {/* Info banner */}
      <div className="relative flex items-start gap-3 bg-primary-50 border border-primary-200 rounded-2xl p-4 overflow-hidden">
        <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-primary-400 to-primary-200" />
        <div className="w-8 h-8 rounded-xl bg-primary-100 flex items-center justify-center flex-shrink-0">
          <Info className="w-4 h-4 text-primary-600" />
        </div>
        <div className="min-w-0">
          <p className="text-sm font-bold text-primary-900">Gesundheits-Apps auf Rezept – kostenlos!</p>
          <p className="text-xs text-primary-700 mt-0.5 leading-relaxed">
            Digitale Gesundheitsanwendungen (DiGAs) sind vom BfArM zugelassene Apps, die du{' '}
            <strong>kostenlos über deine Krankenkasse</strong> bekommst – entweder per{' '}
            ärztlichem Rezept oder per Direktantrag bei deiner Kasse (§ 33a SGB V).
          </p>
        </div>
      </div>

      {!compact && (
        <>
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
            <input
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="DiGA suchen (z.B. Rücken, Depression, Tinnitus)…"
              className="w-full pl-10 pr-9 py-2.5 text-sm border border-stone-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 bg-white"
            />
            {query && (
              <button
                onClick={() => setQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-400 hover:text-ink-600"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Category chips */}
          <div className="flex flex-wrap gap-1.5">
            <button
              onClick={() => setActiveCategory('all')}
              className={cn(
                'px-3 py-1.5 rounded-full text-xs font-medium border transition-all',
                activeCategory === 'all'
                  ? 'bg-primary-600 text-white border-primary-600'
                  : 'bg-white text-ink-600 border-stone-200 hover:border-primary-300',
              )}
            >
              Alle ({DIGAS.length})
            </button>
            {categories.map(cat => {
              const meta  = DIGA_CATEGORIES[cat]
              const count = DIGAS.filter(d => d.category === cat).length
              const isActive = activeCategory === cat
              return (
                <button
                  key={cat}
                  onClick={() => setActiveCategory(isActive ? 'all' : cat)}
                  className={cn(
                    'flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium border transition-all',
                    isActive
                      ? 'text-white border-transparent'
                      : 'bg-white text-ink-600 border-stone-200 hover:border-stone-300',
                  )}
                  style={isActive ? { background: meta.color, borderColor: meta.color } : {}}
                >
                  <span>{meta.emoji}</span>
                  {meta.label} ({count})
                </button>
              )
            })}
          </div>
        </>
      )}

      {/* Grid */}
      {displayed.length === 0 ? (
        <div className="text-center py-12 bg-white border border-stone-200 rounded-2xl">
          <Heart className="w-8 h-8 text-stone-300 mx-auto mb-2" />
          <p className="text-sm font-medium text-ink-700">Keine DiGAs gefunden</p>
          <p className="text-xs text-ink-400 mt-1">Versuche einen anderen Suchbegriff oder wähle „Alle".</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {displayed.map(diga => (
            <DigaCard key={diga.id} diga={diga} showShare={community} />
          ))}
        </div>
      )}

      {/* Count & BfArM link */}
      {!compact && (
        <div className="flex items-center justify-between text-[11px] text-ink-400 px-1">
          <span>{filtered.length} von {DIGAS.length} DiGAs angezeigt</span>
          <a
            href="https://diga.bfarm.de/de/verzeichnis"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 hover:text-primary-600 transition-colors"
          >
            Vollständiges Verzeichnis auf bfarm.de <ExternalLink className="w-3 h-3" />
          </a>
        </div>
      )}
    </div>
  )
}
