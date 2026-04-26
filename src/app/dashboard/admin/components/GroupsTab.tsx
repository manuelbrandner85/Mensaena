'use client'

import { Fragment, useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, Edit3,
  X, Save, Loader2, Users, Lock, Globe, ChevronDown, ChevronUp
} from 'lucide-react'
import type { AdminGroup, AdminGroupMember } from './AdminTypes'
import ConfirmDialog from './ConfirmDialog'

const PAGE_SIZE = 20

// Must match the DB CHECK constraint: groups_category_check
const CATEGORY_LABELS: Record<string, string> = {
  nachbarschaft: 'Nachbarschaft',
  hobby:         'Hobby',
  hilfe:         'Hilfe',
  projekt:       'Projekt',
  sonstiges:     'Sonstiges',
}

export default function GroupsTab() {
  const [groups, setGroups]   = useState<AdminGroup[]>([])
  const [search, setSearch]   = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage]       = useState(0)
  const [total, setTotal]     = useState(0)
  const [expanded, setExpanded] = useState<string | null>(null)
  const [members, setMembers]   = useState<Record<string, AdminGroupMember[]>>({})

  // Confirm delete
  const [confirmDelete, setConfirmDelete] = useState<AdminGroup | null>(null)

  // Edit state
  const [editGroup, setEditGroup]   = useState<AdminGroup | null>(null)
  const [editName, setEditName]     = useState('')
  const [editDesc, setEditDesc]     = useState('')
  const [editCat, setEditCat]       = useState('')
  const [editSaving, setEditSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    let query = supabase
      .from('groups')
      .select('id,name,slug,description,category,is_private,member_count,post_count,creator_id,created_at,profiles!creator_id(name)', { count: 'exact' })

    if (search) query = query.ilike('name', `%${search}%`)

    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)

    setGroups((data ?? []) as unknown as AdminGroup[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, page])

  useEffect(() => { load() }, [load])

  const loadMembers = async (groupId: string) => {
    if (members[groupId]) return // already loaded
    const supabase = createClient()
    const { data } = await supabase
      .from('group_members')
      .select('id,group_id,user_id,role,joined_at,profiles(name,email)')
      .eq('group_id', groupId)
      .order('joined_at', { ascending: false })
    setMembers(prev => ({ ...prev, [groupId]: (data ?? []) as unknown as AdminGroupMember[] }))
  }

  const toggleExpand = (groupId: string) => {
    if (expanded === groupId) {
      setExpanded(null)
    } else {
      setExpanded(groupId)
      loadMembers(groupId)
    }
  }

  const handleRemoveMember = async (groupId: string, memberId: string, userName: string | null) => {
    const supabase = createClient()
    const { error } = await supabase.from('group_members').delete().eq('id', memberId)
    if (error) { toast.error('Entfernen fehlgeschlagen'); return }
    toast.success(`${userName ?? 'Mitglied'} entfernt`)
    setMembers(prev => ({
      ...prev,
      [groupId]: prev[groupId]?.filter(m => m.id !== memberId) ?? [],
    }))
    setGroups(prev => prev.map(g => g.id === groupId ? { ...g, member_count: Math.max(0, g.member_count - 1) } : g))
  }

  const openEdit = (g: AdminGroup) => {
    setEditGroup(g)
    setEditName(g.name)
    setEditDesc(g.description ?? '')
    setEditCat(g.category)
  }

  const handleSaveEdit = async () => {
    if (!editGroup) return
    setEditSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('groups').update({
      name: editName.trim(),
      description: editDesc.trim() || null,
      category: editCat,
    }).eq('id', editGroup.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving(false); return }
    toast.success('Gruppe aktualisiert')
    setGroups(prev => prev.map(g => g.id === editGroup.id
      ? { ...g, name: editName.trim(), description: editDesc.trim() || null, category: editCat }
      : g
    ))
    setEditGroup(null)
    setEditSaving(false)
  }

  const handleDeleteGroup = async () => {
    if (!confirmDelete) return
    const supabase = createClient()
    const { error } = await supabase.from('groups').delete().eq('id', confirmDelete.id)
    if (error) { toast.error('Löschen fehlgeschlagen: ' + error.message); setConfirmDelete(null); return }
    toast.success('Gruppe gelöscht')
    setGroups(prev => prev.filter(g => g.id !== confirmDelete.id))
    setTotal(prev => prev - 1)
    setConfirmDelete(null)
  }

  const getProfileName = (g: AdminGroup) => {
    const p = g.profiles
    if (!p) return null
    if (Array.isArray(p)) return (p[0] as { name: string | null } | undefined)?.name ?? null
    return (p as { name: string | null }).name ?? null
  }

  return (
    <div className="space-y-4">
      {/* Search */}
      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
        <input
          type="text" value={search}
          onChange={e => { setSearch(e.target.value); setPage(0) }}
          placeholder="Gruppe suchen..."
          className="w-full pl-9 pr-4 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
        />
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-ink-500">{total} Gruppen gesamt</p>
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-stone-50 border-b border-stone-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Gruppe</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Kategorie</th>
                    <th className="text-center px-4 py-3 font-semibold text-ink-700">Mitglieder</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Ersteller</th>
                    <th className="text-left px-4 py-3 font-semibold text-ink-700">Erstellt</th>
                    <th className="text-right px-4 py-3 font-semibold text-ink-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {groups.map(g => (
                    <Fragment key={g.id}>
                      <tr className="hover:bg-stone-50 transition-colors">
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            {g.is_private
                              ? <Lock className="w-3.5 h-3.5 text-ink-400 shrink-0" />
                              : <Globe className="w-3.5 h-3.5 text-primary-500 shrink-0" />}
                            <div>
                              <p className="font-medium text-ink-900">{g.name}</p>
                              <p className="text-xs text-ink-400">/{g.slug}</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-ink-600 text-xs">
                          {CATEGORY_LABELS[g.category] ?? g.category}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="inline-flex items-center gap-1 text-xs font-medium text-ink-700">
                            <Users className="w-3 h-3 text-primary-500" />
                            {g.member_count}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-ink-500 text-xs">
                          {getProfileName(g) ?? g.creator_id.slice(0, 8)}
                        </td>
                        <td className="px-4 py-3 text-ink-500 text-xs">
                          {new Date(g.created_at).toLocaleDateString('de-AT')}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center gap-1 justify-end">
                            <button onClick={() => toggleExpand(g.id)}
                              className="p-1.5 rounded-lg text-ink-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
                              title="Mitglieder anzeigen">
                              {expanded === g.id ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </button>
                            <button onClick={() => openEdit(g)}
                              className="p-1.5 rounded-lg text-ink-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                              title="Bearbeiten">
                              <Edit3 className="w-4 h-4" />
                            </button>
                            <button onClick={() => setConfirmDelete(g)}
                              className="p-1.5 rounded-lg text-ink-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                              title="Gruppe löschen">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                      {/* Members sub-row */}
                      {expanded === g.id && (
                        <tr className="bg-stone-50">
                          <td colSpan={6} className="px-6 py-3">
                            <p className="text-xs font-semibold text-ink-500 mb-2">Mitglieder ({members[g.id]?.length ?? '…'})</p>
                            {!members[g.id] ? (
                              <div className="flex items-center gap-2 text-xs text-ink-400">
                                <Loader2 className="w-3 h-3 animate-spin" /> Lädt…
                              </div>
                            ) : members[g.id].length === 0 ? (
                              <p className="text-xs text-ink-400">Keine Mitglieder</p>
                            ) : (
                              <div className="flex flex-wrap gap-2">
                                {members[g.id].map(m => {
                                  const mName = Array.isArray(m.profiles)
                                    ? (m.profiles[0] as { name: string | null } | undefined)?.name
                                    : (m.profiles as { name: string | null } | undefined)?.name
                                  return (
                                    <div key={m.id} className="flex items-center gap-1.5 bg-white border border-stone-200 rounded-lg px-2.5 py-1 text-xs">
                                      <span className="font-medium text-ink-700">{mName ?? m.user_id.slice(0, 8)}</span>
                                      {m.role !== 'member' && (
                                        <span className="bg-primary-100 text-primary-700 px-1.5 rounded-full text-[10px]">{m.role}</span>
                                      )}
                                      <button
                                        onClick={() => handleRemoveMember(g.id, m.id, mName ?? null)}
                                        className="ml-1 text-stone-400 hover:text-red-500 transition-colors"
                                        title="Mitglied entfernen"
                                      >
                                        <X className="w-3 h-3" />
                                      </button>
                                    </div>
                                  )
                                })}
                              </div>
                            )}
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  ))}
                  {groups.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-ink-400">Keine Gruppen gefunden</td></tr>
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
            <button onClick={() => setPage(p => p + 1)} disabled={groups.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-ink-600 hover:text-ink-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* Edit Modal */}
      {editGroup && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-ink-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Gruppe bearbeiten
              </h3>
              <button onClick={() => setEditGroup(null)} aria-label="Schließen" className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-500">
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
                <label className="block text-xs font-semibold text-ink-500 mb-1">Beschreibung</label>
                <textarea value={editDesc} onChange={e => setEditDesc(e.target.value)} rows={3}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300 resize-none" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-ink-500 mb-1">Kategorie</label>
                <select value={editCat} onChange={e => setEditCat(e.target.value)}
                  className="w-full px-3 py-2 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  {Object.entries(CATEGORY_LABELS).map(([v, l]) => (
                    <option key={v} value={v}>{l}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditGroup(null)}
                className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 rounded-xl text-sm font-semibold hover:bg-stone-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleSaveEdit} disabled={editSaving || !editName.trim()}
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
        title="Gruppe löschen"
        message={`Gruppe "${confirmDelete?.name}" wirklich löschen? Alle Beiträge und Mitgliedschaften werden entfernt.`}
        confirmLabel="Löschen"
        onConfirm={handleDeleteGroup}
        onCancel={() => setConfirmDelete(null)}
      />
    </div>
  )
}
