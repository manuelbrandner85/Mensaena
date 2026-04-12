'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Plus, Search, X, Users, HandHeart, HelpingHand, Eye, EyeOff, Filter,
  AlertTriangle, CheckCircle2, ChevronRight, Tag, Sparkles, MapPin,
  ImagePlus, Locate, LoaderCircle,
} from 'lucide-react'
import { useRef } from 'react'
import Link from 'next/link'
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
}

export default function ModulePage({
  title, description, icon, color,
  postTypes, moduleFilter, createTypes, categories,
  emptyText, allowAnonymous = false, filterCategory, children,
}: ModulePageProps) {
  const [posts, setPosts] = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [currentUserId, setCurrentUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterType, setFilterType] = useState<string>('all')
  const [activeTab, setActiveTab] = useState<'alle' | 'suche' | 'biete'>('alle')

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setCurrentUserId(user.id)

    let q = supabase
      .from('posts')
      .select('*, profiles(name, avatar_url)')
      .in('type', postTypes)
      .eq('status', 'active')
      .order('urgency', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(30)

    const { data } = await q
    setPosts(data ?? [])

    if (user) {
      const { data: saved } = await supabase
        .from('saved_posts').select('post_id').eq('user_id', user.id)
      setSavedIds((saved ?? []).map((s: { post_id: string }) => s.post_id))
    }
    setLoading(false)
  }, [postTypes])

  useEffect(() => { loadData() }, [loadData])

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
    <div className="max-w-5xl space-y-6">
      {/* Header */}
      <div className={cn('rounded-2xl p-6 text-white', color)}>
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center flex-shrink-0">
              {icon}
            </div>
            <div>
              <h1 className="text-2xl font-bold">{title}</h1>
              <p className="text-white/80 text-sm mt-0.5">{description}</p>
            </div>
          </div>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-xl text-sm font-semibold transition-all backdrop-blur-sm flex-shrink-0"
          >
            <Plus className="w-4 h-4" />
            Beitrag erstellen
          </button>
        </div>

        {/* Live-Zähler: Suche / Biete */}
        {!loading && posts.length > 0 && (
          <div className="flex gap-3 mt-4">
            <div className="flex items-center gap-2 bg-white/10 rounded-xl px-3 py-2 text-sm">
              <HelpingHand className="w-4 h-4" />
              <span className="font-semibold">{seekCount}</span>
              <span className="text-white/70">suchen Hilfe</span>
            </div>
            <div className="flex items-center gap-2 bg-white/10 rounded-xl px-3 py-2 text-sm">
              <HandHeart className="w-4 h-4" />
              <span className="font-semibold">{offerCount}</span>
              <span className="text-white/70">bieten Hilfe</span>
            </div>
            <div className="flex items-center gap-2 bg-white/10 rounded-xl px-3 py-2 text-sm">
              <Users className="w-4 h-4" />
              <span className="font-semibold">{posts.length}</span>
              <span className="text-white/70">gesamt</span>
            </div>
          </div>
        )}
      </div>

      {/* Optionale Extra-Widgets */}
      {children}

      {/* Tabs: Alle / Suche Hilfe / Biete Hilfe */}
      <div className="flex gap-1 bg-warm-100 p-1 rounded-xl">
        {([
          { key: 'alle',  label: '🔍 Alle Beiträge' },
          { key: 'suche', label: '🔴 Hilfe gesucht' },
          { key: 'biete', label: '🟢 Hilfe angeboten' },
        ] as { key: 'alle'|'suche'|'biete'; label: string }[]).map(tab => (
          <button key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={cn('flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all',
              activeTab === tab.key
                ? 'bg-white shadow-sm text-gray-900'
                : 'text-gray-500 hover:text-gray-700')}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* Suche + Filter */}
      <div className="flex gap-3 flex-wrap">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            placeholder="Suchen…"
            className="input pl-9 py-2 text-sm w-full"
          />
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Filter className="w-4 h-4 text-gray-400" />
          <button
            onClick={() => setFilterType('all')}
            className={cn('px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
              filterType === 'all' ? 'bg-primary-600 text-white' : 'bg-white border border-warm-200 text-gray-600 hover:bg-warm-50')}
          >
            Alle
          </button>
          {createTypes.map(t => (
            <button
              key={t.value}
              onClick={() => setFilterType(t.value)}
              className={cn('px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                filterType === t.value ? 'bg-primary-600 text-white' : 'bg-white border border-warm-200 text-gray-600 hover:bg-warm-50')}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* Feed */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-warm-200">
          <div className="text-4xl mb-3">🌿</div>
          <p className="font-semibold text-gray-700 mb-1">{emptyText ?? 'Noch keine Beiträge'}</p>
          <p className="text-sm text-gray-500 mb-4">
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
          onClose={() => setShowCreate(false)}
          onCreated={() => { setShowCreate(false); loadData() }}
        />
      )}
    </div>
  )
}

// ── Inline Create Modal ──────────────────────────────────────────────
function CreatePostModal({
  createTypes, categories, currentUserId,
  allowAnonymous = false,
  onClose, onCreated,
}: {
  createTypes: { value: string; label: string }[]
  categories: { value: string; label: string }[]
  currentUserId?: string
  allowAnonymous?: boolean
  onClose: () => void
  onCreated: () => void
}) {
  const [form, setForm] = useState({
    type: createTypes[0]?.value ?? 'rescue',
    category: categories[0]?.value ?? 'general',
    title: '',
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
    help_offer:   ['Biete Hilfe beim Einkaufen an', 'Kann beim Umzug helfen', 'Bin verfügbar für …'],
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
      () => setGettingLocation(false),
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
    if (!form.is_anonymous && !form.contact_phone && !form.contact_whatsapp) {
      e.contact = 'Telefon oder WhatsApp ist Pflicht (oder anonym posten)'
    }
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

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 animate-fade-in">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[92vh] overflow-y-auto">
        <div className="flex items-center justify-between p-5 border-b border-warm-100 sticky top-0 bg-white rounded-t-2xl z-10">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Plus className="w-5 h-5 text-primary-600" /> Neuer Beitrag
          </h2>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-500">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
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
                      : 'bg-white text-gray-700 border-warm-200 hover:border-primary-200')}
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
                    form.urgency === v ? a : 'bg-white text-gray-700 border-warm-200 hover:border-primary-200')}>
                  {l}
                </button>
              ))}
            </div>
          </div>

          {/* Titel mit Vorschlägen */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="label">Titel *</label>
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
              <p className="text-xs text-gray-400">{form.title.length}/80</p>
            </div>
          </div>

          {/* Beschreibung */}
          <div>
            <label className="label">Beschreibung <span className="font-normal text-gray-400 text-xs">optional</span></label>
            <textarea value={form.description} onChange={e => set('description', e.target.value)}
              placeholder="Was genau benötigst du / bietest du an?" rows={3} className="input resize-none" />
          </div>

          {/* Standort mit Geo-Button */}
          <div>
            <label className="label flex items-center gap-1.5">
              <MapPin className="w-4 h-4 text-gray-400" /> Standort
              <span className="font-normal text-gray-400 text-xs">optional</span>
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
              <ImagePlus className="w-4 h-4 text-gray-400" /> Bild
              <span className="font-normal text-gray-400 text-xs">optional – max. 10 MB</span>
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
                  <X className="w-3.5 h-3.5 text-gray-500" />
                </button>
              </div>
            ) : (
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-3 py-2 text-sm text-gray-600 border border-dashed border-warm-300 rounded-xl hover:bg-warm-50 transition mt-2">
                <ImagePlus className="w-4 h-4" /> Bild hinzufügen
              </button>
            )}
          </div>

          {/* Tags */}
          <div>
            <label className="label flex items-center gap-1.5">
              <Tag className="w-3.5 h-3.5 text-gray-400" /> Tags <span className="font-normal text-gray-400 text-xs">max. 5</span>
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
                : <Eye className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />}
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">Anonym posten</p>
                <p className="text-xs text-gray-500 mt-0.5">
                  {form.is_anonymous ? 'Anonym aktiv – kein Kontakt nötig' : 'Name & Kontakt werden angezeigt'}
                </p>
              </div>
              <div className={cn('w-5 h-5 rounded border flex items-center justify-center flex-shrink-0',
                form.is_anonymous ? 'bg-cyan-500 border-cyan-500' : 'border-gray-300')}>
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
              acceptedNoTrade ? 'bg-emerald-500 border-emerald-500' : 'border-amber-400 bg-white'
            )}>
              {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
            </div>
            <div>
              <p className="text-sm font-semibold text-gray-900">Kein Handel / kein Geldgeschäft *</p>
              <p className="text-xs text-gray-500 mt-0.5">
                Ich bestätige, dass dieser Beitrag <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
                <a href="/nutzungsbedingungen" target="_blank" className="text-primary-600 hover:underline ml-1">Siehe AGB §4</a>
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
