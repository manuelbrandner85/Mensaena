'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Edit3,
  X, Save, Loader2, Clock, CheckCircle2, Timer
} from 'lucide-react'
import type { AdminTimebankEntry } from './AdminTypes'
import ConfirmDialog from './ConfirmDialog'

const PAGE_SIZE = 25

// Must match DB CHECK constraint: timebank_entries_status_check
const STATUS_COLORS: Record<string, string> = {
  pending:   'bg-amber-100 text-amber-700',
  confirmed: 'bg-green-100 text-green-700',
  cancelled: 'bg-stone-100 text-ink-600',
}
const STATUS_LABELS: Record<string, string> = {
  pending: 'Ausstehend', confirmed: 'Bestätigt', cancelled: 'Abgebrochen',
}
const STATUS_ICONS: Record<string, React.ReactNode> = {
  pending:   <Timer className="w-3 h-3" />,
  confirmed: <CheckCircle2 className="w-3 h-3" />,
  cancelled: <X className="w-3 h-3" />,
}

export default function ZeitbankTab() {
  const [entries, setEntries]       = useState<AdminTimebankEntry[]>([])
  const [search, setSearch]         = useState('')
  const [statusFilter, setStatus]   = useState('')
  const [loading, setLoading]       = useState(true)
  const [page, setPage]             = useState(0)
  const [total, setTotal]           = useState(0)
  const [totalHours, setTotalHours] = useState(0)

  // Edit state
  const [editEntry, setEditEntry]   = useState<AdminTimebankEntry | null>(null)
  const [editHours, setEditHours]   = useState(1)
  const [editDesc, setEditDesc]     = useState('')
  const [editStatus, setEditStatus] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  // Confirm delete
  const [confirmDelete, setConfirmDelete] = useState<AdminTimebankEntry | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()

    // We need to join profiles for giver and receiver — use explicit aliases
    let query = supabase
      .from('timebank_entries')
      .select(
        'id,giver_id,receiver_id,post_id,hours,description,category,status,confirmed_at,created_at,' +
        'giver:profiles!giver_id(name,email),receiver:profiles!receiver_id(name,email)',
        { count: 'exact' }
      )

    if (statusFilter) query = query.eq('status', statusFilter)
    if (search) query = query.or(`description.ilike.%${search}%`)

    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)

    setEntries((data ?? []) as unknown as AdminTimebankEntry[])
    setTotal(count ?? 0)

    // Total confirmed hours (separate query, no filter)
    const { data: hoursData } = await supabase
      .from('timebank_entries')
      .select('hours')
      .eq('status', 'confirmed')
    setTotalHours(hoursData?.reduce((s, e) => s + Number(e.hours), 0) ?? 0)

    setLoading(false)
  }, [search, statusFilter, page])

  useEffect(() => { load() }, [load])

  const openEdit = (e: AdminTimebankEntry) => {
    setEditEntry(e)
    setEditHours(Number(e.hours))
    setEditDesc(e.description)
    setEditStatus(e.status)
  }

  const handleSaveEdit = async () => {
    if (!editEntry) return
    setEditSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('timebank_entries').update({
      hours: editHours,
      description: editDesc.trim(),
      status: editStatus,
      confirmed_at: editStatus === 'confirmed' ? new Date().toISOString() : editEntry.confirmed_at,
    }).eq('id', editEntry.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving(false); return }
    toast.success('Eintrag aktualisiert')
    setEntries(prev => prev.map(e => e.id === editEntry.id
      ? { ...e, hours: editHours, description: editDesc.trim(), status: editStatus }
      : e
    ))
    setEditEntry(null)
    setEditSaving(false)
  }

  const handleDelete = async () => {
    if (!confirmDelete) return
    const supabase = createClient()
    const { error } = await supabase.from('timebank_entries').delete().eq('id', confirmDelete.id)
    if (error) { toast.error('Löschen fehlgeschlagen: ' + error.message); setConfirmDelete(null); return }
    toast.success('Eintrag gelöscht')
    setEntries(prev => prev.filter(e => e.id !== confirmDelete.id))
    setTotal(prev => prev - 1)
    setConfirmDelete(null)
  }

  const getProfileName = (p: { name: string | null } | { name: string | null }[] | undefined | null) => {
    if (!p) return null
    if (Array.isArray(p)) return (p[0] as { name: string | null } | undefined)?.name ?? null
    return (p as { name: string | null }).name ?? null
  }

  return (
    <div className="space-y-4">
      {/* Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <div className="bg-primary-50 rounded-xl p-4 border border-primary-100">
          <div className="flex items-center gap-2 mb-1">
            <Clock className="w-4 h-4 text-primary-600" />
            <span className="text-xs font-medium text-ink-500">Bestätigte Stunden</span>
          </div>
          <p className="text-2xl font-bold text-primary-700">{totalHours.toFixed(1)}h</p>
        </div>
        <div className="bg-stone-50 rounded-xl p-4 border border-stone-100">
          <div className="flex items-center gap-2 mb-1">
            <Timer className="w-4 h-4 text-amber-600" />
            <span className="text-xs font-medium text-ink-500">Einträge gesamt</span>
          </div>
          <p className="text-2xl font-bold text-ink-900">{total}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Beschreibung suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
          <option value="">Alle Status</option>
          {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-stone-50 border-b border-stone-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Geber → Empfänger</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Beschreibung</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Stunden</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Datum</th>
                    <th className="text-right px-4 py-3 font-semibold text-ink-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {entries.map(e => {
                    const giverName    = getProfileName(e.giver as Parameters<typeof getProfileName>[0]) ?? e.giver_id.slice(0, 8)
                    const receiverName = getProfileName(e.receiver as Parameters<typeof getProfileName>[0]) ?? e.receiver_id.slice(0, 8)
                    return (
                      <tr key={e.id} className="hover:bg-stone-50 transition-colors">
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-1.5 text-xs">
                            <span className="font-medium text-ink-900">{giverName}</span>
                            <span className="text-ink-400">→</span>
                            <span className="font-medium text-ink-700">{receiverName}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-ink-600 text-xs max-w-[200px] truncate">
                          {e.description}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="inline-flex items-center gap-1 text-sm font-bold text-primary-700">
                            <Clock className="w-3.5 h-3.5" />
                            {Number(e.hours).toFixed(1)}h
                          </span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[e.status] ?? 'bg-stone-100 text-ink-600'}`}>
                            {STATUS_ICONS[e.status]}
                            {STATUS_LABELS[e.status] ?? e.status}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-ink-500 text-xs">
                          {new Date(e.created_at).toLocaleDateString('de-AT')}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center gap-1 justify-end">
                            <button onClick={() => openEdit(e)}
                              className="p-1.5 rounded-lg text-ink-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                              title="Bearbeiten">
                              <Edit3 className="w-4 h-4" />
                            </button>
                            <button onClick={() => setConfirmDelete(e)}
                              className="p-1.5 rounded-lg text-ink-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                              title="Löschen">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                  {entries.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-ink-400">Keine Einträge gefunden</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-ink-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={entries.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* Edit Modal */}
      {editEntry && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-ink-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Zeiteintrag bearbeiten
              </h3>
              <button onClick={() => setEditEntry(null)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Stunden</label>
                <input type="number" value={editHours} onChange={e => setEditHours(Number(e.target.value))}
                  min={0.1} max={24} step={0.5}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Beschreibung</label>
                <textarea value={editDesc} onChange={e => setEditDesc(e.target.value)} rows={3}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300 resize-none" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Status</label>
                <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditEntry(null)}
                className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 rounded-xl text-sm font-semibold hover:bg-stone-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving || !editDesc.trim()}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50">
                {editSaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                Speichern
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Delete */}
      <ConfirmDialog
        open={!!confirmDelete}
        variant="danger"
        title="Zeiteintrag löschen"
        message={`Zeiteintrag (${Number(confirmDelete?.hours).toFixed(1)}h) wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`}
        confirmLabel="Löschen"
        onConfirm={handleDelete}
        onCancel={() => setConfirmDelete(null)}
      />
    </div>
  )
}
