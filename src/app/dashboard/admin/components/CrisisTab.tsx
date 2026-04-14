'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, AlertTriangle, Edit3, X, Save, Loader2, CheckCircle2 } from 'lucide-react'
import type { AdminCrisis } from './AdminTypes'

const PAGE_SIZE = 20
const URGENCY_COLORS: Record<string, string> = {
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
      .select('id,title,category,urgency,status,creator_id,created_at,profiles:creator_id(name)', { count: 'exact' })
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

  // ── Edit State ──
  const [editCrisis, setEditCrisis] = useState<AdminCrisis | null>(null)
  const [editStatus, setEditStatus] = useState('')
  const [editUrgency, setEditUrgency] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  const openEdit = (c: AdminCrisis) => {
    setEditCrisis(c)
    setEditStatus(c.status)
    setEditUrgency(c.urgency ?? 'medium')
  }

  const handleSaveEdit = async () => {
    if (!editCrisis) return
    setEditSaving(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editStatus !== editCrisis.status) updates.status = editStatus
    if (editUrgency !== (editCrisis.urgency ?? 'medium')) updates.urgency = editUrgency
    if (Object.keys(updates).length === 0) { setEditCrisis(null); setEditSaving(false); return }
    const { error } = await supabase.from('crises').update(updates).eq('id', editCrisis.id)
    if (error) { toast.error('Speichern fehlgeschlagen'); setEditSaving(false); return }
    toast.success('Krise aktualisiert')
    setCrises(prev => prev.map(c => c.id === editCrisis.id ? { ...c, ...updates } : c))
    setEditCrisis(null)
    setEditSaving(false)
  }

  const handleDelete = async (id: string, title: string) => {
    if (!confirm(`Krise "${title}" wirklich löschen? Alle zugehörigen Helfer-Einträge und Updates werden ebenfalls entfernt.`)) return
    const supabase = createClient()

    // Try RPC first (handles cascade)
    const { error } = await supabase.rpc('admin_delete_crisis', { p_crisis_id: id })
    if (error) {
      // Fallback: delete related data manually, then the crisis
      try { await supabase.from('crisis_updates').delete().eq('crisis_id', id) } catch {}
      try { await supabase.from('crisis_helpers').delete().eq('crisis_id', id) } catch {}
      const { error: e2 } = await supabase.from('crises').delete().eq('id', id)
      if (e2) { toast.error(`Löschen fehlgeschlagen: ${e2.message}`); return }
    }
    toast.success('Krise gelöscht')
    setCrises(prev => prev.filter(c => c.id !== id))
    setTotal(prev => prev - 1)
  }

  const handleResolve = async (id: string) => {
    const supabase = createClient()
    const { error } = await supabase.from('crises').update({ status: 'resolved', resolved_at: new Date().toISOString() }).eq('id', id)
    if (error) { toast.error('Status-Änderung fehlgeschlagen'); return }
    toast.success('Krise als gelöst markiert')
    setCrises(prev => prev.map(c => c.id === id ? { ...c, status: 'resolved' } : c))
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
          <option value="in_progress">In Bearbeitung</option>
          <option value="resolved">Gelöst</option>
          <option value="false_alarm">Fehlalarm</option>
          <option value="cancelled">Abgebrochen</option>
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
                      <td className="px-4 py-3 text-gray-600 text-xs capitalize">{c.category ?? '-'}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${URGENCY_COLORS[c.urgency ?? ''] ?? 'bg-gray-100 text-gray-600'}`}>
                          {c.urgency ?? '-'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          c.status === 'active' ? 'bg-red-100 text-red-700' :
                          c.status === 'resolved' ? 'bg-green-100 text-green-700' :
                          c.status === 'in_progress' ? 'bg-amber-100 text-amber-700' :
                          c.status === 'false_alarm' ? 'bg-gray-100 text-gray-600' :
                          'bg-gray-100 text-gray-600'
                        }`}>{c.status}</span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{(c.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{new Date(c.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          {c.status === 'active' && (
                            <button onClick={() => handleResolve(c.id)}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-green-600 hover:bg-green-50 transition-colors" title="Als gelöst markieren">
                              <CheckCircle2 className="w-4 h-4" />
                            </button>
                          )}
                          <button onClick={() => openEdit(c)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(c.id, c.title)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
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
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={crises.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Edit Modal ── */}
      {editCrisis && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Krise bearbeiten
              </h3>
              <button onClick={() => setEditCrisis(null)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <p className="text-sm font-medium text-gray-700">{editCrisis.title}</p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Status</label>
                <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  <option value="active">Aktiv</option>
                  <option value="in_progress">In Bearbeitung</option>
                  <option value="resolved">Gelöst</option>
                  <option value="false_alarm">Fehlalarm</option>
                  <option value="cancelled">Abgebrochen</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Schwere</label>
                <select value={editUrgency} onChange={e => setEditUrgency(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  <option value="low">Niedrig</option>
                  <option value="medium">Mittel</option>
                  <option value="high">Hoch</option>
                  <option value="critical">Kritisch</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditCrisis(null)} className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
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
