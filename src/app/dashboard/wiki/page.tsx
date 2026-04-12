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
  { value: 'ratgeber', label: '📖 Ratgeber' },
  { value: 'anleitung', label: '🔧 Anleitung' },
  { value: 'wissen', label: '🧠 Wissen' },
  { value: 'recht', label: '⚖️ Recht & Soziales' },
  { value: 'gesundheit', label: '💚 Gesundheit' },
  { value: 'notfall', label: '🚨 Notfall-Tipps' },
  { value: 'nachhaltigkeit', label: '🌱 Nachhaltigkeit' },
  { value: 'digital', label: '💻 Digital & Technik' },
  { value: 'sonstiges', label: '📋 Sonstiges' },
]

const catEmoji: Record<string, string> = {
  ratgeber: '📖', anleitung: '🔧', wissen: '🧠', recht: '⚖️',
  gesundheit: '💚', notfall: '🚨', nachhaltigkeit: '🌱',
  digital: '💻', sonstiges: '📋',
}

// ── Article Editor Modal ────────────────────────────────────────
function ArticleEditor({ article, onClose, onSaved }: { article?: Article; onClose: () => void; onSaved: () => void }) {
  const [title, setTitle] = useState(article?.title ?? '')
  const [content, setContent] = useState(article?.content ?? '')
  const [category, setCategory] = useState(article?.category ?? 'ratgeber')
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
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-gray-900">{article ? 'Artikel bearbeiten' : 'Neuer Artikel'}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5" /></button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={120}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-blue-500" placeholder="z.B. Wie beantrage ich Wohngeld?" />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-blue-500">
              {WIKI_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Inhalt * (Markdown wird unterstützt)</label>
            <textarea value={content} onChange={e => setContent(e.target.value)} rows={12}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-blue-500 font-mono text-sm"
              placeholder="Schreibe deinen Artikel hier..." />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Tags (kommagetrennt)</label>
            <input value={tagsInput} onChange={e => setTagsInput(e.target.value)}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-blue-500" placeholder="z.B. wohngeld, soziales, antrag" />
          </div>

          <button onClick={handleSave} disabled={saving || title.trim().length < 5}
            className="w-full py-2.5 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 disabled:opacity-50 flex items-center justify-center gap-2">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileText className="w-4 h-4" />}
            {article ? 'Speichern' : 'Veröffentlichen'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Article Detail View ─────────────────────────────────────────
function ArticleDetail({ article, onClose, onEdit, userId }: {
  article: Article; onClose: () => void; onEdit: () => void; userId?: string
}) {
  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
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

        {/* Render content as simple text (could be Markdown renderer) */}
        <div className="prose prose-sm max-w-none text-gray-700 whitespace-pre-wrap leading-relaxed">
          {article.content}
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
function ArticleCard({ article, onClick }: { article: Article; onClick: () => void }) {
  return (
    <button onClick={onClick} className="bg-white rounded-2xl border border-gray-100 p-4 hover:shadow-md transition-all text-left w-full group">
      <div className="flex items-start gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-400 to-indigo-500 flex items-center justify-center text-white text-sm flex-shrink-0">
          {catEmoji[article.category] || '📋'}
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-bold text-gray-900 text-sm group-hover:text-blue-600 transition-colors truncate">{article.title}</h3>
          <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{article.content.slice(0, 120)}...</p>
          <div className="flex items-center gap-2 mt-2">
            <span className="text-xs bg-blue-50 text-blue-600 px-1.5 py-0.5 rounded capitalize">{article.category}</span>
            <span className="text-xs text-gray-400 flex items-center gap-0.5">
              <Clock className="w-3 h-3" /> {new Date(article.created_at).toLocaleDateString('de-DE')}
            </span>
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
        <ChevronRight className="w-4 h-4 text-gray-300 group-hover:text-blue-500 transition-colors flex-shrink-0 mt-1" />
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

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)
    const { data } = await supabase.from('knowledge_articles').select('*')
      .eq('status', 'published')
      .order('created_at', { ascending: false })
    setArticles(data ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

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
    <div className="min-h-screen bg-gradient-to-b from-blue-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-blue-600 to-indigo-700 text-white px-4 sm:px-6 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm"><BookOpen className="w-6 h-6" /></div>
            <h1 className="text-2xl font-bold">Wissensbasis</h1>
          </div>
          <p className="text-blue-100 text-sm">Ratgeber, Anleitungen und Wissen für die Gemeinschaft</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              📚 {articles.length} Artikel
            </div>
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              📂 {Object.keys(catCounts).length} Kategorien
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 -mt-4">
        {/* Search & Filter */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-blue-500" placeholder="Artikel suchen..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
              className="px-3 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-blue-500">
              <option value="all">Alle Kategorien</option>
              {WIKI_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label} ({catCounts[c.value] ?? 0})</option>)}
            </select>
            <button onClick={() => { setEditArticle(undefined); setShowEditor(true) }}
              className="flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 transition-all">
              <Plus className="w-4 h-4" /> Artikel schreiben
            </button>
          </div>
        </div>

        {/* Category Quick-Chips */}
        <div className="flex flex-wrap gap-2 mb-4">
          {WIKI_CATEGORIES.filter(c => (catCounts[c.value] ?? 0) > 0).map(c => (
            <button key={c.value} onClick={() => setFilterCat(filterCat === c.value ? 'all' : c.value)}
              className={cn('px-3 py-1 rounded-full text-xs font-medium transition-all border',
                filterCat === c.value ? 'bg-blue-100 border-blue-300 text-blue-700' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50')}>
              {c.label} ({catCounts[c.value]})
            </button>
          ))}
        </div>

        {/* Articles */}
        {loading ? (
          <div className="space-y-3">
            {[1, 2, 3, 4].map(i => <div key={i} className="h-24 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16">
            <BookOpen className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 font-medium">Keine Artikel gefunden</p>
            <button onClick={() => { setEditArticle(undefined); setShowEditor(true) }}
              className="mt-3 text-sm text-blue-600 hover:text-blue-700 font-medium">Schreibe den ersten Artikel →</button>
          </div>
        ) : (
          <div className="space-y-3 pb-8">
            {filtered.map(a => (
              <ArticleCard key={a.id} article={a} onClick={() => setViewArticle(a)} />
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
