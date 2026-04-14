'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { Search, ChevronLeft, ChevronRight, Trash2, Building2, Edit3, X, Save, Loader2, PlusCircle } from 'lucide-react'
import type { AdminOrg } from './AdminTypes'

const PAGE_SIZE = 20

// Must match DB CHECK constraint: organizations_category_check
const CATEGORY_LABELS: Record<string, string> = {
  tierheim:         'Tierheim',
  tierschutz:       'Tierschutz',
  suppenkueche:     'Suppenküche',
  obdachlosenhilfe: 'Obdachlosenhilfe',
  tafel:            'Tafel',
  kleiderkammer:    'Kleiderkammer',
  sozialkaufhaus:   'Sozialkaufhaus',
  krisentelefon:    'Krisentelefon',
  notschlafstelle:  'Notschlafstelle',
  jugend:           'Jugend',
  senioren:         'Senioren',
  behinderung:      'Behinderung',
  sucht:            'Sucht',
  fluechtlingshilfe:'Flüchtlingshilfe',
  allgemein:        'Allgemein',
}

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
      .select('id,name,category,is_verified,is_active,created_at', { count: 'exact' })
    if (search) query = query.ilike('name', `%${search}%`)
    if (verifiedFilter === 'true') query = query.eq('is_verified', true)
    if (verifiedFilter === 'false') query = query.eq('is_verified', false)
    const { data, count } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
    setOrgs((data ?? []) as AdminOrg[])
    setTotal(count ?? 0)
    setLoading(false)
  }, [search, verifiedFilter, page])

  useEffect(() => { load() }, [load])

  // ── Edit State ──
  const [editOrg, setEditOrg] = useState<AdminOrg | null>(null)
  const [editName, setEditName] = useState('')
  const [editCategory, setEditCategory] = useState('')
  const [editSaving, setEditSaving] = useState(false)

  // ── Create State ──
  const [showCreate, setShowCreate] = useState(false)
  const [newName, setNewName] = useState('')
  const [newCategory, setNewCategory] = useState('')

  const [creating, setCreating] = useState(false)

  const openEdit = (o: AdminOrg) => {
    setEditOrg(o)
    setEditName(o.name)
    setEditCategory(o.category ?? '')
  }

  const handleSaveEdit = async () => {
    if (!editOrg) return
    setEditSaving(true)
    const supabase = createClient()
    const updates: Record<string, string> = {}
    if (editName !== editOrg.name) updates.name = editName
    if (editCategory !== (editOrg.category ?? '')) updates.category = editCategory
    if (Object.keys(updates).length === 0) { setEditOrg(null); setEditSaving(false); return }
    const { error } = await supabase.from('organizations').update(updates).eq('id', editOrg.id)
    if (error) { toast.error('Speichern fehlgeschlagen: ' + error.message); setEditSaving(false); return }
    toast.success('Organisation aktualisiert')
    setOrgs(prev => prev.map(o => o.id === editOrg.id ? { ...o, ...updates } : o))
    setEditOrg(null)
    setEditSaving(false)
  }

  const handleCreate = async () => {
    if (!newName.trim()) { toast.error('Name ist erforderlich'); return }
    setCreating(true)
    const supabase = createClient()
    const { data, error } = await supabase.from('organizations')
      .insert({ name: newName.trim(), category: newCategory || null, is_verified: false })
      .select()
      .single()
    if (error) { toast.error('Erstellen fehlgeschlagen: ' + error.message); setCreating(false); return }
    toast.success('Organisation erstellt')
    setOrgs(prev => [data as AdminOrg, ...prev])
    setTotal(prev => prev + 1)
    setShowCreate(false)
    setNewName('')
    setNewCategory('')
    setCreating(false)
  }

  const handleToggleVerified = async (id: string, current: boolean) => {
    const supabase = createClient()
    const { error } = await supabase.from('organizations').update({ is_verified: !current }).eq('id', id)
    if (error) { toast.error('Update fehlgeschlagen'); return }
    toast.success(current ? 'Verifizierung entfernt' : 'Verifiziert')
    setOrgs(prev => prev.map(o => o.id === id ? { ...o, is_verified: !current } : o))
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Organisation "${name}" löschen?`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_organization', { p_organization_id: id })
    if (error) {
      const { error: e2 } = await supabase.from('organizations').delete().eq('id', id)
      if (e2) { toast.error('Löschen fehlgeschlagen'); return }
    }
    toast.success('Organisation gelöscht')
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
        <button onClick={() => setShowCreate(true)}
          className="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700 transition-colors">
          <PlusCircle className="w-4 h-4" /> Neue Organisation
        </button>
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
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
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
                      <td className="px-4 py-3 text-gray-600 text-xs">{o.category ? (CATEGORY_LABELS[o.category] ?? o.category) : '-'}</td>
                      <td className="px-4 py-3 text-center">
                        <button onClick={() => handleToggleVerified(o.id, o.is_verified)}
                          className={`w-10 h-5 rounded-full transition-all relative ${o.is_verified ? 'bg-green-500' : 'bg-gray-300'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${o.is_verified ? 'left-5' : 'left-0.5'}`} />
                        </button>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${o.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                          {o.is_active ? 'Aktiv' : 'Inaktiv'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{new Date(o.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <button onClick={() => openEdit(o)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Bearbeiten">
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button onClick={() => handleDelete(o.id, o.name)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
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
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={orgs.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
      {/* ── Edit Modal ── */}
      {editOrg && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-blue-500" /> Organisation bearbeiten
              </h3>
              <button onClick={() => setEditOrg(null)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Name</label>
                <input value={editName} onChange={e => setEditName(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Kategorie</label>
                <select value={editCategory} onChange={e => setEditCategory(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300">
                  <option value="">— bitte wählen —</option>
                  {Object.entries(CATEGORY_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setEditOrg(null)} className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
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

      {/* ── Create Modal ── */}
      {showCreate && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <PlusCircle className="w-5 h-5 text-green-500" /> Neue Organisation
              </h3>
              <button onClick={() => setShowCreate(false)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Name *</label>
                <input value={newName} onChange={e => setNewName(e.target.value)}
                  placeholder="Organisation Name"
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Kategorie</label>
                <select value={newCategory} onChange={e => setNewCategory(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300">
                  <option value="">— bitte wählen —</option>
                  {Object.entries(CATEGORY_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setShowCreate(false)} className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleCreate} disabled={creating}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700 transition-colors disabled:opacity-50">
                {creating ? <Loader2 className="w-4 h-4 animate-spin" /> : <PlusCircle className="w-4 h-4" />}
                Erstellen
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
