'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Eye,
  CheckCircle2, XCircle, Leaf, MapPin, Edit3, X, Save, Loader2
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

  // ── Edit State ──
  const [editFarm, setEditFarm] = useState<FarmListing | null>(null)
  const [editName, setEditName] = useState('')
  const [editCity, setEditCity] = useState('')
  const [editSaving2, setEditSaving2] = useState(false)

  const openEdit = (f: FarmListing) => {
    setEditFarm(f)
    setEditName(f.name)
    setEditCity(f.city)
  }

  const handleSaveEdit = async () => {
    if (!editFarm) return
    setEditSaving2(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editName !== editFarm.name) updates.name = editName
    if (editCity !== editFarm.city) updates.city = editCity
    if (Object.keys(updates).length === 0) { setEditFarm(null); setEditSaving2(false); return }
    const { error } = await supabase.from('farm_listings').update(updates).eq('id', editFarm.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving2(false); return }
    toast.success('Betrieb aktualisiert')
    setFarms(prev => prev.map(f => f.id === editFarm.id ? { ...f, ...updates } as FarmListing : f))
    setEditFarm(null)
    setEditSaving2(false)
  }

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
    if (!confirm(`Betrieb "${name}" löschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_farm', { p_farm_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('farm_listings').delete().eq('id', id)
      if (e2) { toast.error('Löschen fehlgeschlagen'); return }
    }
    toast.success('Betrieb gelöscht')
    setFarms(prev => prev.filter(f => f.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
          <input type="text" inputMode="search" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Betrieb oder Stadt suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-ink-500">{total} Betriebe</p>
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-stone-50 border-b border-stone-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Stadt</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Land</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">GPS</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Öffentlich</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Verifiziert</th>
                    <th className="text-right px-4 py-3 font-semibold text-ink-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {farms.map(f => (
                    <tr key={f.id} className="hover:bg-stone-50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <span>{CATEGORY_ICONS[f.category] || '🏡'}</span>
                          <span className="font-medium text-ink-900 truncate max-w-48">{f.name}</span>
                          {f.is_bio && <Leaf className="w-3.5 h-3.5 text-lime-600 shrink-0" />}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-ink-600">{f.city}</td>
                      <td className="px-4 py-3 text-ink-500">{COUNTRY_LABELS[f.country] ?? f.country}</td>
                      <td className="px-4 py-3 text-center">
                        {f.latitude && f.longitude
                          ? <CheckCircle2 className="w-4 h-4 text-green-500 mx-auto" />
                          : <XCircle className="w-4 h-4 text-red-400 mx-auto" />}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => togglePublic(f)} disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_public ? 'bg-green-500' : 'bg-stone-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_public ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => toggleVerified(f)} disabled={saving === f.id}
                          className={`w-10 h-5 rounded-full transition-all relative ${f.is_verified ? 'bg-blue-500' : 'bg-stone-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${f.is_verified ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <Link href={`/dashboard/supply/farm/${f.slug}`}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-green-600 hover:bg-green-50 transition-colors" title="Ansehen">
                            <Eye className="w-4 h-4" />
                          </Link>
                          <button onClick={() => openEdit(f)}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(f.id, f.name)}
                            className="p-1.5 rounded-lg text-ink-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {farms.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-ink-400">Keine Betriebe</td></tr>
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
            <span className="text-sm text-ink-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={farms.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
      {/* ── Edit Modal ── */}
      {editFarm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-ink-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Betrieb bearbeiten
              </h3>
              <button onClick={() => setEditFarm(null)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Name</label>
                <input value={editName} onChange={e => setEditName(e.target.value)}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Stadt</label>
                <input value={editCity} onChange={e => setEditCity(e.target.value)}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditFarm(null)} className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 rounded-xl text-sm font-semibold hover:bg-stone-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving2}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50">
                {editSaving2 ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                Speichern
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
