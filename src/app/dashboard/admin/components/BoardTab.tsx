'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, Pin, MessageSquare, Edit3, X, Save, Loader2 } from 'lucide-react'
import type { AdminBoardPost } from './AdminTypes'

const PAGE_SIZE = 20
const CAT_LABELS: Record<string, string> = {
  general: 'Allgemein', gesucht: 'Gesucht', biete: 'Biete', event: 'Event',
  info: 'Info', warnung: 'Warnung', verloren: 'Verloren', fundbuero: 'Fundbuero',
}

export default function BoardTab() {
  const [posts, setPosts]         = useState<AdminBoardPost[]>([])
  const [search, setSearch]       = useState('')
  const [catFilter, setCat]       = useState<string>('')
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState(0)
  const [total, setTotal]         = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('board_posts')
      .select('id,content,category,color,status,pin_count,comment_count,author_id,created_at,profiles(name)', { count: 'exact' })
    if (search) query = query.ilike('content', `%${search}%`)
    if (catFilter) query = query.eq('category', catFilter)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setPosts((data ?? []) as AdminBoardPost[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, catFilter, page])

  useEffect(() => { load() }, [load])

  // ── Edit State ──
  const [editPost, setEditPost] = useState<AdminBoardPost | null>(null)
  const [editContent, setEditContent] = useState('')
  const [editCategory, setEditCategory] = useState('')
  const [editStatus, setEditStatus] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  const openEdit = (p: AdminBoardPost) => {
    setEditPost(p)
    setEditContent(p.content)
    setEditCategory(p.category)
    setEditStatus(p.status)
  }

  const handleSaveEdit = async () => {
    if (!editPost) return
    setEditSaving(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editContent !== editPost.content) updates.content = editContent
    if (editCategory !== editPost.category) updates.category = editCategory
    if (editStatus !== editPost.status) updates.status = editStatus
    if (Object.keys(updates).length === 0) { setEditPost(null); setEditSaving(false); return }
    const { error } = await supabase.from('board_posts').update(updates).eq('id', editPost.id)
    if (error) { toast.error('Speichern fehlgeschlagen'); setEditSaving(false); return }
    toast.success('Brett-Beitrag aktualisiert')
    setPosts(prev => prev.map(p => p.id === editPost.id ? { ...p, ...updates } : p))
    setEditPost(null)
    setEditSaving(false)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Brett-Beitrag löschen?')) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_board_post', { p_board_post_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('board_posts').delete().eq('id', id)
      if (e2) { toast.error('Löschen fehlgeschlagen'); return }
    }
    toast.success('Brett-Beitrag gelöscht')
    setPosts(prev => prev.filter(p => p.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-mute" />
          <input type="text" inputMode="search" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Brett-Beitrag suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
        <select value={catFilter} onChange={e => { setCat(e.target.value); setPage(0) }}
          aria-label="Kategorie filtern"
          className="px-3 py-2.5 border border-white/5 rounded-xl text-sm">
          <option value="">Alle Kategorien</option>
          {Object.entries(CAT_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-mn-bronze/20 border-t-mn-bronze rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-mn-mute">{total} Brett-Beiträge</p>
          <div className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-mn-surface border-b border-white/5">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Inhalt</th>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Kategorie</th>
                    <th className="text-center px-4 py-3 font-semibold text-mn-ink-soft">Pins</th>
                    <th className="text-center px-4 py-3 font-semibold text-mn-ink-soft">Kommentare</th>
                    <th className="text-center px-4 py-3 font-semibold text-mn-ink-soft">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Autor</th>
                    <th className="text-right px-4 py-3 font-semibold text-mn-ink-soft">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {posts.map(p => (
                    <tr key={p.id} className="hover:bg-mn-surface transition-colors">
                      <td className="px-4 py-3 text-mn-ink max-w-64 truncate">{p.content}</td>
                      <td className="px-4 py-3 text-mn-ink-soft text-xs">{CAT_LABELS[p.category] ?? p.category}</td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center gap-1 text-xs text-mn-ink-soft">
                          <Pin className="w-3 h-3" /> {p.pin_count}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center gap-1 text-xs text-mn-ink-soft">
                          <MessageSquare className="w-3 h-3" /> {p.comment_count}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          p.status === 'active' ? 'bg-mn-elevated text-mn-leben' : 'bg-mn-elevated text-mn-ink-soft'
                        }`}>{p.status}</span>
                      </td>
                      <td className="px-4 py-3 text-mn-mute text-xs">{(p.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <button onClick={() => openEdit(p)}
                            className="p-1.5 rounded-xl text-mn-mute hover:text-mn-teal-soft hover:bg-mn-surface transition-colors" aria-label="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(p.id)}
                            className="p-1.5 rounded-xl text-mn-mute hover:text-mn-herzrot hover:bg-mn-surface transition-colors" aria-label="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {posts.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-mn-mute">Keine Brett-Beiträge</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-mn-ink-soft hover:text-mn-ink disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-mn-mute">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={posts.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-mn-ink-soft hover:text-mn-ink disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Edit Modal ── */}
      {editPost && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-mn-elevated rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-mn-ink flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-mn-teal-soft" /> Brett-Beitrag bearbeiten
              </h3>
              <button onClick={() => setEditPost(null)} className="p-1.5 rounded-xl hover:bg-mn-elevated text-mn-mute" aria-label="Schließen">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-mn-mute mb-1">Inhalt</label>
                <textarea value={editContent} onChange={e => setEditContent(e.target.value)} rows={3}
                  className="w-full px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 resize-none" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-mn-mute mb-1">Kategorie</label>
                  <select value={editCategory} onChange={e => setEditCategory(e.target.value)}
                    aria-label="Kategorie"
                    className="w-full px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                    {Object.entries(CAT_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-mn-mute mb-1">Status</label>
                  <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                    aria-label="Status"
                    className="w-full px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                    <option value="active">Aktiv</option>
                    <option value="expired">Abgelaufen</option>
                    <option value="hidden">Versteckt</option>
                    <option value="deleted">Gelöscht</option>
                  </select>
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditPost(null)} className="flex-1 px-4 py-2.5 bg-mn-elevated text-mn-ink-soft rounded-xl text-sm font-semibold hover:bg-mn-raised transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-mn-teal/8 transition-colors disabled:opacity-50">
                {editSaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                Speichern
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
