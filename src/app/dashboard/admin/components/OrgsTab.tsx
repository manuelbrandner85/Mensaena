'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, Building2, CheckCircle2, Star } from 'lucide-react'
import type { AdminOrg } from './AdminTypes'

const PAGE_SIZE = 20

export default function OrgsTab() {
  const [orgs, setOrgs]           = useState<AdminOrg[]>([])
  const [search, setSearch]       = useState('')
  const [verifiedFilter, setVerified] = useState<string>('')
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState(0)
  const [total, setTotal]         = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('organizations')
      .select('id,name,slug,category:cat,verified,rating_avg,rating_count,created_at', { count: 'exact' })
    if (search) query = query.ilike('name', `%${search}%`)
    if (verifiedFilter === 'true') query = query.eq('verified', true)
    if (verifiedFilter === 'false') query = query.eq('verified', false)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setOrgs((data ?? []) as AdminOrg[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, verifiedFilter, page])

  useEffect(() => { load() }, [load])

  const handleToggleVerified = async (id: string, current: boolean) => {
    const supabase = createClient()
    const { error } = await supabase.from('organizations').update({ verified: !current }).eq('id', id)
    if (error) { toast.error('Update fehlgeschlagen'); return }
    toast.success(current ? 'Verifizierung entfernt' : 'Verifiziert')
    setOrgs(prev => prev.map(o => o.id === id ? { ...o, verified: !current } : o))
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Organisation "${name}" loeschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_organization', { p_organization_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('organizations').delete().eq('id', id)
      if (e2) { toast.error('Loeschen fehlgeschlagen'); return }
    }
    toast.success('Organisation geloescht')
    setOrgs(prev => prev.filter(o => o.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Organisation suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select value={verifiedFilter} onChange={e => { setVerified(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm">
          <option value="">Alle</option>
          <option value="true">Verifiziert</option>
          <option value="false">Nicht verifiziert</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Organisationen</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Kategorie</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Verifiziert</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Bewertung</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Erstellt</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {orgs.map(o => (
                    <tr key={o.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Building2 className="w-4 h-4 text-teal-500 shrink-0" />
                          <span className="font-medium text-gray-900 truncate max-w-48">{o.name}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs capitalize">{o.category ?? '-'}</td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => handleToggleVerified(o.id, o.verified)}
                          className={`w-10 h-5 rounded-full transition-all relative ${o.verified ? 'bg-green-500' : 'bg-gray-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${o.verified ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className="inline-flex items-center gap-1 text-xs text-gray-600">
                          <Star className="w-3 h-3 text-yellow-500" />
                          {o.rating_avg?.toFixed(1) ?? '-'} ({o.rating_count})
                        </span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{new Date(o.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <button onClick={() => handleDelete(o.id, o.name)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                  {orgs.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-gray-400">Keine Organisationen</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={orgs.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
