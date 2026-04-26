'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Eye, Edit3, X, Save, Loader2
} from 'lucide-react'
import Link from 'next/link'
import type { AdminPost } from './AdminTypes'

const PAGE_SIZE = 20
const STATUS_COLORS: Record<string, string> = {
  active: 'bg-green-100 text-green-700',
  fulfilled: 'bg-blue-100 text-blue-700',
  archived: 'bg-stone-100 text-ink-600',
  pending: 'bg-amber-100 text-amber-700',
}
const URGENCY_COLORS: Record<string, string> = {
  low: 'bg-stone-100 text-ink-600',
  medium: 'bg-amber-100 text-amber-700',
  high: 'bg-orange-100 text-orange-700',
  critical: 'bg-red-100 text-red-700',
}

export default function PostsTab() {
  const [posts, setPosts]         = useState<AdminPost[]>([])
  const [search, setSearch]       = useState('')
  const [statusFilter, setStatus] = useState<string>('')
  const [typeFilter, setType]     = useState<string>('')
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState(0)
  const [total, setTotal]         = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('posts')
      .select('id,title,type,category,status,urgency,user_id,created_at,profiles(name)', { count: 'exact' })
    if (search) query = query.ilike('title', `%${search}%`)
    if (statusFilter) query = query.eq('status', statusFilter)
    if (typeFilter) query = query.eq('type', typeFilter)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setPosts((data ?? []) as AdminPost[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, statusFilter, typeFilter, page])

  useEffect(() => { load() }, [load])

  // ── Edit Modal State ──
  const [editPost, setEditPost] = useState<AdminPost | null>(null)
  const [editTitle, setEditTitle] = useState('')
  const [editStatus, setEditStatus] = useState('')
  const [editUrgency, setEditUrgency] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  const openEdit = (p: AdminPost) => {
    setEditPost(p)
    setEditTitle(p.title)
    setEditStatus(p.status)
    setEditUrgency(p.urgency)
  }

  const handleSaveEdit = async () => {
    if (!editPost) return
    setEditSaving(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editTitle !== editPost.title) updates.title = editTitle
    if (editStatus !== editPost.status) updates.status = editStatus
    if (editUrgency !== editPost.urgency) updates.urgency = editUrgency
    if (Object.keys(updates).length === 0) { setEditPost(null); setEditSaving(false); return }
    const { error } = await supabase.from('posts').update(updates).eq('id', editPost.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving(false); return }
    toast.success('Beitrag aktualisiert')
    setPosts(prev => prev.map(p => p.id === editPost.id ? { ...p, ...updates } : p))
    setEditPost(null)
    setEditSaving(false)
  }

  const handleDelete = async (id: string, title: string) => {
    if (!confirm(`Beitrag "${title}" und alle zugehörigen Daten löschen?`)) return
    const supabase = createClient()
    // Try RPC first (handles cascade)
    const { error } = await supabase.rpc('admin_delete_post', { p_post_id: id })
    if (error) {
      // Manual cascade: delete related data first, then the post
      await Promise.allSettled([
        supabase.from('interactions').delete().eq('post_id', id),
        supabase.from('saved_posts').delete().eq('post_id', id),
        supabase.from('post_comments').delete().eq('post_id', id),
        supabase.from('post_votes').delete().eq('post_id', id),
        supabase.from('post_shares').delete().eq('post_id', id),
        supabase.from('content_reports').delete().eq('content_id', id).eq('content_type', 'post'),
      ])
      const { error: e2 } = await supabase.from('posts').delete().eq('id', id)
      if (e2) { toast.error('Löschen fehlgeschlagen: ' + e2.message); return }
    }
    toast.success('Beitrag gelöscht')
    setPosts(prev => prev.filter(p => p.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Titel suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          aria-label="Status filtern"
          className="px-3 py-2.5 border border-stone-200 rounded-xl text-sm">
          <option value="">Alle Status</option>
          <option value="active">Aktiv</option>
          <option value="fulfilled">Erfüllt</option>
          <option value="archived">Archiviert</option>
          <option value="pending">Ausstehend</option>
        </select>
        <select value={typeFilter} onChange={e => { setType(e.target.value); setPage(0) }}
          aria-label="Typ filtern"
          className="px-3 py-2.5 border border-stone-200 rounded-xl text-sm">
          <option value="">Alle Typen</option>
          <option value="help_needed">Hilfe gesucht</option>
          <option value="help_offered">Hilfe angeboten</option>
          <option value="rescue">Rettung</option>
          <option value="animal">Tier</option>
          <option value="housing">Wohnen</option>
          <option value="supply">Versorgung</option>
          <option value="mobility">Mobilität</option>
          <option value="sharing">Teilen</option>
          <option value="crisis">Krise</option>
          <option value="community">Community</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-ink-500">{total} Beiträge</p>
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-stone-50 border-b border-stone-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Titel</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Typ</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Status</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Dringlichkeit</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Autor</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Datum</th>
                    <th className="text-right px-4 py-3 font-semibold text-ink-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {posts.map(p => (
                    <tr key={p.id} className="hover:bg-stone-50 transition-colors">
                      <td className="px-4 py-3 font-medium text-ink-900 max-w-48 truncate">{p.title}</td>
                      <td className="px-4 py-3 text-ink-600 text-xs capitalize">{p.type.replace('_', ' ')}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[p.status] ?? 'bg-stone-100 text-ink-600'}`}>
                          {p.status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${URGENCY_COLORS[p.urgency] ?? ''}`}>
                          {p.urgency}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-ink-500 text-xs">{(p.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-ink-500 text-xs">{new Date(p.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <Link href={`/dashboard/posts/${p.id}`}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-green-600 hover:bg-green-50 transition-colors" title="Ansehen">
                            <Eye className="w-4 h-4" />
                          </Link>
                          <button onClick={() => openEdit(p)}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(p.id, p.title)}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {posts.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-ink-400">Keine Beiträge gefunden</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-ink-500">Seite {page + 1} von {Math.max(1, Math.ceil(total / PAGE_SIZE))}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={posts.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Edit Modal ── */}
      {editPost && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-ink-900 text-lg flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Beitrag bearbeiten
              </h3>
              <button onClick={() => setEditPost(null)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Titel</label>
                <input value={editTitle} onChange={e => setEditTitle(e.target.value)}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-ink-500 mb-1">Status</label>
                  <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                    className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                    <option value="active">Aktiv</option>
                    <option value="fulfilled">Erfüllt</option>
                    <option value="archived">Archiviert</option>
                    <option value="pending">Ausstehend</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-ink-500 mb-1">Dringlichkeit</label>
                  <select value={editUrgency} onChange={e => setEditUrgency(e.target.value)}
                    className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                    <option value="low">Niedrig</option>
                    <option value="medium">Mittel</option>
                    <option value="high">Hoch</option>
                    <option value="critical">Kritisch</option>
                  </select>
                </div>
              </div>
              <p className="text-xs text-ink-400">Autor: {(editPost.profiles as any)?.name ?? '-'} | Erstellt: {new Date(editPost.created_at).toLocaleDateString('de-AT')}</p>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditPost(null)} className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 rounded-xl text-sm font-semibold hover:bg-stone-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50">
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
