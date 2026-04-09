'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, AlertTriangle } from 'lucide-react'
import type { AdminCrisis } from './AdminTypes'

const PAGE_SIZE = 20
const SEVERITY_COLORS: Record<string, string> = {
  low: 'bg-gray-100 text-gray-600',
  medium: 'bg-amber-100 text-amber-700',
  high: 'bg-orange-100 text-orange-700',
  critical: 'bg-red-100 text-red-700',
}

export default function CrisisTab() {
  const [crises, setCrises]       = useState<AdminCrisis[]>([])
  const [search, setSearch]       = useState('')
  const [statusFilter, setStatus] = useState<string>('')
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState(0)
  const [total, setTotal]         = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('crises')
      .select('id,title,type,severity,status,reporter_id,created_at,profiles:reporter_id(name)', { count: 'exact' })
    if (search) query = query.ilike('title', `%${search}%`)
    if (statusFilter) query = query.eq('status', statusFilter)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setCrises((data ?? []) as AdminCrisis[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, statusFilter, page])

  useEffect(() => { load() }, [load])

  const handleDelete = async (id: string, title: string) => {
    if (!confirm(`Krise "${title}" loeschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_crisis', { p_crisis_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('crises').delete().eq('id', id)
      if (e2) { toast.error('Loeschen fehlgeschlagen'); return }
    }
    toast.success('Krise geloescht')
    setCrises(prev => prev.filter(c => c.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Krise suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm">
          <option value="">Alle Status</option>
          <option value="active">Aktiv</option>
          <option value="resolved">Geloest</option>
          <option value="monitoring">Beobachtung</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Krisen</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Titel</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Typ</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Schwere</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Melder</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Datum</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {crises.map(c => (
                    <tr key={c.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 font-medium text-gray-900 max-w-48 truncate">
                        <div className="flex items-center gap-2">
                          <AlertTriangle className="w-4 h-4 text-red-500 shrink-0" />
                          {c.title}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs capitalize">{c.type ?? '-'}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${SEVERITY_COLORS[c.severity ?? ''] ?? 'bg-gray-100 text-gray-600'}`}>
                          {c.severity ?? '-'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          c.status === 'active' ? 'bg-red-100 text-red-700' :
                          c.status === 'resolved' ? 'bg-green-100 text-green-700' :
                          'bg-amber-100 text-amber-700'
                        }`}>{c.status}</span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{(c.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{new Date(c.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <button onClick={() => handleDelete(c.id, c.title)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                  {crises.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-gray-400">Keine Krisen gefunden</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={crises.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
