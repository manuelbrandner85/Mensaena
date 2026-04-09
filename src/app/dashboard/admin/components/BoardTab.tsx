'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, Pin, MessageSquare } from 'lucide-react'
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

  const handleDelete = async (id: string) => {
    if (!confirm('Brett-Beitrag loeschen?')) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_board_post', { p_board_post_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('board_posts').delete().eq('id', id)
      if (e2) { toast.error('Loeschen fehlgeschlagen'); return }
    }
    toast.success('Brett-Beitrag geloescht')
    setPosts(prev => prev.filter(p => p.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Brett-Beitrag suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select value={catFilter} onChange={e => { setCat(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm">
          <option value="">Alle Kategorien</option>
          {Object.entries(CAT_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Brett-Beitraege</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Inhalt</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Kategorie</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Pins</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Kommentare</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Autor</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {posts.map(p => (
                    <tr key={p.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 text-gray-900 max-w-64 truncate">{p.content}</td>
                      <td className="px-4 py-3 text-gray-600 text-xs">{CAT_LABELS[p.category] ?? p.category}</td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center gap-1 text-xs text-gray-600">
                          <Pin className="w-3 h-3" /> {p.pin_count}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center gap-1 text-xs text-gray-600">
                          <MessageSquare className="w-3 h-3" /> {p.comment_count}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          p.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                        }`}>{p.status}</span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{(p.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-right">
                        <button onClick={() => handleDelete(p.id)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                  {posts.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-gray-400">Keine Brett-Beitraege</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurueck
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={posts.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
