'use client'

import { useState, useEffect, useCallback, useRef, isValidElement, cloneElement } from 'react'
import {
  Plus, Search, X, Users, HandHeart, HelpingHand, Eye, EyeOff, Filter,
  AlertTriangle, CheckCircle2, ChevronRight, Tag, Sparkles, MapPin,
  ImagePlus, Locate, LoaderCircle, HelpCircle, ArrowLeft,
} from 'lucide-react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import ModuleFirstVisitIntro from '@/components/shared/ModuleFirstVisitIntro'
import VoiceInputButton from '@/components/shared/VoiceInputButton'
import IntentSuggestionBanner from '@/components/shared/IntentSuggestionBanner'
import type { IntentType } from '@/lib/intent-classifier'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

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
  const router = useRouter()
  const [posts, setPosts] = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [currentUserId, setCurrentUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [createDefaults, setCreateDefaults] = useState<{ type?: string; category?: string; title?: string }>({})
  const [tooltipOpen, setTooltipOpen] = useState(false)
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
      .order('urgency', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(30)

    const { data, error: postsErr } = await q
    if (postsErr) console.error('ModulePage posts query failed:', postsErr.message)
    setPosts(data ?? [])

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
          <button
            onClick={() => setShowCreate(true)}
            className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors flex-shrink-0"
          >
            <Plus className="w-4 h-4" />
            <span>Beitrag erstellen</span>
          </button>
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
            onClick={() => setActiveTab(tab.key)}
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
              onClick={() => setFilterType('all')}
              className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all',
                filterType === 'all' ? 'bg-primary-600 text-white shadow-sm' : 'bg-white border border-warm-200 text-ink-600 hover:bg-warm-50')}
            >
              Alle
            </button>
            {createTypes.map(t => (
              <button
                key={t.value}
                onClick={() => setFilterType(t.value)}
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
                  onClick={() => { setCreateDefaults({ type: ex.type, category: ex.category, title: ex.title }); setShowCreate(true) }}
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
              <button onClick={() => { setCreateDefaults({}); setShowCreate(true) }} className="btn-primary">
                <Plus className="w-4 h-4" />
                Jetzt erstellen
              </button>
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
              <button onClick={() => setShowCreate(true)} className="btn-primary">
                <Plus className="w-4 h-4" />
                {activeTab === 'suche' ? 'Hilfe suchen' : activeTab === 'biete' ? 'Hilfe anbieten' : 'Jetzt erstellen'}
              </button>
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

      {/* Create Modal */}
      {showCreate && (
        <CreatePostModal
          createTypes={createTypes}
          categories={categories}
          currentUserId={currentUserId}
          allowAnonymous={allowAnonymous}
          initialValues={createDefaults}
          onClose={() => { setShowCreate(false); setCreateDefaults({}) }}
          onCreated={() => { setShowCreate(false); setCreateDefaults({}); loadData() }}
        />
      )}
    </div>
  )
}

// ── Inline Create Modal ──────────────────────────────────────────────
function CreatePostModal({
  createTypes, categories, currentUserId,
  allowAnonymous = true,
  initialValues = {},
  onClose, onCreated,
}: {
  createTypes: { value: string; label: string }[]
  categories: { value: string; label: string }[]
  currentUserId?: string
  allowAnonymous?: boolean
  initialValues?: { type?: string; category?: string; title?: string }
  onClose: () => void
  onCreated: () => void
}) {
  const [form, setForm] = useState({
    type: initialValues.type ?? createTypes[0]?.value ?? 'rescue',
    category: initialValues.category ?? categories[0]?.value ?? 'general',
    title: initialValues.title ?? '',
    description: '',
    location: '',
    contact_phone: '',
    contact_whatsapp: '',
    urgency: 'low',
    is_anonymous: false,
  })
  const [tags, setTags] = useState<string[]>([])
  const [tagInput, setTagInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)

  // ── Geo / Image / Rate-Limit state ──
  const [userLat, setUserLat] = useState<number | null>(null)
  const [userLng, setUserLng] = useState<number | null>(null)
  const [gettingLocation, setGettingLocation] = useState(false)
  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const TITLE_SUGGESTIONS: Record<string, string[]> = {
    help_request: ['Brauche Hilfe beim Einkaufen', 'Suche Unterstützung bei …', 'Benötige dringend Hilfe mit …'],
    help_offered: ['Biete Hilfe beim Einkaufen an', 'Kann beim Umzug helfen', 'Bin verfügbar für …'],
    rescue:       ['Rette Lebensmittel – bitte abholen', 'Überschuss kostenlos', 'Reste zu vergeben'],
    animal:       ['Katze entlaufen', 'Biete Tierbetreuung an', 'Suche Pflegestelle'],
    housing:      ['Biete Zimmer an', 'Suche Unterkunft', 'Notunterkunft verfügbar'],
    supply:       ['Gemüse vom Garten', 'Suche regionale Produkte', 'Biete Selbstgeerntetes an'],
    skill:        ['Gebe Unterricht in …', 'Helfe bei Computerproblemen', 'Biete Handwerker-Hilfe an'],
    mobility:     ['Fahre nach … – Mitfahrer willkommen', 'Suche Mitfahrt nach …', 'Biete Fahrten an'],
    sharing:      ['Verleihe Werkzeug', 'Tausche Bücher', 'Gebe Kindersachen weiter'],
    community:    ['Idee für Gemeinschaftsprojekt', 'Abstimmung: …', 'Einladung zum Treffen'],
    crisis:       ['DRINGEND: Sofortige Hilfe gesucht', 'Notfall – bitte melden', 'Medizinische Hilfe benötigt'],
    knowledge:    ['Anleitung: …', 'Tipps für …', 'Guide: …'],
    mental:       ['Suche jemanden zum Reden', 'Biete Begleitung an', 'Möchte Erfahrungen teilen'],
  }

  const set = (k: string, v: string | boolean) => setForm(f => ({ ...f, [k]: v }))

  const addTag = () => {
    const t = tagInput.trim().toLowerCase()
    if (t && !tags.includes(t) && tags.length < 5) { setTags(prev => [...prev, t]); setTagInput('') }
  }

  // Auto-load profile coords on mount as baseline fallback
  useEffect(() => {
    if (!currentUserId) return
    const supabase = createClient()
    supabase.from('profiles').select('latitude, longitude').eq('id', currentUserId).maybeSingle()
      .then(({ data }) => {
        if (data?.latitude && data?.longitude && userLat === null) {
          setUserLat(data.latitude as number)
          setUserLng(data.longitude as number)
        }
      })
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUserId])

  const handleGetLocation = () => {
    if (!navigator.geolocation) return
    setGettingLocation(true)
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        setUserLat(pos.coords.latitude)
        setUserLng(pos.coords.longitude)
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`)
          const data = await res.json()
          if (data.display_name && !form.location) {
            const parts = data.display_name.split(',')
            set('location', parts.slice(0, 3).join(',').trim())
          }
        } catch { /* ignore geocoding errors */ }
        setGettingLocation(false)
      },
      async () => {
        // Geolocation denied — try profile coords as fallback
        if (currentUserId && userLat === null) {
          const supabase = createClient()
          const { data } = await supabase.from('profiles').select('latitude, longitude').eq('id', currentUserId).maybeSingle()
          if (data?.latitude && data?.longitude) {
            setUserLat(data.latitude as number)
            setUserLng(data.longitude as number)
          }
        }
        setGettingLocation(false)
      },
      { timeout: 10000 },
    )
  }

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !currentUserId) return
    if (file.size > 10 * 1024 * 1024) { toast.error('Bild zu groß (max. 10 MB)'); return }
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      toast.error('Nur JPEG, PNG, WebP oder GIF erlaubt'); return
    }
    const reader = new FileReader()
    reader.onload = () => setImagePreview(reader.result as string)
    reader.readAsDataURL(file)
    setUploading(true)
    try {
      const supabase = createClient()
      const ext = file.name.split('.').pop() ?? 'jpg'
      const path = `${currentUserId}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`
      const { error: upErr } = await supabase.storage.from('post-images').upload(path, file, { upsert: false })
      if (upErr) { toast.error('Upload fehlgeschlagen'); setImagePreview(null); setUploading(false); return }
      const { data: urlData } = supabase.storage.from('post-images').getPublicUrl(path)
      setImageUrl(urlData.publicUrl)
      toast.success('Bild hochgeladen')
    } catch {
      toast.error('Upload fehlgeschlagen')
      setImagePreview(null)
    } finally {
      setUploading(false)
    }
  }

  const validate = () => {
    const e: Record<string, string> = {}
    if (!form.title.trim()) e.title = 'Titel ist Pflichtfeld'
    else if (form.title.trim().length < 5) e.title = 'Mindestens 5 Zeichen'
    if (form.description.length > 2000) e.description = 'Beschreibung darf max. 2000 Zeichen haben'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!currentUserId) { toast.error('Nicht eingeloggt'); return }
    if (!acceptedNoTrade) { toast.error('Bitte bestätige, dass kein Handel oder Geldgeschäft stattfindet.'); return }
    if (!validate()) return
    setLoading(true)

    // Rate-Limiting
    const allowed = await checkRateLimit(currentUserId, 'create_post', 2, 10)
    if (!allowed) { toast.error('Zu viele Beiträge in kurzer Zeit. Bitte warte etwas.'); setLoading(false); return }

    const supabase = createClient()
    const { error } = await supabase.from('posts').insert({
      user_id: currentUserId,
      type: form.type,
      category: form.category,
      title: form.title.trim(),
      description: form.description.trim() || 'Keine weiteren Details angegeben.',
      location_text: form.location.trim() || null,
      ...(userLat !== null ? { latitude: userLat } : {}),
      ...(userLng !== null ? { longitude: userLng } : {}),
      contact_phone: form.is_anonymous ? null : form.contact_phone.trim() || null,
      contact_whatsapp: form.is_anonymous ? null : form.contact_whatsapp.trim() || null,
      urgency: form.urgency,
      is_anonymous: form.is_anonymous,
      ...(tags.length > 0 ? { tags } : {}),
      ...(imageUrl ? { media_urls: [imageUrl] } : {}),
      status: 'active',
    })
    setLoading(false)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Beitrag veröffentlicht! 🌿')
    onCreated()
  }

  const suggestions = TITLE_SUGGESTIONS[form.type] ?? []

  // Close on Escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [onClose])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[92vh] overflow-y-auto animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between p-5 border-b border-warm-100 sticky top-0 bg-white/95 backdrop-blur-sm rounded-t-2xl z-10">
          <h2 className="text-lg font-bold text-ink-900 flex items-center gap-2">
            <Plus className="w-5 h-5 text-primary-600" /> Neuer Beitrag
          </h2>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-warm-100 text-ink-500">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          {/* Intent suggestion (shows when user types content that doesn't match the current type) */}
          <IntentSuggestionBanner
            title={form.title}
            description={form.description}
            currentType={form.type}
            navigateOnAccept
            onAccept={(intent: IntentType) => {
              // If the intent maps to a type the current form supports, just switch
              const supported = createTypes.find(t => t.value === intent)
              if (supported) set('type', supported.value)
            }}
          />

          {/* Typ */}
          <div>
            <label className="label">Art des Beitrags *</label>
            <div className="grid grid-cols-2 gap-2">
              {createTypes.map(t => (
                <button key={t.value} type="button"
                  onClick={() => set('type', t.value)}
                  className={cn('px-3 py-2 rounded-xl text-sm font-medium border transition-all text-left',
                    form.type === t.value
                      ? 'bg-primary-50 border-primary-400 ring-1 ring-primary-300 text-primary-800'
                      : 'bg-white text-ink-700 border-warm-200 hover:border-primary-200')}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          {/* Kategorie */}
          <div>
            <label className="label">Kategorie *</label>
            <select value={form.category} onChange={e => set('category', e.target.value)} className="input">
              {categories.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>

          {/* Dringlichkeit */}
          <div>
            <label className="label">Dringlichkeit</label>
            <div className="flex gap-2">
              {[
                { v: 'low', l: '🟦 Normal', a: 'bg-primary-600 text-white border-primary-600' },
                { v: 'medium', l: '🟧 Mittel', a: 'bg-orange-500 text-white border-orange-500' },
                { v: 'high',   l: '🔴 Dringend', a: 'bg-red-600 text-white border-red-600' },
              ].map(({ v, l, a }) => (
                <button key={v} type="button" onClick={() => set('urgency', v)}
                  className={cn('flex-1 py-2 rounded-xl text-xs font-semibold border transition-all',
                    form.urgency === v ? a : 'bg-white text-ink-700 border-warm-200 hover:border-primary-200')}>
                  {l}
                </button>
              ))}
            </div>
          </div>

          {/* Titel mit Vorschlägen */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="label flex items-center gap-2">
                Titel *
                <VoiceInputButton
                  label="Titel"
                  onResult={t => set('title', form.title ? `${form.title} ${t}` : t)}
                />
              </label>
              {suggestions.length > 0 && (
                <button type="button" onClick={() => setShowSuggestions(s => !s)}
                  className="flex items-center gap-1 text-xs text-violet-600 hover:text-violet-700 font-medium">
                  <Sparkles className="w-3 h-3" /> Vorschläge
                </button>
              )}
            </div>
            {showSuggestions && (
              <div className="mb-2 p-2 bg-violet-50 border border-violet-200 rounded-xl space-y-1">
                {suggestions.map(s => (
                  <button key={s} type="button"
                    onClick={() => { set('title', s); setShowSuggestions(false) }}
                    className="block w-full text-left text-xs text-violet-800 hover:bg-violet-100 px-2 py-1 rounded-lg transition-colors">
                    {s}
                  </button>
                ))}
              </div>
            )}
            <input value={form.title} onChange={e => { set('title', e.target.value); setErrors(er => ({ ...er, title: '' })) }}
              placeholder="Kurze, klare Beschreibung" maxLength={80}
              className={cn('input', errors.title && 'border-red-400')} />
            <div className="flex justify-between mt-1">
              {errors.title ? <p className="text-xs text-red-500">{errors.title}</p> : <span />}
              <p className="text-xs text-ink-400">{form.title.length}/80</p>
            </div>
          </div>

          {/* Beschreibung */}
          <div>
            <label className="label flex items-center gap-2">
              Beschreibung
              <VoiceInputButton
                label="Beschreibung"
                onResult={t => set('description', form.description ? `${form.description} ${t}` : t)}
              />
              <span className="font-normal text-ink-400 text-xs">optional</span>
            </label>
            <textarea value={form.description} onChange={e => set('description', e.target.value)}
              placeholder="Was genau benötigst du / bietest du an?" rows={3} maxLength={2000}
              className={cn('input resize-none', errors.description && 'border-red-400')} />
            <div className="flex justify-between mt-1">
              {errors.description ? <p className="text-xs text-red-500">{errors.description}</p> : <span />}
              <p className="text-xs text-ink-400">{form.description.length}/2000</p>
            </div>
          </div>

          {/* Standort mit Geo-Button */}
          <div>
            <label className="label flex items-center gap-1.5">
              <MapPin className="w-4 h-4 text-ink-400" /> Standort
              <span className="font-normal text-ink-400 text-xs">optional</span>
            </label>
            <input value={form.location} onChange={e => set('location', e.target.value)}
              placeholder="z.B. Wien, 1010 oder Graz-Mitte" className="input" />
            <div className="flex items-center gap-2 mt-2">
              <button type="button" onClick={handleGetLocation} disabled={gettingLocation}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border border-primary-300 bg-primary-50 text-primary-700 rounded-xl hover:bg-primary-100 transition-all">
                {gettingLocation
                  ? <span className="w-3.5 h-3.5 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
                  : <Locate className="w-3.5 h-3.5" />}
                Meinen Standort verwenden
              </button>
              {userLat !== null && (
                <span className="text-xs text-green-600 flex items-center gap-1">
                  <MapPin className="w-3 h-3" /> Koordinaten gesetzt
                </span>
              )}
            </div>
          </div>

          {/* Bild-Upload */}
          <div>
            <label className="label flex items-center gap-1.5">
              <ImagePlus className="w-4 h-4 text-ink-400" /> Bild
              <span className="font-normal text-ink-400 text-xs">optional – max. 10 MB</span>
            </label>
            <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={handleImageUpload} className="hidden" />
            {imagePreview ? (
              <div className="relative inline-block mt-2">
                <img src={imagePreview} alt="Vorschau" className="h-20 w-20 object-cover rounded-xl border border-warm-200" />
                {uploading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-xl">
                    <LoaderCircle className="w-5 h-5 text-white animate-spin" />
                  </div>
                )}
                <button type="button" onClick={() => { setImageUrl(null); setImagePreview(null); if (fileRef.current) fileRef.current.value = '' }}
                  className="absolute -top-2 -right-2 bg-white rounded-full p-0.5 shadow border border-warm-200">
                  <X className="w-3.5 h-3.5 text-ink-500" />
                </button>
              </div>
            ) : (
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-3 py-2 text-sm text-ink-600 border border-dashed border-warm-300 rounded-xl hover:bg-warm-50 transition mt-2">
                <ImagePlus className="w-4 h-4" /> Bild hinzufügen
              </button>
            )}
          </div>

          {/* Tags */}
          <div>
            <label className="label flex items-center gap-1.5">
              <Tag className="w-3.5 h-3.5 text-ink-400" /> Tags <span className="font-normal text-ink-400 text-xs">max. 5</span>
            </label>
            <div className="flex gap-2">
              <input value={tagInput}
                onChange={e => setTagInput(e.target.value.replace(/[^a-zA-ZäöüÄÖÜß0-9-]/g, ''))}
                onKeyDown={e => { if ((e.key === 'Enter' || e.key === ',') && tagInput.trim()) { e.preventDefault(); addTag() } }}
                placeholder="Tag + Enter" className="input flex-1 text-sm" maxLength={20} disabled={tags.length >= 5} />
              <button type="button" onClick={addTag} disabled={!tagInput.trim() || tags.length >= 5}
                className="px-3 py-2 bg-violet-600 text-white text-sm rounded-xl hover:bg-violet-700 disabled:opacity-40 transition-all">+</button>
            </div>
            {tags.length > 0 && (
              <div className="flex flex-wrap gap-1.5 mt-2">
                {tags.map(tag => (
                  <span key={tag} className="flex items-center gap-1 bg-violet-100 text-violet-700 px-2 py-0.5 rounded-full text-xs font-medium">
                    #{tag}
                    <button type="button" onClick={() => setTags(t => t.filter(x => x !== tag))}><X className="w-3 h-3" /></button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Kontakt */}
          {!form.is_anonymous && (
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="label text-xs">Telefon</label>
                  <input value={form.contact_phone} onChange={e => { set('contact_phone', e.target.value); setErrors(er => ({ ...er, contact: '' })) }}
                    placeholder="+43 xxx xxx" className={cn('input', errors.contact && 'border-red-400')} />
                </div>
                <div>
                  <label className="label text-xs">WhatsApp</label>
                  <input value={form.contact_whatsapp} onChange={e => { set('contact_whatsapp', e.target.value); setErrors(er => ({ ...er, contact: '' })) }}
                    placeholder="+43 xxx xxx" className={cn('input', errors.contact && 'border-red-400')} />
                </div>
              </div>
              {errors.contact && (
                <p className="text-xs text-red-500 flex items-center gap-1">
                  <AlertTriangle className="w-3.5 h-3.5" /> {errors.contact}
                </p>
              )}
            </div>
          )}

          {/* Anonym */}
          {allowAnonymous && (
            <div onClick={() => { set('is_anonymous', !form.is_anonymous); setErrors(er => ({ ...er, contact: '' })) }}
              className={cn('flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-all select-none',
                form.is_anonymous ? 'bg-cyan-50 border-cyan-300' : 'bg-white border-warm-200 hover:border-cyan-200')}>
              {form.is_anonymous
                ? <EyeOff className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
                : <Eye className="w-5 h-5 text-ink-400 flex-shrink-0 mt-0.5" />}
              <div className="flex-1">
                <p className="text-sm font-semibold text-ink-900">Anonym posten</p>
                <p className="text-xs text-ink-500 mt-0.5">
                  {form.is_anonymous ? 'Anonym aktiv – kein Kontakt nötig' : 'Name & Kontakt werden angezeigt'}
                </p>
              </div>
              <div className={cn('w-5 h-5 rounded border flex items-center justify-center flex-shrink-0',
                form.is_anonymous ? 'bg-cyan-500 border-cyan-500' : 'border-stone-300')}>
                {form.is_anonymous && <span className="text-white text-xs font-bold">✓</span>}
              </div>
            </div>
          )}

          {/* Kein-Handel-Bestätigung */}
          <button
            type="button"
            onClick={() => setAcceptedNoTrade(v => !v)}
            className="flex items-start gap-3 w-full text-left group"
          >
            <div className={cn(
              'w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 mt-0.5 transition-all',
              acceptedNoTrade ? 'bg-primary-500 border-primary-500' : 'border-amber-400 bg-white'
            )}>
              {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
            </div>
            <div>
              <p className="text-sm font-semibold text-ink-900">Kein Handel / kein Geldgeschäft *</p>
              <p className="text-xs text-ink-500 mt-0.5">
                Ich bestätige, dass dieser Beitrag <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
                <a href="/nutzungsbedingungen" target="_blank" rel="noopener noreferrer" className="text-primary-600 hover:underline ml-1">Siehe AGB §4</a>
              </p>
            </div>
          </button>

          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary flex-1">Abbrechen</button>
            <button type="submit" disabled={loading || uploading || !acceptedNoTrade} className="btn-primary flex-1 flex items-center justify-center gap-2">
              {loading
                ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                : <><CheckCircle2 className="w-4 h-4" /> Veröffentlichen</>
              }
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
