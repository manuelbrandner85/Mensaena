'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Eye,
  CheckCircle2, XCircle, Leaf, MapPin
} from 'lucide-react'
import Link from 'next/link'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS, COUNTRY_LABELS } from '@/types/farm'

const PAGE_SIZE = 20

export default function FarmsTab() {
  const [farms, setFarms]     = useState<FarmListing[]>([])
  const [search, setSearch]   = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage]       = useState(0)
  const [total, setTotal]     = useState(0)
  const [saving, setSaving]   = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('farm_listings')
      .select('*', { count: 'exact' })
    if (search) query = query.or(`name.ilike.%${search}%,city.ilike.%${search}%`)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setFarms((data ?? []) as FarmListing[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, page])

  useEffect(() => { load() }, [load])

  const toggleVerified = async (farm: FarmListing) => {
    setSaving(farm.id)
    const supabase = createClient()
    await supabase.from('farm_listings').update({ is_verified: !farm.is_verified }).eq('id', farm.id)
    setFarms(prev => prev.map(f => f.id === farm.id ? { ...f, is_verified: !f.is_verified } : f))
    setSaving(null)
  }

  const togglePublic = async (farm: FarmListing) => {
    setSaving(farm.id)
    const supabase = createClient()
    await supabase.from('farm_listings').update({ is_public: !farm.is_public }).eq('id', farm.id)
    setFarms(prev => prev.map(f => f.id === farm.id ? { ...f, is_public: !f.is_public } : f))
    setSaving(null)
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Betrieb "${name}" loeschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_farm', { p_farm_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('farm_listings').delete().eq('id', id)
      if (e2) { toast.error('Loeschen fehlgeschlagen'); return }
    }
    toast.success('Betrieb geloescht')
    setFarms(prev => prev.filter(f => f.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Betrieb oder Stadt suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Betriebe</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Stadt</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Land</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">GPS</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Oeffentlich</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Verifiziert</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {farms.map(f => (
                    <tr key={f.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span>{CATEGORY_ICONS[f.category] || '🏡'}</span>
                          <span className="font-medium text-gray-900 truncate max-w-48">{f.name}</span>
                          {f.is_bio && <Leaf className="w-3.5 h-3.5 text-lime-600 shrink-0" />}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600">{f.city}</td>
                      <td className="px-4 py-3 text-gray-500">{COUNTRY_LABELS[f.country] ?? f.country}</td>
                      <td className="px-4 py-3 text-center">
                        {f.latitude && f.longitude
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => togglePublic(f)} disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_public ? 'bg-green-500' : 'bg-gray-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_public ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => toggleVerified(f)} disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_verified ? 'bg-blue-500' : 'bg-gray-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_verified ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <Link href={`/dashboard/supply/farm/${f.slug}`}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-green-600 hover:bg-green-50 transition-colors">
                            <Eye className="w-4 h-4" />
                          </Link>
                          <button onClick={() => handleDelete(f.id, f.name)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {farms.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-gray-400">Keine Betriebe</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={farms.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
