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
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-mute" />
          <input type="text" inputMode="search" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Event suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          aria-label="Status filtern"
          className="px-3 py-2.5 border border-white/5 rounded-xl text-sm">
          <option value="">Alle Status</option>
          <option value="upcoming">Geplant</option>
          <option value="ongoing">Laufend</option>
          <option value="completed">Abgeschlossen</option>
          <option value="cancelled">Abgesagt</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-mn-bronze/20 border-t-mn-bronze rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-mn-mute">{total} Events</p>
          <div className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-mn-surface border-b border-white/5">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Titel</th>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Kategorie</th>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Datum</th>
                    <th className="text-center px-4 py-3 font-semibold text-mn-ink-soft">Teilnehmer</th>
                    <th className="text-center px-4 py-3 font-semibold text-mn-ink-soft">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-mn-ink-soft">Ersteller</th>
                    <th className="text-right px-4 py-3 font-semibold text-mn-ink-soft">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {events.map(ev => (
                    <tr key={ev.id} className="hover:bg-mn-surface transition-colors">
                      <td className="px-4 py-3 font-medium text-mn-ink max-w-48 truncate">
                        <div className="flex items-center gap-2">
                          <Calendar className="w-4 h-4 text-mn-teal-soft shrink-0" />
                          {ev.title}
                        </div>
                      </td>
                      <td className="px-4 py-3 text-mn-ink-soft text-xs capitalize">{ev.category}</td>
                      <td className="px-4 py-3 text-mn-mute text-xs">
                        {new Date(ev.start_date).toLocaleDateString('de-AT')}
                      </td>
                      <td className="px-4 py-3 text-center text-mn-ink-soft font-medium">{ev.attendee_count}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${
                          ev.status === 'upcoming' ? 'bg-mn-elevated text-mn-leben' :
                          ev.status === 'ongoing' ? 'bg-mn-elevated text-mn-teal-soft' :
                          ev.status === 'completed' ? 'bg-mn-elevated text-mn-ink-soft' :
                          'bg-mn-elevated text-mn-herzrot'
                        }`}>{ev.status}</span>
                      </td>
                      <td className="px-4 py-3 text-mn-mute text-xs">{(ev.profiles as any)?.name ?? '-'}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <button onClick={() => openEdit(ev)}
                            className="p-1.5 rounded-lg text-mn-mute hover:text-mn-teal-soft hover:bg-mn-surface transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(ev.id, ev.title)}
                            className="p-1.5 rounded-lg text-mn-mute hover:text-mn-herzrot hover:bg-mn-surface transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {events.length === 0 && (
                    <tr><td colSpan={7} className="px-4 py-12 text-center text-mn-mute">Keine Events gefunden</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={events.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-mn-ink-soft hover:text-mn-ink disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Edit Modal ── */}
      {editEvent && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-mn-elevated rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-mn-ink flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-mn-teal-soft" /> Event bearbeiten
              </h3>
              <button onClick={() => setEditEvent(null)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-mn-elevated text-mn-mute">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-mn-mute mb-1">Titel</label>
                <input value={editTitle} onChange={e => setEditTitle(e.target.value)}
                  className="w-full px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-mn-mute mb-1">Status</label>
                <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                  <option value="upcoming">Geplant</option>
                  <option value="ongoing">Laufend</option>
                  <option value="completed">Abgeschlossen</option>
                  <option value="cancelled">Abgesagt</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditEvent(null)} className="flex-1 px-4 py-2.5 bg-mn-elevated text-mn-ink-soft rounded-xl text-sm font-semibold hover:bg-mn-raised transition-colors">
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
