'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Users, Plus, Search, X, Lock, Globe, UserPlus, UserMinus,
  MessageCircle, Image as ImageIcon, ChevronRight, Shield, Crown,
  Settings, LogOut as Leave, Loader2,
} from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ──────────────────────────────────────────────────────
interface Group {
  id: string
  name: string
  slug: string
  description: string | null
  category: string
  is_private?: boolean
  is_public?: boolean
  image_url?: string | null
  cover_image_url?: string | null
  member_count: number
  post_count?: number
  created_at: string
  creator_id?: string
  created_by?: string
}

interface GroupMember {
  group_id: string
  user_id: string
  role: string
  joined_at: string
}

// ── Category Config ─────────────────────────────────────────────
const GROUP_CATEGORIES = [
  { value: 'nachbarschaft', label: '🏘️ Nachbarschaft' },
  { value: 'hobby', label: '🎨 Hobby & Freizeit' },
  { value: 'sport', label: '⚽ Sport & Fitness' },
  { value: 'eltern', label: '👶 Eltern & Familie' },
  { value: 'senioren', label: '🧓 Senioren' },
  { value: 'umwelt', label: '🌿 Umwelt & Nachhaltigkeit' },
  { value: 'bildung', label: '📚 Bildung & Lernen' },
  { value: 'tiere', label: '🐾 Tiere' },
  { value: 'handwerk', label: '🔧 Handwerk & DIY' },
  { value: 'sonstiges', label: '💬 Sonstiges' },
]

const catEmoji: Record<string, string> = {
  nachbarschaft: '🏘️', hobby: '🎨', sport: '⚽', eltern: '👶',
  senioren: '🧓', umwelt: '🌿', bildung: '📚', tiere: '🐾',
  handwerk: '🔧', sonstiges: '💬',
}

// ── Create Group Modal ──────────────────────────────────────────
function CreateGroupModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [isPrivate, setIsPrivate] = useState(false)
  const [saving, setSaving] = useState(false)

  // Close on Escape
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const handleCreate = async () => {
    if (name.trim().length < 3) { toast.error('Name mindestens 3 Zeichen'); return }
    if (description.trim().length > 500) { toast.error('Beschreibung max. 500 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      // Rate-Limiting
      const allowed = await checkRateLimit(user.id, 'create_group', 2, 60)
      if (!allowed) { toast.error('Zu viele Gruppen in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      // Generate unique slug with timestamp to avoid collisions
      const baseSlug = name.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, '-').replace(/^-|-$/g, '')
      const slug = `${baseSlug}-${Date.now().toString(36)}`

      // Insert with both column variants for compatibility
      const insertData: Record<string, unknown> = {
        name: name.trim(),
        slug,
        description: description.trim() || null,
        category,
        is_private: isPrivate,
        is_public: !isPrivate,
        creator_id: user.id,
        created_by: user.id,
        member_count: 1,
        post_count: 0,
      }

      let result = await supabase.from('groups').insert(insertData).select('id').single()

      // Strip unknown columns and retry
      for (let attempt = 0; attempt < 5 && result.error?.message?.includes('column'); attempt++) {
        const colMatch = result.error.message.match(/column\s+["']?(\w+)["']?.*does not exist/i)
          || result.error.message.match(/Could not find.*column\s+["']?(\w+)["']?/i)
        if (!colMatch) break
        delete insertData[colMatch[1]]
        result = await supabase.from('groups').insert(insertData).select('id').single()
      }

      if (result.error) throw result.error

      // Auto-join as admin
      const groupId = result.data?.id
      if (groupId) {
        await supabase.from('group_members').insert({
          group_id: groupId,
          user_id: user.id,
          role: 'admin',
        })
      }

      toast.success('Gruppe erstellt!')
      onCreated()
      onClose()
    } catch (err: any) {
      console.error('Group create error:', err)
      if (err?.message?.includes('duplicate') || err?.code === '23505') {
        toast.error('Gruppenname existiert bereits')
      } else if (err?.message?.includes('permission') || err?.code === '42501') {
        toast.error('Keine Berechtigung. Bitte neu einloggen.')
      } else {
        toast.error('Fehler beim Erstellen: ' + (err?.message ?? 'Unbekannter Fehler'))
      }
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl animate-scale-in" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Users className="w-5 h-5 text-primary-600" /> Neue Gruppe erstellen
          </h2>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-xl transition-colors"><X className="w-5 h-5 text-gray-400" /></button>
        </div>

        <div className="space-y-4">
          {/* Rate-Limit Hinweis */}
          <div className="flex items-center gap-2 bg-primary-50 border border-primary-200 rounded-xl px-3 py-2">
            <Shield className="w-4 h-4 text-primary-500 flex-shrink-0" />
            <p className="text-xs text-primary-700">Max. <strong>2 Gruppen pro Stunde</strong> – Gruppen werden sofort sichtbar.</p>
          </div>
          <div>
            <label className="label">Gruppenname *</label>
            <input value={name} onChange={e => setName(e.target.value)} maxLength={60}
              className="input" placeholder="z.B. Nachbarschaftshilfe Mitte" />
            {name.trim().length > 0 && name.trim().length < 3 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 3 Zeichen nötig</p>
            )}
          </div>

          <div>
            <label className="label">Beschreibung <span className="font-normal text-gray-400">({description.length}/500)</span></label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={500}
              className="input resize-none" placeholder="Worum geht es in der Gruppe?" />
            {description.length > 450 && (
              <p className="text-xs text-amber-500 mt-1">{500 - description.length} Zeichen übrig</p>
            )}
          </div>

          <div>
            <label className="label">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {GROUP_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>

          <div className="flex items-center gap-3">
            <button onClick={() => setIsPrivate(!isPrivate)}
              className={cn('flex items-center gap-2 px-4 py-2 rounded-xl border transition-all',
                isPrivate ? 'bg-amber-50 border-amber-300 text-amber-700' : 'bg-green-50 border-green-300 text-green-700')}>
              {isPrivate ? <Lock className="w-4 h-4" /> : <Globe className="w-4 h-4" />}
              {isPrivate ? 'Privat' : 'Öffentlich'}
            </button>
            <span className="text-xs text-gray-500">
              {isPrivate ? 'Nur auf Einladung' : 'Jeder kann beitreten'}
            </span>
          </div>

          <button onClick={handleCreate} disabled={saving || name.trim().length < 3}
            className="w-full py-3 bg-gradient-to-r from-primary-500 to-teal-600 text-white rounded-xl font-semibold hover:shadow-lg disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-95">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Gruppe erstellen
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Group Card ──────────────────────────────────────────────────
function GroupCard({ group, isMember, onJoin, onLeave, userId }: {
  group: Group; isMember: boolean; onJoin: (id: string) => void; onLeave: (id: string) => void; userId?: string
}) {
  return (
    <div className="bg-white rounded-2xl border border-warm-200 p-4 hover:shadow-md transition-all group hover:-translate-y-[2px]">
      <div className="flex items-start gap-3">
        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary-400 to-teal-500 flex items-center justify-center text-white text-lg font-bold flex-shrink-0">
          {catEmoji[group.category] || '👥'}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <h3 className="font-bold text-gray-900 truncate">{group.name}</h3>
            {(group.is_private || group.is_public === false) && (
              <span className="inline-flex items-center gap-0.5 px-1.5 py-0.5 bg-amber-50 border border-amber-200 rounded-full text-[10px] font-semibold text-amber-600 flex-shrink-0">
                <Lock className="w-2.5 h-2.5" /> Privat
              </span>
            )}
          </div>
          {group.description && (
            <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{group.description}</p>
          )}
          <div className="flex items-center gap-3 mt-2 text-xs text-gray-400">
            <span className="flex items-center gap-1"><Users className="w-3 h-3" /> {group.member_count}</span>
            <span className="flex items-center gap-1"><MessageCircle className="w-3 h-3" /> {group.post_count ?? 0} Beiträge</span>
            <span className="capitalize">{catEmoji[group.category]} {group.category}</span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2 mt-3 pt-3 border-t border-warm-100">
        {isMember ? (
          <>
            <Link href={`/dashboard/groups/${group.id}`}
              className="flex-1 text-center py-1.5 bg-primary-50 text-primary-700 rounded-lg text-xs font-medium hover:bg-primary-100 transition-all flex items-center justify-center gap-1">
              <ChevronRight className="w-3.5 h-3.5" /> Öffnen
            </Link>
            <button onClick={() => onLeave(group.id)}
              className="py-1.5 px-3 bg-red-50 text-red-600 rounded-lg text-xs font-medium hover:bg-red-100 transition-all flex items-center gap-1">
              <Leave className="w-3.5 h-3.5" /> Verlassen
            </button>
          </>
        ) : (
          <button onClick={() => onJoin(group.id)}
            className="flex-1 py-1.5 bg-primary-600 text-white rounded-lg text-xs font-medium hover:bg-primary-700 transition-all flex items-center justify-center gap-1">
            <UserPlus className="w-3.5 h-3.5" /> Beitreten
          </button>
        )}
      </div>
    </div>
  )
}

// ── Main Groups Page ────────────────────────────────────────────
export default function GroupsPage() {
  const [groups, setGroups] = useState<Group[]>([])
  const [myMemberships, setMyMemberships] = useState<Set<string>>(new Set())
  const [userId, setUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterCat, setFilterCat] = useState('all')
  const [showCreate, setShowCreate] = useState(false)
  const [tab, setTab] = useState<'all' | 'mine'>('all')

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    const [groupsRes, membersRes] = await Promise.all([
      supabase.from('groups').select('*').order('member_count', { ascending: false }),
      user ? supabase.from('group_members').select('group_id').eq('user_id', user.id) : Promise.resolve({ data: [] }),
    ])

    setGroups(groupsRes.data ?? [])
    setMyMemberships(new Set((membersRes.data ?? []).map((m: any) => m.group_id)))
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

  const handleJoin = async (groupId: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    const supabase = createClient()
    const { error } = await supabase.from('group_members').insert({ group_id: groupId, user_id: userId, role: 'member' })
    if (error) {
      if (error.code === '23505') toast.error('Du bist bereits Mitglied')
      else toast.error('Fehler beim Beitreten: ' + error.message)
      return
    }
    // member_count wird automatisch per DB-Trigger aktualisiert
    toast.success('Gruppe beigetreten!')
    loadData()
  }

  const handleLeave = async (groupId: string) => {
    if (!userId) return
    const group = groups.find(g => g.id === groupId)
    const creatorId = group?.creator_id || group?.created_by
    if (creatorId === userId) { toast.error('Ersteller kann die Gruppe nicht verlassen'); return }
    if (!confirm('Gruppe wirklich verlassen?')) return
    const supabase = createClient()
    const { error } = await supabase.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId)
    if (error) { toast.error('Fehler beim Verlassen'); return }
    // member_count wird automatisch per DB-Trigger aktualisiert
    toast.success('Gruppe verlassen')
    loadData()
  }

  const filtered = groups.filter(g => {
    if (tab === 'mine' && !myMemberships.has(g.id)) return false
    if (filterCat !== 'all' && g.category !== filterCat) return false
    if (searchTerm && !g.name.toLowerCase().includes(searchTerm.toLowerCase()) &&
        !(g.description ?? '').toLowerCase().includes(searchTerm.toLowerCase())) return false
    return true
  })

  return (
    <div className="min-h-screen bg-gradient-to-b from-primary-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-primary-500 to-teal-600 text-white px-4 sm:px-6 py-8 shadow-soft">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm"><Users className="w-6 h-6" /></div>
            <h1 className="text-2xl font-bold tracking-tight">Gruppen</h1>
          </div>
          <p className="text-primary-100 text-sm">Schließe dich Gruppen an, tausche dich aus und organisiere gemeinsame Aktivitäten</p>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 -mt-4">
        {/* Action Bar */}
        <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="input pl-10 py-2.5"
                placeholder="Gruppen suchen..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
              className="input w-auto min-w-[160px]">
              <option value="all">Alle Kategorien</option>
              {GROUP_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
            <button onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary-500 to-teal-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 flex-shrink-0">
              <Plus className="w-4 h-4" /> Neue Gruppe
            </button>
          </div>

          {/* Tabs */}
          <div className="flex gap-1 mt-3 bg-gray-50 rounded-xl p-1">
            {[
              { key: 'all' as const, label: 'Alle Gruppen', count: groups.length },
              { key: 'mine' as const, label: 'Meine Gruppen', count: myMemberships.size },
            ].map(t => (
              <button key={t.key} onClick={() => setTab(t.key)}
                className={cn('flex-1 py-1.5 rounded-lg text-xs font-medium transition-all',
                  tab === t.key ? 'bg-white text-primary-700 shadow-sm' : 'text-gray-500 hover:text-gray-700')}>
                {t.label} ({t.count})
              </button>
            ))}
          </div>
        </div>

        {/* Groups Grid */}
        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {[1, 2, 3, 4].map(i => <div key={i} className="h-40 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl border border-warm-200 shadow-sm">
            <Users className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-700 font-bold text-lg">{tab === 'mine' ? 'Du bist noch keiner Gruppe beigetreten' : 'Keine Gruppen gefunden'}</p>
            <p className="text-sm text-gray-500 mt-1 mb-4">Starte die Gemeinschaft mit einer neuen Gruppe</p>
            <button onClick={() => setShowCreate(true)}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary-500 to-teal-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95">
              <Plus className="w-4 h-4" /> Erste Gruppe erstellen
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-8">
            {filtered.map(g => (
              <GroupCard key={g.id} group={g} isMember={myMemberships.has(g.id)}
                onJoin={handleJoin} onLeave={handleLeave} userId={userId} />
            ))}
          </div>
        )}
      </div>

      {showCreate && <CreateGroupModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
