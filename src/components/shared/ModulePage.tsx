'use client'

import { useState, useEffect, useCallback, useMemo, useRef, isValidElement, cloneElement } from 'react'
import {
  Plus, Search, Users, HandHeart, HelpingHand, Filter,
  HelpCircle, ArrowLeft,
} from 'lucide-react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import ModuleFirstVisitIntro from '@/components/shared/ModuleFirstVisitIntro'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { cn } from '@/lib/utils'
import { useHaptic } from '@/hooks/useHaptic'

/**
 * Rule-based filter: a post matches the module if its type+category matches ANY rule.
 * If `categories` is undefined/empty, ALL posts of that type match.
 * If `categories` is specified, only posts whose category is in the list match.
 */
export interface ModuleFilterRule {
  type: string
  categories?: string[]   // optional – wenn leer, passt JEDER Post dieses Typs
}

/**
 * Mood sets the subtle ambient gradient (and optional animation) behind the
 * module's hero header. Echoes the editorial DashboardHeroCard treatment so
 * every module feels alive instead of static. Defaults to `neutral`.
 */
export type ModuleMood =
  | 'neutral'    // default primary-teal wash
  | 'calm'       // mental-support, rescuer – soft cyan breath
  | 'warm'       // community, sharing – amber/rose
  | 'fresh'      // housing, harvest, animals – green/teal
  | 'scholarly'  // knowledge, skills – indigo/violet
  | 'sky'        // mobility – sky/blue
  | 'gold'       // (reserved) events, timebank
  | 'urgent'     // (reserved) crisis – gentle red pulse

const MOOD_GRADIENT: Record<ModuleMood, string> = {
  neutral:   'from-primary-200/25 via-primary-50/10 to-transparent',
  calm:      'from-cyan-200/35 via-sky-100/15 to-transparent',
  warm:      'from-amber-200/35 via-rose-100/15 to-transparent',
  fresh:     'from-primary-200/30 via-teal-100/15 to-transparent',
  scholarly: 'from-indigo-200/30 via-violet-100/15 to-transparent',
  sky:       'from-sky-200/30 via-cyan-100/15 to-transparent',
  gold:      'from-amber-200/40 via-yellow-100/20 to-transparent',
  urgent:    'from-red-200/30 via-orange-100/15 to-transparent',
}

const MOOD_ANIM: Partial<Record<ModuleMood, string>> = {
  calm:   'animate-module-breathe',
  urgent: 'animate-module-pulse',
}

interface ModulePageProps {
  title: string
  description: string
  icon: React.ReactNode
  color: string          // tailwind bg class for header
  postTypes: string[]    // welche post-types aus der DB geladen werden (Supabase .in())
  /** Intelligentes Filter-System: Wenn gesetzt, wird ein Post nur angezeigt wenn er
   *  mindestens eine Regel erfüllt. So landen Posts GENAU dort, wo sie hingehören. */
  moduleFilter?: ModuleFilterRule[]
  createTypes: { value: string; label: string }[]
  categories: { value: string; label: string }[]
  emptyText?: string
  allowAnonymous?: boolean
  filterCategory?: string   // T: Kategorie-Filter von außen (z.B. Zeitbank)
  children?: React.ReactNode  // optionale extra Widgets oben
  /** Optional editorial section label (e.g. "§ 17 / Teilen") */
  sectionLabel?: string
  /** Tailwind text color class for icon (replaces white-on-gradient) */
  iconColorClass?: string
  /** Tailwind bg class for icon container (e.g. "bg-teal-50") */
  iconBgClass?: string
  /** Mood sets the ambient gradient & optional breath animation behind the hero. */
  mood?: ModuleMood
  /** Optionale Beispiel-Posts, die bei leerem Feed statt des EmptyState angezeigt werden. */
  examplePosts?: { emoji: string; title: string; description: string; type: string; category: string }[]
  /** Optionaler Info-Text – erscheint als klickbares "?" Icon neben dem Modul-Titel. */
  infoTooltip?: string
  /** Modul-Schlüssel für First-Visit-Intro (z.B. 'animals'). Beide Felder müssen gesetzt sein. */
  moduleKey?: string
  /** Steps für das First-Visit-Intro-Overlay. */
  firstVisitIntro?: { steps: { emoji: string; text: string }[] }
}

export default function ModulePage({
  title, description, icon, color,
  postTypes, moduleFilter, createTypes, categories,
  emptyText, allowAnonymous = true, filterCategory, children,
  sectionLabel, iconColorClass = 'text-primary-700', iconBgClass = 'bg-primary-50 border-primary-100',
  mood = 'neutral', examplePosts, infoTooltip, moduleKey, firstVisitIntro,
}: ModulePageProps) {
  // color is intentionally unused in the editorial design (kept for API compatibility)
  void color
  // Recolor the passed-in icon (which often hardcodes text-white from the legacy design)
  const iconNode = isValidElement(icon)
    ? cloneElement(icon as React.ReactElement<{ className?: string }>, {
        className: cn('w-6 h-6', iconColorClass),
      })
    : icon
  // allowAnonymous wird aktuell nicht mehr direkt vom Modul-Header benutzt –
  // die Create-Page liest die Einstellung über ihre Props. Bleibt als API-Compat.
  void allowAnonymous
  const router = useRouter()
  const haptic = useHaptic()
  const [posts, setPosts] = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [currentUserId, setCurrentUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [tooltipOpen, setTooltipOpen] = useState(false)

  /** URL zur modul-spezifischen Create-Page (mit optionalen Prefill-Params) */
  const buildCreateUrl = (defaults: { type?: string; category?: string; title?: string } = {}): string => {
    const params = new URLSearchParams()
    if (defaults.type) params.set('type', defaults.type)
    if (defaults.category) params.set('category', defaults.category)
    if (defaults.title) params.set('title', defaults.title)
    const base = moduleKey ? `/dashboard/${moduleKey}/create` : '/dashboard/create'
    const qs = params.toString()
    return qs ? `${base}?${qs}` : base
  }
  const createUrl = useMemo(
    () => buildCreateUrl(),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [moduleKey],
  )
  const tooltipRef = useRef<HTMLDivElement>(null)
  const [showIntro, setShowIntro] = useState(false)

  useEffect(() => {
    if (!moduleKey || !firstVisitIntro) return
    try {
      const visited: string[] = JSON.parse(localStorage.getItem('mensaena_visited_modules') ?? '[]')
      if (!visited.includes(moduleKey)) setShowIntro(true)
    } catch {}
  }, [moduleKey, firstVisitIntro])
  const [searchTerm, setSearchTerm] = useState('')
  const [filterType, setFilterType] = useState<string>('all')
  const [activeTab, setActiveTab] = useState<'alle' | 'suche' | 'biete'>('alle')

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setCurrentUserId(user.id)

    let q = supabase
      .from('posts')
      .select('*, profiles(name, avatar_url, trust_score)')
      .in('type', postTypes)
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(30)

    const { data, error: postsErr } = await q
    if (postsErr) console.error('ModulePage posts query failed:', postsErr.message)
    // Sort by urgency client-side (TEXT column, alphabetical sort would be wrong)
    const urgencyRank: Record<string, number> = { critical: 4, high: 3, medium: 2, low: 1 }
    const sorted = [...(data ?? [])].sort((a, b) => {
      const ra = urgencyRank[a?.urgency as string] ?? 0
      const rb = urgencyRank[b?.urgency as string] ?? 0
      if (rb !== ra) return rb - ra
      // tiebreak by created_at desc (already pre-sorted, but safe)
      return new Date(b?.created_at ?? 0).getTime() - new Date(a?.created_at ?? 0).getTime()
    })
    setPosts(sorted)

    if (user) {
      const { data: saved, error: savedErr } = await supabase
        .from('saved_posts').select('post_id').eq('user_id', user.id)
      if (savedErr) console.error('ModulePage saved_posts query failed:', savedErr.message)
      setSavedIds((saved ?? []).map((s: { post_id: string }) => s.post_id))
    }
    setLoading(false)
  }, [postTypes])

  useEffect(() => { loadData() }, [loadData])

  useEffect(() => {
    if (!tooltipOpen) return
    const handler = (e: MouseEvent) => {
      if (tooltipRef.current && !tooltipRef.current.contains(e.target as Node)) {
        setTooltipOpen(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [tooltipOpen])

  // Count crisis/rescue as "suche", offering types as "biete" – nach Modul-Filter
  const modulePostsForCount = posts.filter(p => !moduleFilter || moduleFilter.length === 0 || moduleFilter.some(rule => {
    if (p.type !== rule.type) return false
    if (!rule.categories || rule.categories.length === 0) return true
    return rule.categories.includes(p.category ?? '')
  }))
  const seekCount  = modulePostsForCount.filter(p => p.type === 'rescue' || p.type === 'crisis').length
  const offerCount = modulePostsForCount.filter(p => p.type === 'sharing' || p.type === 'supply' || p.type === 'housing' || p.type === 'community' || p.type === 'animal' || p.type === 'mobility').length

  // Intelligente Modul-Zuordnung: Ein Post wird nur angezeigt wenn er
  // mindestens eine ModuleFilterRule erfüllt (type + optional categories).
  const matchesModule = (p: PostCardPost): boolean => {
    if (!moduleFilter || moduleFilter.length === 0) return true // kein Filter → alle anzeigen
    return moduleFilter.some(rule => {
      if (p.type !== rule.type) return false
      if (!rule.categories || rule.categories.length === 0) return true // Typ passt, keine Kategorie-Einschränkung
      return rule.categories.includes(p.category ?? '')
    })
  }

  const modulePosts = posts.filter(matchesModule)

  const filtered = modulePosts.filter(p => {
    const matchTab =
      activeTab === 'alle'  ? true :
      activeTab === 'suche' ? (p.type === 'rescue' || p.type === 'crisis') :
                              (p.type === 'sharing' || p.type === 'supply' || p.type === 'housing' || p.type === 'community' || p.type === 'animal' || p.type === 'mobility')
    const matchType   = filterType === 'all' || p.type === filterType
    const matchSearch = !searchTerm ||
      p.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.description?.toLowerCase().includes(searchTerm.toLowerCase())
    const matchCategory = !filterCategory || p.category === filterCategory
    return matchTab && matchType && matchSearch && matchCategory
  })

  return (
    <div className="relative max-w-5xl mx-auto space-y-6">
      {/* Mobile back button */}
      <button
        type="button"
        onClick={() => router.back()}
        className="sm:hidden flex items-center gap-1.5 -ml-1 px-1 py-1.5 text-sm font-medium text-ink-600 hover:text-ink-900 active:text-ink-900 transition-colors"
        aria-label="Zurück"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück
      </button>

      {showIntro && moduleKey && firstVisitIntro && (
        <ModuleFirstVisitIntro
          moduleKey={moduleKey}
          title={title}
          steps={firstVisitIntro.steps}
          onDismiss={() => setShowIntro(false)}
        />
      )}
      {/* Editorial header */}
      <header className="relative -mx-3 -mt-3 sm:-mx-6 sm:-mt-6 lg:-mx-8 lg:-mt-8 px-3 pt-3 sm:px-6 sm:pt-6 lg:px-8 lg:pt-8 overflow-hidden">
        {/* Ambient mood gradient — echoes DashboardHeroCard */}
        <div
          className={cn(
            'pointer-events-none absolute inset-0 bg-gradient-to-br',
            MOOD_GRADIENT[mood],
            MOOD_ANIM[mood],
          )}
          aria-hidden="true"
        />
        <div className="relative">
        {sectionLabel && (
          <div className="meta-label meta-label--subtle mb-4">{sectionLabel}</div>
        )}
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4 min-w-0">
            <div className={cn('w-14 h-14 rounded-2xl border flex items-center justify-center flex-shrink-0 float-idle', iconBgClass)}>
              {iconNode}
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <h1 className="page-title">{title}</h1>
                {infoTooltip && (
                  <div className="relative flex-shrink-0" ref={tooltipRef}>
                    <button
                      type="button"
                      onClick={() => setTooltipOpen((o) => !o)}
                      aria-label="Mehr Informationen zu diesem Modul"
                      className="p-0.5 rounded-full hover:bg-stone-100 transition-colors"
                    >
                      <HelpCircle className="w-4 h-4 text-stone-400 cursor-pointer" />
                    </button>
                    {tooltipOpen && (
                      <div className="absolute left-0 top-full mt-2 z-50 animate-fade-in">
                        <div className="absolute -top-1.5 left-3 w-3 h-3 bg-ink-800 rotate-45" />
                        <div className="relative bg-ink-800 text-white text-sm rounded-xl p-4 max-w-sm shadow-xl leading-relaxed">
                          {infoTooltip}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
              <p className="page-subtitle mt-2">{description}</p>
            </div>
          </div>
          <Link
            href={createUrl}
            onClick={() => haptic.medium()}
            className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors flex-shrink-0"
          >
            <Plus className="w-4 h-4" />
            <span>Beitrag erstellen</span>
          </Link>
        </div>

        {/* Live-Zähler: Suche / Biete */}
        {!loading && posts.length > 0 && (
          <div className="flex gap-2 mt-5 flex-wrap text-xs tracking-wide text-ink-500">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <HelpingHand className="w-3.5 h-3.5" />
              <span className="font-serif italic text-ink-800 tabular-nums">{seekCount}</span> suchen
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <HandHeart className="w-3.5 h-3.5" />
              <span className="font-serif italic text-ink-800 tabular-nums">{offerCount}</span> bieten
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <Users className="w-3.5 h-3.5" />
              <span className="font-serif italic text-ink-800 tabular-nums">{posts.length}</span> gesamt
            </span>
          </div>
        )}
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
        </div>
      </header>

      {/* Optionale Extra-Widgets */}
      {children}

      {/* Tabs: Alle / Suche Hilfe / Biete Hilfe */}
      <div className="flex gap-1 bg-warm-100 p-1 rounded-xl shadow-sm">
        {([
          { key: 'alle',  label: '🔍 Alle Beiträge' },
          { key: 'suche', label: '🔴 Hilfe gesucht' },
          { key: 'biete', label: '🟢 Hilfe angeboten' },
        ] as { key: 'alle'|'suche'|'biete'; label: string }[]).map(tab => (
          <button key={tab.key}
            onClick={() => { haptic.selection(); setActiveTab(tab.key) }}
            className={cn('flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all',
              activeTab === tab.key
                ? 'bg-white shadow-sm text-ink-900'
                : 'text-ink-500 hover:text-ink-700')}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* Suche + Filter */}
      <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4">
        <div className="flex gap-3 flex-wrap">
          <div className="relative flex-1 min-w-48">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
            <input
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              placeholder="Suchen…"
              className="input pl-9 py-2.5 text-sm w-full"
            />
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Filter className="w-4 h-4 text-ink-400 flex-shrink-0" />
            <button
              onClick={() => { haptic.selection(); setFilterType('all') }}
              className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all',
                filterType === 'all' ? 'bg-primary-600 text-white shadow-sm' : 'bg-white border border-warm-200 text-ink-600 hover:bg-warm-50')}
            >
              Alle
            </button>
            {createTypes.map(t => (
              <button
                key={t.value}
                onClick={() => { haptic.selection(); setFilterType(t.value) }}
                className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all',
                  filterType === t.value ? 'bg-primary-600 text-white shadow-sm' : 'bg-white border border-warm-200 text-ink-600 hover:bg-warm-50')}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Feed */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        examplePosts && examplePosts.length > 0 ? (
          <div className="space-y-4">
            <p className="text-sm font-semibold text-ink-500 text-center">
              So könnte dein erster Beitrag aussehen:
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {examplePosts.map((ex, i) => (
                <button
                  key={i}
                  type="button"
                  onClick={() => router.push(buildCreateUrl({ type: ex.type, category: ex.category, title: ex.title }))}
                  className="relative text-left rounded-2xl border border-dashed border-primary-300 bg-primary-50/50 p-4 opacity-70 hover:opacity-100 hover:border-primary-500 hover:bg-primary-50 transition-all cursor-pointer"
                >
                  <span className="absolute top-2 right-2 bg-violet-100 text-violet-700 text-xs rounded-full px-2 py-0.5">
                    ✨ Beispiel
                  </span>
                  <div className="flex items-start gap-3 pr-16">
                    <span className="text-2xl flex-shrink-0">{ex.emoji}</span>
                    <div className="min-w-0">
                      <p className="font-semibold text-ink-800 text-sm leading-snug">{ex.title}</p>
                      <p className="text-xs text-ink-500 mt-1 line-clamp-2">{ex.description}</p>
                    </div>
                  </div>
                </button>
              ))}
            </div>
            <div className="flex justify-center gap-3 flex-wrap pt-2">
              <Link href={createUrl} className="btn-primary">
                <Plus className="w-4 h-4" />
                Jetzt erstellen
              </Link>
              {activeTab !== 'alle' && (
                <button onClick={() => setActiveTab('alle')} className="btn-secondary">
                  Alle Beiträge anzeigen
                </button>
              )}
            </div>
          </div>
        ) : (
          <div className="text-center py-16 bg-white rounded-2xl border border-warm-200 shadow-sm">
            <div className="text-5xl mb-4">🌿</div>
            <p className="font-bold text-ink-800 text-lg mb-1">{emptyText ?? 'Noch keine Beiträge'}</p>
            <p className="text-sm text-ink-500 mb-5">
              {activeTab === 'suche' ? 'Noch niemand sucht Hilfe in diesem Bereich.'
               : activeTab === 'biete' ? 'Noch niemand bietet Hilfe an – sei der Erste!'
               : 'Sei der Erste – erstelle jetzt einen Beitrag!'}
            </p>
            <div className="flex justify-center gap-3 flex-wrap">
              <Link href={createUrl} className="btn-primary">
                <Plus className="w-4 h-4" />
                {activeTab === 'suche' ? 'Hilfe suchen' : activeTab === 'biete' ? 'Hilfe anbieten' : 'Jetzt erstellen'}
              </Link>
              {activeTab !== 'alle' && (
                <button onClick={() => setActiveTab('alle')} className="btn-secondary">
                  Alle Beiträge anzeigen
                </button>
              )}
            </div>
          </div>
        )
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map(post => (
            <PostCard
              key={post.id}
              post={post}
              currentUserId={currentUserId}
              savedIds={savedIds}
              onSaveToggle={(id, s) => setSavedIds(prev => s ? [...prev, id] : prev.filter(x => x !== id))}
            />
          ))}
        </div>
      )}

    </div>
  )
}

