'use client'

import { Fragment, useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Edit3,
  X, Save, Loader2, Target, Users, ChevronDown, ChevronUp, Plus
} from 'lucide-react'
import type { AdminChallenge, AdminChallengeProgress } from './AdminTypes'
import ConfirmDialog from './ConfirmDialog'

const PAGE_SIZE = 20

const DIFFICULTY_COLORS: Record<string, string> = {
  leicht: 'bg-green-100 text-green-700',
  mittel: 'bg-amber-100 text-amber-700',
  schwer: 'bg-red-100 text-red-700',
}

const STATUS_COLORS: Record<string, string> = {
  active:    'bg-green-100 text-green-700',
  completed: 'bg-blue-100 text-blue-700',
  cancelled: 'bg-gray-100 text-gray-600',
  draft:     'bg-gray-100 text-gray-500',
}

const STATUS_LABELS: Record<string, string> = {
  active: 'Aktiv', completed: 'Abgeschlossen', cancelled: 'Abgebrochen', draft: 'Entwurf',
}

const CATEGORY_LABELS: Record<string, string> = {
  umwelt: 'Umwelt', soziales: 'Soziales', gesundheit: 'Gesundheit',
  bildung: 'Bildung', kreativ: 'Kreativ', sport: 'Sport', sonstiges: 'Sonstiges',
}

export default function ChallengesTab() {
  const [challenges, setChallenges] = useState<AdminChallenge[]>([])
  const [search, setSearch]         = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [loading, setLoading]       = useState(true)
  const [page, setPage]             = useState(0)
  const [total, setTotal]           = useState(0)
  const [expanded, setExpanded]     = useState<string | null>(null)
  const [participants, setParticipants] = useState<Record<string, AdminChallengeProgress[]>>({})

  // Create state
  const [showCreate, setShowCreate] = useState(false)
  const [newTitle, setNewTitle]     = useState('')
  const [newDesc, setNewDesc]       = useState('')
  const [newCat, setNewCat]         = useState('umwelt')
  const [newDiff, setNewDiff]       = useState('mittel')
  const [newPoints, setNewPoints]   = useState(50)
  const [newEndDate, setNewEndDate] = useState('')
  const [creating, setCreating]     = useState(false)

  // Edit state
  const [editChallenge, setEditChallenge] = useState<AdminChallenge | null>(null)
  const [editTitle, setEditTitle]         = useState('')
  const [editDesc, setEditDesc]           = useState('')
  const [editStatus, setEditStatus]       = useState('')
  const [editSaving, setEditSaving]       = useState(false)

  // Confirm delete
  const [confirmDelete, setConfirmDelete] = useState<AdminChallenge | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase
      .from('challenges')
      .select('id,title,description,category,difficulty,points,max_participants,participant_count,start_date,end_date,status,creator_id,created_at,profiles!creator_id(name)', { count: 'exact' })

    if (search)       query = query.ilike('title', `%${search}%`)
    if (statusFilter) query = query.eq('status', statusFilter)

    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)

    setChallenges((data ?? []) as unknown as AdminChallenge[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, statusFilter, page])

  useEffect(() => { load() }, [load])

  const loadParticipants = async (challengeId: string) => {
    if (participants[challengeId]) return
    const supabase = createClient()
    const { data } = await supabase
      .from('challenge_progress')
      .select('id,challenge_id,user_id,status,progress_pct,completed_at,joined_at,profiles(name,email)')
      .eq('challenge_id', challengeId)
      .order('joined_at', { ascending: false })
    setParticipants(prev => ({ ...prev, [challengeId]: (data ?? []) as unknown as AdminChallengeProgress[] }))
  }

  const toggleExpand = (id: string) => {
    if (expanded === id) {
      setExpanded(null)
    } else {
      setExpanded(id)
      loadParticipants(id)
    }
  }

  const handleCreate = async () => {
    if (!newTitle.trim() || !newEndDate) return
    setCreating(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { toast.error('Nicht angemeldet'); setCreating(false); return }
    const { error } = await supabase.from('challenges').insert({
      title: newTitle.trim(),
      description: newDesc.trim() || null,
      category: newCat,
      difficulty: newDiff,
      points: newPoints,
      end_date: new Date(newEndDate).toISOString(),
      creator_id: user.id,
      status: 'active',
    })
    if (error) { toast.error('Erstellen fehlgeschlagen: ' + error.message); setCreating(false); return }
    toast.success('Challenge erstellt')
    setShowCreate(false)
    setNewTitle(''); setNewDesc(''); setNewEndDate('')
    setCreating(false)
    load()
  }

  const openEdit = (c: AdminChallenge) => {
    setEditChallenge(c)
    setEditTitle(c.title)
    setEditDesc(c.description ?? '')
    setEditStatus(c.status)
  }

  const handleSaveEdit = async () => {
    if (!editChallenge) return
    setEditSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('challenges').update({
      title:  editTitle.trim(),
      description: editDesc.trim() || null,
      status: editStatus,
    }).eq('id', editChallenge.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving(false); return }
    toast.success('Challenge aktualisiert')
    setChallenges(prev => prev.map(c => c.id === editChallenge.id
      ? { ...c, title: editTitle.trim(), description: editDesc.trim() || null, status: editStatus }
      : c
    ))
    setEditChallenge(null)
    setEditSaving(false)
  }

  const handleDelete = async () => {
    if (!confirmDelete) return
    const supabase = createClient()
    const { error } = await supabase.from('challenges').delete().eq('id', confirmDelete.id)
    if (error) { toast.error('Löschen fehlgeschlagen: ' + error.message); setConfirmDelete(null); return }
    toast.success('Challenge gelöscht')
    setChallenges(prev => prev.filter(c => c.id !== confirmDelete.id))
    setTotal(prev => prev - 1)
    setConfirmDelete(null)
  }

  const getCreatorName = (c: AdminChallenge) => {
    const p = c.profiles
    if (!p) return null
    if (Array.isArray(p)) return (p[0] as { name: string | null } | undefined)?.name ?? null
    return (p as { name: string | null }).name ?? null
  }

  const getParticipantName = (p: AdminChallengeProgress) => {
    const pr = p.profiles
    if (!pr) return p.user_id.slice(0, 8)
    if (Array.isArray(pr)) return (pr[0] as { name: string | null } | undefined)?.name ?? p.user_id.slice(0, 8)
    return (pr as { name: string | null }).name ?? p.user_id.slice(0, 8)
  }

  return (
    <div className="space-y-4">
      {/* Filters + Create */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Challenge suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
          <option value="">Alle Status</option>
          {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <button onClick={() => setShowCreate(true)}
          className="flex items-center gap-1.5 px-4 py-2.5 bg-primary-600 text-white rounded-xl text-sm font-semibold hover:bg-primary-700 transition-colors">
          <Plus className="w-4 h-4" /> Neue Challenge
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Challenges gesamt</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Challenge</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Kategorie</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Teilnehmer</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Endet</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {challenges.map(c => (
                    <Fragment key={c.id}>
                      <tr className="hover:bg-gray-50 transition-colors">
                        <td className="px-4 py-3">
                          <p className="font-medium text-gray-900">{c.title}</p>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className={`inline-block px-1.5 py-0.5 rounded-full text-[10px] font-semibold ${DIFFICULTY_COLORS[c.difficulty] ?? 'bg-gray-100 text-gray-600'}`}>
                              {c.difficulty}
                            </span>
                            <span className="text-xs text-amber-600 font-medium">{c.points} Pkt.</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-gray-600 text-xs">{CATEGORY_LABELS[c.category] ?? c.category}</td>
                        <td className="px-4 py-3 text-center">
                          <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[c.status] ?? 'bg-gray-100 text-gray-600'}`}>
                            {STATUS_LABELS[c.status] ?? c.status}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="inline-flex items-center gap-1 text-xs font-medium text-gray-700">
                            <Users className="w-3 h-3 text-primary-500" />
                            {c.participant_count}
                            {c.max_participants ? `/${c.max_participants}` : ''}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-gray-500 text-xs">
                          {new Date(c.end_date).toLocaleDateString('de-AT')}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center gap-1 justify-end">
                            <button onClick={() => toggleExpand(c.id)}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
                              title="Teilnehmer anzeigen">
                              {expanded === c.id ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </button>
                            <button onClick={() => openEdit(c)}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                              title="Bearbeiten">
                              <Edit3 className="w-4 h-4" />
                            </button>
                            <button onClick={() => setConfirmDelete(c)}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                              title="Löschen">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                      {/* Participants sub-row */}
                      {expanded === c.id && (
                        <tr className="bg-gray-50">
                          <td colSpan={6} className="px-6 py-3">
                            <p className="text-xs font-semibold text-gray-500 mb-2">Teilnehmer</p>
                            {!participants[c.id] ? (
                              <div className="flex items-center gap-2 text-xs text-gray-400">
                                <Loader2 className="w-3 h-3 animate-spin" /> Lädt…
                              </div>
                            ) : participants[c.id].length === 0 ? (
                              <p className="text-xs text-gray-400">Keine Teilnehmer</p>
                            ) : (
                              <div className="flex flex-wrap gap-2">
                                {participants[c.id].map(p => (
                                  <div key={p.id} className="flex items-center gap-1.5 bg-white border border-gray-200 rounded-lg px-2.5 py-1 text-xs">
                                    <span className="font-medium text-gray-700">{getParticipantName(p)}</span>
                                    <span className="text-gray-400">{p.progress_pct}%</span>
                                    {p.status === 'completed' && (
                                      <span className="bg-green-100 text-green-700 px-1.5 rounded-full text-[10px]">✓</span>
                                    )}
                                  </div>
                                ))}
                              </div>
                            )}
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  ))}
                  {challenges.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-gray-400">Keine Challenges gefunden</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={challenges.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* Create Modal */}
      {showCreate && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Target className="w-5 h-5 text-primary-500" /> Neue Challenge
              </h3>
              <button onClick={() => setShowCreate(false)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Titel *</label>
                <input value={newTitle} onChange={e => setNewTitle(e.target.value)}
                  placeholder="Challenge-Titel..."
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Beschreibung</label>
                <textarea value={newDesc} onChange={e => setNewDesc(e.target.value)} rows={2}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 resize-none" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Kategorie</label>
                  <select value={newCat} onChange={e => setNewCat(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                    {Object.entries(CATEGORY_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Schwierigkeit</label>
                  <select value={newDiff} onChange={e => setNewDiff(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                    <option value="leicht">Leicht</option>
                    <option value="mittel">Mittel</option>
                    <option value="schwer">Schwer</option>
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Punkte</label>
                  <input type="number" value={newPoints} onChange={e => setNewPoints(Number(e.target.value))} min={1}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300" />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Enddatum *</label>
                  <input type="date" value={newEndDate} onChange={e => setNewEndDate(e.target.value)}
                    min={new Date().toISOString().split('T')[0]}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300" />
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setShowCreate(false)}
                className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleCreate} disabled={creating || !newTitle.trim() || !newEndDate}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-primary-600 text-white rounded-xl text-sm font-semibold hover:bg-primary-700 transition-colors disabled:opacity-50">
                {creating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
                Erstellen
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editChallenge && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Challenge bearbeiten
              </h3>
              <button onClick={() => setEditChallenge(null)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
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
                <label className="block text-xs font-semibold text-gray-500 mb-1">Beschreibung</label>
                <textarea value={editDesc} onChange={e => setEditDesc(e.target.value)} rows={3}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300 resize-none" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Status</label>
                <select value={editStatus} onChange={e => setEditStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditChallenge(null)}
                className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving || !editTitle.trim()}
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
        title="Challenge löschen"
        message={`Challenge "${confirmDelete?.title}" wirklich löschen? Alle Fortschritte der Teilnehmer werden entfernt.`}
        confirmLabel="Löschen"
        onConfirm={handleDelete}
        onCancel={() => setConfirmDelete(null)}
      />
    </div>
  )
}
