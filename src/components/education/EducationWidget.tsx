'use client'

import { useEffect, useState, useCallback } from 'react'
import { GraduationCap, BookOpen, MapPin, Calendar, ExternalLink, ChevronRight, Loader2, Search, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import {
  searchApprenticeships,
  searchCourses,
  formatStartDate,
  type Apprenticeship,
  type Course,
} from '@/lib/api/education'
import { reverseGeocode } from '@/lib/api/nominatim'

// ── Types ─────────────────────────────────────────────────────────────────────

type Tab = 'apprenticeship' | 'course'
type Item = Apprenticeship | Course

// ── Helpers ───────────────────────────────────────────────────────────────────

async function resolvePlz(userId: string): Promise<string | null> {
  const supabase = createClient()

  // 1. Try profile address field (regex for 5-digit PLZ)
  const { data: profile } = await supabase
    .from('profiles')
    .select('address, location, latitude, longitude')
    .eq('id', userId)
    .maybeSingle()

  const fromAddress = (profile?.address ?? '')
    .match(/\b\d{5}\b/)?.[0] ?? null
  if (fromAddress) return fromAddress

  // 2. Reverse geocode from coordinates
  if (profile?.latitude != null && profile?.longitude != null) {
    const addr = await reverseGeocode(
      profile.latitude as number,
      profile.longitude as number,
    )
    if (addr.postcode) return addr.postcode
  }

  return null
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function ItemSkeleton() {
  return (
    <div className="space-y-2">
      {[1, 2, 3].map(i => (
        <div key={i} className="animate-pulse flex gap-3 p-3 rounded-xl bg-stone-50">
          <div className="w-9 h-9 rounded-lg bg-stone-200 flex-shrink-0" />
          <div className="flex-1 space-y-1.5 pt-0.5">
            <div className="h-3 bg-stone-200 rounded w-3/4" />
            <div className="h-2.5 bg-stone-200 rounded w-1/2" />
            <div className="h-2.5 bg-stone-200 rounded w-1/3" />
          </div>
        </div>
      ))}
    </div>
  )
}

// ── Item Card ─────────────────────────────────────────────────────────────────

function ItemCard({ item, color }: { item: Item; color: string }) {
  return (
    <a
      href={item.url}
      target="_blank"
      rel="noopener noreferrer"
      className="group flex items-start gap-3 p-3 rounded-xl hover:bg-stone-50 transition-colors"
    >
      <div
        className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5"
        style={{ background: `${color}18` }}
      >
        {item.type === 'apprenticeship'
          ? <GraduationCap className="w-4 h-4" style={{ color }} />
          : <BookOpen       className="w-4 h-4" style={{ color }} />
        }
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-xs font-semibold text-ink-900 line-clamp-2 group-hover:text-primary-700 transition-colors">
          {item.title}
        </p>
        {item.provider && (
          <p className="text-[11px] text-ink-500 truncate mt-0.5">{item.provider}</p>
        )}
        <div className="flex flex-wrap items-center gap-2 mt-1">
          {item.city && (
            <span className="flex items-center gap-0.5 text-[10px] text-ink-400">
              <MapPin className="w-2.5 h-2.5" />{item.city}
            </span>
          )}
          {item.startDate && (
            <span className="flex items-center gap-0.5 text-[10px] text-ink-400">
              <Calendar className="w-2.5 h-2.5" />{formatStartDate(item.startDate)}
            </span>
          )}
          {item.type === 'course' && (item as Course).funded && (
            <span className="text-[10px] font-medium text-primary-600 bg-primary-50 px-1.5 py-0.5 rounded-full">
              Förderbar
            </span>
          )}
          {item.type === 'course' && (item as Course).category && (
            <span className="text-[10px] text-ink-500 bg-stone-100 px-1.5 py-0.5 rounded-full truncate max-w-[120px]">
              {(item as Course).category}
            </span>
          )}
        </div>
      </div>

      <ExternalLink className="w-3.5 h-3.5 text-stone-400 group-hover:text-primary-400 flex-shrink-0 mt-1 transition-colors" />
    </a>
  )
}

// ── Main Widget ───────────────────────────────────────────────────────────────

interface EducationWidgetProps {
  /** compact=true → header-only with 3 items, no search; for dashboard teaser */
  compact?: boolean
  className?: string
}

export default function EducationWidget({ compact, className }: EducationWidgetProps) {
  const [plz, setPlz]           = useState<string | null>(null)
  const [tab, setTab]           = useState<Tab>('apprenticeship')
  const [query, setQuery]       = useState('')
  const [debouncedQ, setDQ]     = useState('')
  const [items, setItems]       = useState<Item[]>([])
  const [total, setTotal]       = useState(0)
  const [loading, setLoading]   = useState(true)
  const [error, setError]       = useState<string | null>(null)
  const [noPlz, setNoPlz]       = useState(false)

  // Debounce search query
  useEffect(() => {
    const t = setTimeout(() => setDQ(query), 400)
    return () => clearTimeout(t)
  }, [query])

  // Resolve PLZ on mount
  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) { setLoading(false); return }
        const resolved = await resolvePlz(user.id)
        if (cancelled) return
        if (!resolved) { setNoPlz(true); setLoading(false); return }
        setPlz(resolved)
      } catch {
        if (!cancelled) { setLoading(false); setNoPlz(true) }
      }
    })()
    return () => { cancelled = true }
  }, [])

  // Fetch education items
  const fetchItems = useCallback(async () => {
    if (!plz) return
    setLoading(true)
    setError(null)
    try {
      const size = compact ? 3 : 8
      const opts = { query: debouncedQ || undefined, size }

      const result = tab === 'apprenticeship'
        ? await searchApprenticeships(plz, 25, opts)
        : await searchCourses(plz, 25, opts)

      setItems(result.items)
      setTotal(result.total)
    } catch {
      setError('Angebote konnten nicht geladen werden.')
    } finally {
      setLoading(false)
    }
  }, [plz, tab, debouncedQ, compact])

  useEffect(() => { void fetchItems() }, [fetchItems])

  // ── Compact (dashboard teaser) ─────────────────────────────────────────────
  if (compact) {
    if (loading) return (
      <div className={cn('bg-white rounded-2xl border border-stone-200 shadow-soft p-4', className)}>
        <div className="flex items-center gap-2 mb-3">
          <div className="w-7 h-7 rounded-lg bg-primary-50 flex items-center justify-center">
            <GraduationCap className="w-4 h-4 text-primary-600" />
          </div>
          <div className="h-3.5 bg-stone-100 rounded w-36 animate-pulse" />
        </div>
        <ItemSkeleton />
      </div>
    )
    if (noPlz || items.length === 0) return null
    return (
      <div className={cn('bg-white rounded-2xl border border-stone-200 shadow-soft overflow-hidden', className)}>
        <div className="flex items-center justify-between px-4 py-3 border-b border-stone-100">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-primary-50 flex items-center justify-center flex-shrink-0">
              <GraduationCap className="w-4 h-4 text-primary-600" />
            </div>
            <h2 className="text-sm font-semibold text-ink-900">Bildung in deiner Nähe</h2>
          </div>
          <a
            href="/dashboard/community"
            className="flex items-center gap-0.5 text-xs font-medium text-primary-600 hover:text-primary-700 transition-colors"
          >
            Mehr <ChevronRight className="w-3.5 h-3.5" />
          </a>
        </div>
        <div className="px-2 py-2">
          {items.slice(0, 3).map(item => (
            <ItemCard key={item.id} item={item} color="#1EAAA6" />
          ))}
        </div>
      </div>
    )
  }

  // ── Full Widget ────────────────────────────────────────────────────────────

  const accentColor = tab === 'apprenticeship' ? '#1EAAA6' : '#8B5CF6'

  return (
    <div className={cn('bg-white rounded-2xl border border-stone-200 shadow-soft overflow-hidden', className)}>
      {/* Header */}
      <div className="relative px-4 pt-4 pb-0">
        <div className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: `linear-gradient(90deg, ${accentColor}, ${accentColor}33)` }}
        />
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
              style={{ background: `${accentColor}18` }}
            >
              <GraduationCap className="w-5 h-5" style={{ color: accentColor }} />
            </div>
            <div>
              <h3 className="font-bold text-ink-900 leading-tight">Bildung in deiner Nähe</h3>
              {plz && <p className="text-[11px] text-ink-400 mt-0.5">PLZ {plz} · 25 km Umkreis</p>}
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 bg-stone-100 p-1 rounded-xl mb-3">
          {([
            { key: 'apprenticeship' as Tab, label: 'Ausbildung',    icon: GraduationCap },
            { key: 'course'         as Tab, label: 'Weiterbildung', icon: BookOpen },
          ]).map(({ key, label, icon: Icon }) => (
            <button
              key={key}
              onClick={() => { setTab(key); setQuery('') }}
              className={cn(
                'flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg text-xs font-medium transition-all',
                tab === key
                  ? 'bg-white text-ink-900 shadow-soft'
                  : 'text-ink-500 hover:text-ink-700',
              )}
            >
              <Icon className="w-3.5 h-3.5" />
              {label}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative mb-3">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-400" />
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder={tab === 'apprenticeship' ? 'Ausbildung suchen…' : 'Kurs oder Thema suchen…'}
            className="w-full pl-9 pr-8 py-2 text-xs border border-stone-200 rounded-xl focus:outline-none focus:ring-1 focus:ring-primary-300 bg-white"
          />
          {query && (
            <button
              onClick={() => setQuery('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-ink-400 hover:text-ink-600 transition-colors"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Body */}
      <div className="px-2 pb-3">
        {loading ? (
          <div className="px-2"><ItemSkeleton /></div>
        ) : error ? (
          <div className="px-4 py-6 text-center">
            <p className="text-xs text-red-500">{error}</p>
          </div>
        ) : noPlz ? (
          <div className="px-4 py-6 text-center space-y-1">
            <GraduationCap className="w-8 h-8 text-stone-300 mx-auto" />
            <p className="text-xs font-medium text-ink-700">Kein Standort gesetzt</p>
            <p className="text-[11px] text-ink-400">
              Trage deine PLZ im Profil ein, um Bildungsangebote in der Nähe zu sehen.
            </p>
          </div>
        ) : items.length === 0 ? (
          <div className="px-4 py-6 text-center space-y-1">
            <BookOpen className="w-8 h-8 text-stone-300 mx-auto" />
            <p className="text-xs font-medium text-ink-700">Keine Angebote gefunden</p>
            <p className="text-[11px] text-ink-400">
              Versuche einen anderen Suchbegriff oder erweitere den Umkreis.
            </p>
          </div>
        ) : (
          <>
            {items.map(item => (
              <ItemCard key={item.id} item={item} color={accentColor} />
            ))}

            {/* Footer */}
            {total > items.length && (
              <div className="px-2 pt-2">
                <a
                  href={
                    tab === 'apprenticeship'
                      ? `https://www.arbeitsagentur.de/bildung/ausbildung/ausbildungsangebote?ort=${plz}&umkreis=25`
                      : `https://kursnet-finden.arbeitsagentur.de/kurs/suche?plz=${plz}&umkreis=25`
                  }
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-1 py-2 rounded-xl text-xs font-medium text-primary-600 hover:bg-primary-50 border border-primary-100 transition-colors"
                >
                  Alle {total.toLocaleString('de-DE')} Angebote auf arbeitsagentur.de
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            )}
          </>
        )}
      </div>

      {/* Attribution */}
      <div className="px-4 pb-3">
        <p className="text-[10px] text-ink-400 text-right">
          Quelle: Bundesagentur für Arbeit
        </p>
      </div>
    </div>
  )
}
