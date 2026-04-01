'use client'

import { useState, useEffect, useCallback } from 'react'
import { Plus, Search, Filter, X, Users, HandHeart, HelpingHand, ArrowRight } from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { cn } from '@/lib/utils'

interface ModulePageProps {
  title: string
  description: string
  icon: React.ReactNode
  color: string          // tailwind bg class for header
  postTypes: string[]    // welche post-types hier angezeigt werden
  createTypes: { value: string; label: string }[]
  categories: { value: string; label: string }[]
  emptyText?: string
  children?: React.ReactNode  // optionale extra Widgets oben
}

export default function ModulePage({
  title, description, icon, color,
  postTypes, createTypes, categories,
  emptyText, children,
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

  const seekCount  = posts.filter(p => p.type === 'help_request' || p.type?.includes('request')).length
  const offerCount = posts.filter(p => p.type === 'help_offer'   || p.type?.includes('offer')).length

  const filtered = posts.filter(p => {
    const matchTab =
      activeTab === 'alle'  ? true :
      activeTab === 'suche' ? (p.type === 'help_request' || p.type?.includes('request')) :
                              (p.type === 'help_offer'   || p.type?.includes('offer')  )
    const matchType   = filterType === 'all' || p.type === filterType
    const matchSearch = !searchTerm ||
      p.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.description?.toLowerCase().includes(searchTerm.toLowerCase())
    return matchTab && matchType && matchSearch
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
  onClose, onCreated,
}: {
  createTypes: { value: string; label: string }[]
  categories: { value: string; label: string }[]
  currentUserId?: string
  onClose: () => void
  onCreated: () => void
}) {
  const [form, setForm] = useState({
    type: createTypes[0]?.value ?? 'help_request',
    category: categories[0]?.value ?? 'general',
    title: '',
    description: '',
    location_text: '',
    contact_phone: '',
    contact_whatsapp: '',
    urgency: 'normal',
  })
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!currentUserId) return
    if (!form.title.trim()) { alert('Bitte Titel eingeben'); return }
    if (!form.contact_phone && !form.contact_whatsapp) {
      alert('Bitte mindestens eine Kontaktmöglichkeit angeben (Telefon oder WhatsApp)')
      return
    }
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('posts').insert({
      user_id: currentUserId,
      type: form.type,
      category: form.category,
      title: form.title.trim(),
      description: form.description.trim(),
      location_text: form.location_text.trim(),
      contact_phone: form.contact_phone.trim(),
      contact_whatsapp: form.contact_whatsapp.trim(),
      urgency: form.urgency,
      status: 'active',
    })
    setLoading(false)
    if (error) { alert('Fehler: ' + error.message); return }
    onCreated()
  }

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }))

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 animate-fade-in">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <h2 className="text-lg font-bold text-gray-900">Neuer Beitrag</h2>
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
                      ? 'bg-primary-600 text-white border-primary-600'
                      : 'bg-white text-gray-700 border-warm-200 hover:border-primary-300')}
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
              {[['normal','Normal'],['medium','Mittel'],['high','Dringend']].map(([v,l]) => (
                <button key={v} type="button"
                  onClick={() => set('urgency', v)}
                  className={cn('flex-1 py-2 rounded-xl text-sm font-medium border transition-all',
                    form.urgency === v
                      ? v === 'high' ? 'bg-red-600 text-white border-red-600'
                        : v === 'medium' ? 'bg-orange-500 text-white border-orange-500'
                        : 'bg-primary-600 text-white border-primary-600'
                      : 'bg-white text-gray-700 border-warm-200 hover:border-primary-300')}
                >{l}</button>
              ))}
            </div>
          </div>

          {/* Titel */}
          <div>
            <label className="label">Titel *</label>
            <input value={form.title} onChange={e => set('title', e.target.value)}
              placeholder="Kurze, klare Beschreibung" required className="input" />
          </div>

          {/* Beschreibung */}
          <div>
            <label className="label">Beschreibung</label>
            <textarea value={form.description} onChange={e => set('description', e.target.value)}
              placeholder="Was genau benötigst du / bietest du an?" rows={3} className="input resize-none" />
          </div>

          {/* Standort */}
          <div>
            <label className="label">Standort / Ort</label>
            <input value={form.location_text} onChange={e => set('location_text', e.target.value)}
              placeholder="z.B. Wien, 1010 oder Graz-Mitte" className="input" />
          </div>

          {/* Kontakt */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Telefon</label>
              <input value={form.contact_phone} onChange={e => set('contact_phone', e.target.value)}
                placeholder="+43 xxx xxx" className="input" />
            </div>
            <div>
              <label className="label">WhatsApp</label>
              <input value={form.contact_whatsapp} onChange={e => set('contact_whatsapp', e.target.value)}
                placeholder="+43 xxx xxx" className="input" />
            </div>
          </div>
          <p className="text-xs text-amber-600 bg-amber-50 px-3 py-2 rounded-lg">
            ⚠️ Mindestens Telefon oder WhatsApp ist Pflicht
          </p>

          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary flex-1">Abbrechen</button>
            <button type="submit" disabled={loading} className="btn-primary flex-1">
              {loading ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> : null}
              Veröffentlichen
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
