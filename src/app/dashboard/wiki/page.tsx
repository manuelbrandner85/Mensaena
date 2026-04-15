'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  BookOpen, Plus, Search, X, FileText, Tag, Eye, Edit3,
  Clock, User, ThumbsUp, Loader2, ChevronRight, Star,
  Hash, Filter,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ──────────────────────────────────────────────────────
interface Article {
  id: string
  title: string
  content: string
  category: string
  tags: string[]
  status: string
  author_id: string
  created_at: string
  updated_at: string
}

// ── Config ─────────────────────────────────────────────────────
const WIKI_CATEGORIES = [
  { value: 'everyday', label: '📖 Alltag & Ratgeber' },
  { value: 'skills', label: '🔧 Handwerk & Anleitung' },
  { value: 'knowledge', label: '🧠 Wissen & Bildung' },
  { value: 'housing', label: '⚖️ Wohnen & Recht' },
  { value: 'mental', label: '💚 Gesundheit & Wohlbefinden' },
  { value: 'emergency', label: '🚨 Notfall-Tipps' },
  { value: 'sharing', label: '🌱 Nachhaltigkeit & Teilen' },
  { value: 'food', label: '🍽️ Ernährung & Kochen' },
  { value: 'mobility', label: '🚲 Mobilität & Unterwegs' },
  { value: 'animals', label: '🐾 Tiere & Natur' },
  { value: 'moving', label: '📦 Umzug & Neuanfang' },
  { value: 'general', label: '💻 Digital & Sonstiges' },
]

const catEmoji: Record<string, string> = {
  everyday: '📖', skills: '🔧', knowledge: '🧠', housing: '⚖️',
  mental: '💚', emergency: '🚨', sharing: '🌱', food: '🍽️',
  mobility: '🚲', animals: '🐾', moving: '📦', general: '💻',
}

// ── Article Editor Modal ────────────────────────────────────────
function ArticleEditor({ article, onClose, onSaved }: { article?: Article; onClose: () => void; onSaved: () => void }) {
  const [title, setTitle] = useState(article?.title ?? '')
  const [content, setContent] = useState(article?.content ?? '')
  const [category, setCategory] = useState(article?.category ?? 'everyday')
  const [tagsInput, setTagsInput] = useState((article?.tags ?? []).join(', '))
  const [saving, setSaving] = useState(false)

  // Close on Escape
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const handleSave = async () => {
    if (title.trim().length < 5) { toast.error('Titel mindestens 5 Zeichen'); return }
    if (content.trim().length < 20) { toast.error('Inhalt mindestens 20 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      // Rate-Limiting
      const allowed = await checkRateLimit(user.id, 'create_article', 3, 60)
      if (!allowed) { toast.error('Zu viele Artikel in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const tags = tagsInput.split(',').map(t => t.trim().toLowerCase()).filter(Boolean)

      if (article) {
        const { error } = await supabase.from('knowledge_articles').update({
          title: title.trim(), content: content.trim(), category, tags, updated_at: new Date().toISOString()
        }).eq('id', article.id)
        if (error) throw error
        toast.success('Artikel aktualisiert!')
      } else {
        const { error } = await supabase.from('knowledge_articles').insert({
          title: title.trim(), content: content.trim(), category, tags, author_id: user.id, status: 'published',
        })
        if (error) throw error
        toast.success('Artikel erstellt!')
      }
      onSaved()
      onClose()
    } catch (err: any) {
      toast.error('Fehler: ' + (err?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <BookOpen className="w-5 h-5 text-blue-600" /> {article ? 'Artikel bearbeiten' : 'Neuer Artikel'}
          </h2>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-xl transition-colors"><X className="w-5 h-5 text-gray-400" /></button>
        </div>

        <div className="space-y-4">
          {/* Rate-Limit Hinweis */}
          {!article && (
            <div className="flex items-center gap-2 bg-blue-50 border border-blue-200 rounded-xl px-3 py-2">
              <Clock className="w-4 h-4 text-blue-500 flex-shrink-0" />
              <p className="text-xs text-blue-700">Max. <strong>3 Artikel pro Stunde</strong> – neue Artikel erscheinen sofort.</p>
            </div>
          )}
          <div>
            <label className="label">Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={120}
              className="input" placeholder="z.B. Wie beantrage ich Wohngeld?" />
            {title.trim().length > 0 && title.trim().length < 5 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 5 Zeichen nötig ({title.trim().length}/5)</p>
            )}
          </div>
          <div>
            <label className="label">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {WIKI_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Inhalt * <span className="font-normal text-gray-400">(Markdown: **fett**, # Überschrift, - Liste)</span></label>
            <textarea value={content} onChange={e => setContent(e.target.value)} rows={12}
              className="input resize-none font-mono text-sm"
              placeholder={'# Überschrift\n\nSchreibe hier deinen Artikel...\n\n- Punkt 1\n- Punkt 2\n\n**Wichtig:** ...'} />
            {content.trim().length > 0 && content.trim().length < 20 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 20 Zeichen nötig ({content.trim().length}/20)</p>
            )}
          </div>
          <div>
            <label className="label">Tags <span className="font-normal text-gray-400">(kommagetrennt)</span></label>
            <input value={tagsInput} onChange={e => setTagsInput(e.target.value)}
              className="input" placeholder="z.B. wohngeld, soziales, antrag" />
          </div>

          <button onClick={handleSave} disabled={saving || title.trim().length < 5 || content.trim().length < 20}
            className="w-full py-3 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-xl font-semibold hover:shadow-lg disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-95">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileText className="w-4 h-4" />}
            {article ? 'Speichern' : 'Veröffentlichen'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Inline Markdown (bold, italic, code) ───────────────────────
function renderInline(text: string): React.ReactNode {
  const parts = text.split(/(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/g)
  return parts.map((part, i) => {
    if (/^\*\*[^*]+\*\*$/.test(part)) return <strong key={i}>{part.slice(2, -2)}</strong>
    if (/^\*[^*]+\*$/.test(part))     return <em key={i}>{part.slice(1, -1)}</em>
    if (/^`[^`]+`$/.test(part))       return <code key={i} className="bg-gray-100 px-1 rounded text-xs font-mono">{part.slice(1, -1)}</code>
    return part
  })
}

// ── Article Detail View ─────────────────────────────────────────
function ArticleDetail({ article, onClose, onEdit, userId }: {
  article: Article; onClose: () => void; onEdit: () => void; userId?: string
}) {
  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <span className="text-lg">{catEmoji[article.category] || '📋'}</span>
            <span className="text-xs bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full capitalize">{article.category}</span>
          </div>
          <div className="flex items-center gap-2">
            {userId === article.author_id && (
              <button onClick={onEdit} className="p-1.5 hover:bg-blue-50 rounded-lg text-blue-600"><Edit3 className="w-4 h-4" /></button>
            )}
            <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5" /></button>
          </div>
        </div>

        <h1 className="text-xl font-bold text-gray-900 mb-2">{article.title}</h1>

        <div className="flex items-center gap-3 text-xs text-gray-400 mb-4">
          <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {new Date(article.created_at).toLocaleDateString('de-DE')}</span>
          {article.updated_at !== article.created_at && (
            <span className="flex items-center gap-1"><Edit3 className="w-3 h-3" /> Aktualisiert: {new Date(article.updated_at).toLocaleDateString('de-DE')}</span>
          )}
        </div>

        {/* Markdown rendering */}
        <div className="prose prose-sm max-w-none text-gray-700 leading-relaxed space-y-2">
          {article.content.split('\n').map((line, i) => {
            if (/^#{3}\s/.test(line)) return <h3 key={i} className="text-base font-bold text-gray-900 mt-4 mb-1">{line.replace(/^###\s/, '')}</h3>
            if (/^##\s/.test(line))  return <h2 key={i} className="text-lg font-bold text-gray-900 mt-4 mb-1">{line.replace(/^##\s/, '')}</h2>
            if (/^#\s/.test(line))   return <h1 key={i} className="text-xl font-bold text-gray-900 mt-4 mb-2">{line.replace(/^#\s/, '')}</h1>
            if (/^[-*]\s/.test(line))return <li key={i} className="ml-4 list-disc text-sm">{renderInline(line.replace(/^[-*]\s/, ''))}</li>
            if (line.trim() === '')  return <br key={i} />
            return <p key={i} className="text-sm">{renderInline(line)}</p>
          })}
        </div>

        {article.tags?.length > 0 && (
          <div className="flex flex-wrap gap-1.5 mt-4 pt-4 border-t">
            {article.tags.map(t => (
              <span key={t} className="flex items-center gap-0.5 px-2 py-0.5 bg-blue-50 text-blue-600 rounded-full text-xs">
                <Hash className="w-2.5 h-2.5" /> {t}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Article Card ────────────────────────────────────────────────
function ArticleCard({
  article, onClick, voteCount = 0, hasVoted = false, onVote,
}: {
  article: Article
  onClick: () => void
  voteCount?: number
  hasVoted?: boolean
  onVote?: (e: React.MouseEvent) => void
}) {
  return (
    <button onClick={onClick} className="spotlight hover-lift relative bg-white rounded-2xl border border-warm-200 p-4 pt-5 shadow-soft hover:shadow-card transition-all text-left w-full group overflow-hidden">
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #3B82F6, #3B82F633)' }}
      />
      <div className="relative flex items-start gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-400 to-indigo-500 flex items-center justify-center text-white text-sm flex-shrink-0 shadow-soft group-hover:scale-105 transition-transform">
          {catEmoji[article.category] || '📋'}
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-bold text-gray-900 text-sm group-hover:text-blue-600 transition-colors truncate">{article.title}</h3>
          <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{article.content.slice(0, 120)}...</p>
          <div className="flex items-center gap-2 mt-2 flex-wrap">
            <span className="text-xs bg-blue-50 text-blue-600 px-1.5 py-0.5 rounded capitalize">{article.category}</span>
            <span className="text-xs text-gray-400 flex items-center gap-0.5">
              <Clock className="w-3 h-3" /> {new Date(article.created_at).toLocaleDateString('de-DE')}
            </span>
            {voteCount > 0 && (
              <span className="flex items-center gap-0.5 text-[10px] text-blue-500 bg-blue-50 px-1.5 py-0.5 rounded-full font-semibold">
                <ThumbsUp className="w-2.5 h-2.5" /> {voteCount}
              </span>
            )}
          </div>
          {article.tags?.length > 0 && (
            <div className="flex gap-1 mt-1.5">
              {article.tags.slice(0, 3).map(t => (
                <span key={t} className="text-[10px] bg-gray-50 text-gray-400 px-1.5 py-0.5 rounded-full">#{t}</span>
              ))}
              {article.tags.length > 3 && <span className="text-[10px] text-gray-400">+{article.tags.length - 3}</span>}
            </div>
          )}
        </div>
        <div className="flex flex-col items-end gap-2 flex-shrink-0">
          {onVote && (
            <button
              onClick={e => { e.stopPropagation(); onVote(e) }}
              title={hasVoted ? 'Bereits bewertet' : 'Hilfreich'}
              className={cn(
                'flex items-center gap-1 p-1.5 rounded-lg transition-colors text-xs',
                hasVoted ? 'text-blue-600 bg-blue-50' : 'text-gray-300 hover:text-blue-500 hover:bg-blue-50',
              )}
            >
              <ThumbsUp className="w-3.5 h-3.5" />
            </button>
          )}
          <ChevronRight className="w-4 h-4 text-gray-300 group-hover:text-blue-500 transition-colors mt-1" />
        </div>
      </div>
    </button>
  )
}

// ── Main Wiki Page ──────────────────────────────────────────────
export default function WikiPage() {
  const [articles, setArticles] = useState<Article[]>([])
  const [userId, setUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterCat, setFilterCat] = useState('all')
  const [showEditor, setShowEditor] = useState(false)
  const [editArticle, setEditArticle] = useState<Article | undefined>()
  const [viewArticle, setViewArticle] = useState<Article | undefined>()
  const [votes, setVotes] = useState<Record<string, number>>({})
  const [myVotes, setMyVotes] = useState<Set<string>>(new Set())

  useEffect(() => {
    try {
      setVotes(JSON.parse(localStorage.getItem('wiki_votes') ?? '{}'))
      setMyVotes(new Set(JSON.parse(localStorage.getItem('wiki_my_votes') ?? '[]')))
    } catch { /* ignore */ }
  }, [])

  const handleVote = useCallback((articleId: string) => {
    if (myVotes.has(articleId)) { toast('Bereits bewertet.', { icon: 'ℹ️' }); return }
    const newVotes = { ...votes, [articleId]: (votes[articleId] ?? 0) + 1 }
    const newMyVotes = new Set([...myVotes, articleId])
    setVotes(newVotes)
    setMyVotes(newMyVotes)
    try {
      localStorage.setItem('wiki_votes', JSON.stringify(newVotes))
      localStorage.setItem('wiki_my_votes', JSON.stringify([...newMyVotes]))
    } catch { /* ignore */ }
    toast.success('Danke für deine Bewertung!')
  }, [votes, myVotes])

  const loadData = useCallback(async (signal?: { cancelled: boolean }) => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (signal?.cancelled) return
    if (user) setUserId(user.id)
    const { data, error } = await supabase.from('knowledge_articles').select('*')
      .eq('status', 'published')
      .order('created_at', { ascending: false })
    if (signal?.cancelled) return
    if (error) console.error('wiki articles query failed:', error.message)
    setArticles(data ?? [])
    setLoading(false)
  }, [])

  useEffect(() => {
    const signal = { cancelled: false }
    loadData(signal)
    return () => { signal.cancelled = true }
  }, [loadData])

  const filtered = articles.filter(a => {
    if (filterCat !== 'all' && a.category !== filterCat) return false
    if (searchTerm) {
      const q = searchTerm.toLowerCase()
      if (!a.title.toLowerCase().includes(q) && !a.content.toLowerCase().includes(q) &&
          !(a.tags ?? []).some(t => t.includes(q))) return false
    }
    return true
  })

  // Group by category for category counts
  const catCounts = articles.reduce<Record<string, number>>((acc, a) => {
    acc[a.category] = (acc[a.category] ?? 0) + 1
    return acc
  }, {})

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 13 / Wissen</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center flex-shrink-0 float-idle">
              <BookOpen className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <h1 className="page-title">Wissensbasis</h1>
              <p className="page-subtitle mt-2">Ratgeber, Anleitungen und <span className="text-accent">Wissen</span> für die Gemeinschaft.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0 text-xs tracking-wide text-ink-500">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{articles.length}</span> Artikel
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{Object.keys(catCounts).length}</span> Kategorien
            </span>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div>
        {/* Top-Artikel Ranking */}
        {!loading && articles.length >= 3 && (() => {
          const top = [...articles]
            .sort((a, b) => (votes[b.id] ?? 0) - (votes[a.id] ?? 0))
            .slice(0, 3)
          const hasAnyVotes = top.some(a => (votes[a.id] ?? 0) > 0)
          if (!hasAnyVotes) return null
          return (
            <div className="relative mb-6 p-4 bg-gradient-to-br from-blue-50 via-blue-50/80 to-indigo-50 border border-blue-200 rounded-2xl shadow-soft overflow-hidden">
              <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
              <div
                className="absolute top-0 left-0 right-0 h-[3px]"
                style={{ background: 'linear-gradient(90deg, #3B82F6, #3B82F633)' }}
              />
              <div className="relative flex items-center gap-2 mb-3">
                <Star className="w-4 h-4 text-amber-500" />
                <span className="text-sm font-bold text-gray-800">Meistempfohlen</span>
              </div>
              <div className="relative space-y-2">
                {top.map((a, i) => (
                  <button key={a.id} onClick={() => setViewArticle(a)}
                    className="w-full flex items-center gap-3 p-2.5 bg-white/80 hover:bg-white rounded-xl transition-colors text-left shadow-soft">
                    <span className="display-numeral w-6 h-6 rounded-full bg-blue-100 text-blue-700 text-xs font-bold flex items-center justify-center flex-shrink-0">
                      {i + 1}
                    </span>
                    <span className="text-sm font-medium text-gray-800 flex-1 truncate">{a.title}</span>
                    <span className="flex items-center gap-1 text-xs text-blue-500 font-semibold">
                      <ThumbsUp className="w-3 h-3" /> {votes[a.id] ?? 0}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          )
        })()}

        {/* Search & Filter */}
        <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="input pl-10 py-2.5" placeholder="Artikel suchen..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
              className="input w-auto min-w-[160px]">
              <option value="all">Alle Kategorien</option>
              {WIKI_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label} ({catCounts[c.value] ?? 0})</option>)}
            </select>
            <button onClick={() => { setEditArticle(undefined); setShowEditor(true) }}
              className="shine flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 flex-shrink-0" style={{ boxShadow: '0 4px 16px -4px rgba(59,130,246,0.45)' }}>
              <Plus className="w-4 h-4" /> Artikel schreiben
            </button>
          </div>
        </div>

        {/* Category Quick-Chips */}
        <div className="flex flex-wrap gap-2 mb-4">
          {WIKI_CATEGORIES.filter(c => (catCounts[c.value] ?? 0) > 0).map(c => (
            <button key={c.value} onClick={() => setFilterCat(filterCat === c.value ? 'all' : c.value)}
              className={cn('px-3 py-1 rounded-full text-xs font-medium transition-all border',
                filterCat === c.value ? 'bg-blue-100 border-blue-300 text-blue-700 shadow-sm' : 'bg-white border-warm-200 text-gray-600 hover:bg-gray-50')}>
              {c.label} ({catCounts[c.value]})
            </button>
          ))}
        </div>

        {/* Articles */}
        {loading ? (
          <div className="space-y-3">
            {[1, 2, 3, 4].map(i => <div key={i} className="h-24 bg-white rounded-2xl animate-pulse border border-warm-200" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl border border-warm-200 shadow-sm">
            <BookOpen className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-700 font-bold text-lg">Keine Artikel gefunden</p>
            <p className="text-sm text-gray-500 mt-1 mb-4">Teile dein Wissen mit der Gemeinschaft</p>
            <button onClick={() => { setEditArticle(undefined); setShowEditor(true) }}
              className="shine inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-700 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95" style={{ boxShadow: '0 4px 16px -4px rgba(59,130,246,0.45)' }}>
              <Plus className="w-4 h-4" /> Ersten Artikel schreiben
            </button>
          </div>
        ) : (
          <div className="space-y-3 pb-8">
            {filtered.map(a => (
              <ArticleCard
                key={a.id}
                article={a}
                onClick={() => setViewArticle(a)}
                voteCount={votes[a.id] ?? 0}
                hasVoted={myVotes.has(a.id)}
                onVote={() => handleVote(a.id)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Modals */}
      {showEditor && (
        <ArticleEditor article={editArticle} onClose={() => setShowEditor(false)} onSaved={loadData} />
      )}
      {viewArticle && (
        <ArticleDetail article={viewArticle} onClose={() => setViewArticle(undefined)}
          onEdit={() => { setEditArticle(viewArticle); setViewArticle(undefined); setShowEditor(true) }} userId={userId} />
      )}
    </div>
  )
}
