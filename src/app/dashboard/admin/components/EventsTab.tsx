'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, Calendar, Edit3, X, Save, Loader2 } from 'lucide-react'
import type { AdminEvent } from './AdminTypes'

const PAGE_SIZE = 20

export default function EventsTab() {
  const [events, setEvents]       = useState<AdminEvent[]>([])
  const [search, setSearch]       = useState('')
  const [statusFilter, setStatus] = useState<string>('')
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState(0)
  const [total, setTotal]         = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase.from('events')
      .select('id,title,category,start_date,end_date,status,attendee_count,author_id,created_at,profiles(name)', { count: 'exact' })
    if (search) query = query.ilike('title', `%${search}%`)
    if (statusFilter) query = query.eq('status', statusFilter)
    const { data, count } = await query
      .order('start_date', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setEvents((data ?? []) as AdminEvent[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, statusFilter, page])

  useEffect(() => { load() }, [load])

  // ── Edit State ──
  const [editEvent, setEditEvent] = useState<AdminEvent | null>(null)
  const [editTitle, setEditTitle] = useState('')
  const [editStatus, setEditStatus] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  const openEdit = (ev: AdminEvent) => {
    setEditEvent(ev)
    setEditTitle(ev.title)
    setEditStatus(ev.status)
  }

  const handleSaveEdit = async () => {
    if (!editEvent) return
    setEditSaving(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editTitle !== editEvent.title) updates.title = editTitle
    if (editStatus !== editEvent.status) updates.status = editStatus
    if (Object.keys(updates).length === 0) { setEditEvent(null); setEditSaving(false); return }
    const { error } = await supabase.from('events').update(updates).eq('id', editEvent.id)
    if (error) { toast.error('Speichern fehlgeschlagen'); setEditSaving(false); return }
    toast.success('Event aktualisiert')
    setEvents(prev => prev.map(e => e.id === editEvent.id ? { ...e, ...updates } : e))
    setEditEvent(null)
    setEditSaving(false)
  }

  const handleDelete = async (id: string, title: string) => {
    if (!confirm(`Event "${title}" und alle zugehörigen Daten löschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_event', { p_event_id: id })
    if (error) {
      // Manual cascade: delete attendees and volunteer signups first
      await Promise.allSettled([
        supabase.from('event_attendees').delete().eq('event_id', id),
        supabase.from('volunteer_signups').delete().eq('event_id', id),
        supabase.from('content_reports').delete().eq('content_id', id).eq('content_type', 'event'),
      ])
      const { error: e2 } = await supabase.from('events').delete().eq('id', id)
      if (e2) { toast.error('Löschen fehlgeschlagen: ' + e2.message); return }
    }
    toast.success('Event gelöscht')
    setEvents(prev => prev.filter(e => e.id !== id))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Event suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm">
          <option value="">Alle Status</option>
          <option value="upcoming">Geplant</option>
          <option value="ongoing">Laufend</option>
          <option value="completed">Abgeschlossen</option>
          <option value="cancelled">Abgesagt</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Events</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Titel</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Kategorie</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Datum</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Teilnehmer</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Ersteller</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {events.map(ev => (
                    <tr key={ev.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 font-medium text-gray-900 max-w-48 truncate">
                        <div className="flex items-center gap-2">
                          <Calendar className="w-4 h-4 text-sky-500 shrink-0" />
                          {ev.title}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs capitalize">{ev.category}</td>
                      <td className="px-4 py-3 text-gray-500 text-xs">
                        {new Date(ev.start_date).toLocaleDateString('de-AT')}
                      </td>
                      <td className="px-4 py-3 text-center text-gray-700 font-medium">{ev.attendee_count}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          ev.status === 'upcoming' ? 'bg-green-100 text-green-700' :
                          ev.status === 'ongoing' ? 'bg-blue-100 text-blue-700' :
                          ev.status === 'completed' ? 'bg-gray-100 text-gray-600' :
                          'bg-red-100 text-red-700'
                        }`}>{ev.status}</span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{(ev.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <button onClick={() => openEdit(ev)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(ev.id, ev.title)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {events.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-gray-400">Keine Events gefunden</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={events.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Edit Modal ── */}
      {editEvent && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Event bearbeiten
              </h3>
              <button onClick={() => setEditEvent(null)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Titel</label>
                <input value={editTitle} onChange={e => setEditTitle(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Status</label>
                <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  <option value="upcoming">Geplant</option>
                  <option value="ongoing">Laufend</option>
                  <option value="completed">Abgeschlossen</option>
                  <option value="cancelled">Abgesagt</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditEvent(null)} className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
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
