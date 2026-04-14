'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Users, Plus, Search, X, Lock, Globe, UserPlus,
  MessageCircle, Shield, Crown, LogOut as Leave, Loader2, Filter,
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

// ── Category Config ─────────────────────────────────────────────
const GROUP_CATEGORIES = [
  { value: 'nachbarschaft', label: 'Nachbarschaft', emoji: '🏘️', color: 'from-blue-400 to-blue-600' },
  { value: 'hobby',         label: 'Hobby & Freizeit', emoji: '🎨', color: 'from-pink-400 to-rose-500' },
  { value: 'sport',         label: 'Sport & Fitness', emoji: '⚽', color: 'from-orange-400 to-orange-600' },
  { value: 'eltern',        label: 'Eltern & Familie', emoji: '👶', color: 'from-yellow-400 to-amber-500' },
  { value: 'senioren',      label: 'Senioren', emoji: '🧓', color: 'from-purple-400 to-purple-600' },
  { value: 'umwelt',        label: 'Umwelt & Nachhaltigkeit', emoji: '🌿', color: 'from-green-400 to-green-600' },
  { value: 'bildung',       label: 'Bildung & Lernen', emoji: '📚', color: 'from-indigo-400 to-indigo-600' },
  { value: 'tiere',         label: 'Tiere', emoji: '🐾', color: 'from-amber-400 to-yellow-600' },
  { value: 'handwerk',      label: 'Handwerk & DIY', emoji: '🔧', color: 'from-slate-400 to-slate-600' },
  { value: 'sonstiges',     label: 'Sonstiges', emoji: '💬', color: 'from-primary-400 to-teal-600' },
]

function getCatConfig(category: string) {
  return GROUP_CATEGORIES.find(c => c.value === category) ?? GROUP_CATEGORIES[GROUP_CATEGORIES.length - 1]
}

// ── Create Group Modal ──────────────────────────────────────────
function CreateGroupModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [isPrivate, setIsPrivate] = useState(false)
  const [saving, setSaving] = useState(false)

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

      const allowed = await checkRateLimit(user.id, 'create_group', 2, 60)
      if (!allowed) { toast.error('Zu viele Gruppen in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const baseSlug = name.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, '-').replace(/^-|-$/g, '')
      const slug = `${baseSlug}-${Date.now().toString(36)}`

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

      for (let attempt = 0; attempt < 5 && result.error?.message?.includes('column'); attempt++) {
        const colMatch = result.error.message.match(/column\s+["']?(\w+)["']?.*does not exist/i)
          || result.error.message.match(/Could not find.*column\s+["']?(\w+)["']?/i)
        if (!colMatch) break
        delete insertData[colMatch[1]]
        result = await supabase.from('groups').insert(insertData).select('id').single()
      }

      if (result.error) throw result.error

      const groupId = result.data?.id
      if (groupId) {
        await supabase.from('group_members').insert({ group_id: groupId, user_id: user.id, role: 'admin' })
      }

      toast.success('Gruppe erstellt!')
      onCreated()
      onClose()
    } catch (err: unknown) {
      const e = err as { message?: string; code?: string }
      if (e?.code === '23505') toast.error('Gruppenname existiert bereits')
      else if (e?.code === '42501') toast.error('Keine Berechtigung. Bitte neu einloggen.')
      else toast.error('Fehler beim Erstellen: ' + (e?.message ?? 'Unbekannter Fehler'))
    } finally {
      setSaving(false)
    }
  }

  const selectedCat = getCatConfig(category)

  return (
    <div
      className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className={cn('rounded-t-2xl p-5 bg-gradient-to-r text-white', selectedCat.color)}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-2xl">{selectedCat.emoji}</span>
              <h2 className="text-lg font-bold">Neue Gruppe erstellen</h2>
            </div>
            <button onClick={onClose} className="p-1.5 hover:bg-white/20 rounded-xl transition-colors">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="p-6 space-y-4">
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
            <label className="label">
              Beschreibung <span className="font-normal text-gray-400">({description.length}/500)</span>
            </label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={500}
              className="input resize-none" placeholder="Worum geht es in der Gruppe?" />
          </div>

          <div>
            <label className="label">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {GROUP_CATEGORIES.map(c => (
                <option key={c.value} value={c.value}>{c.emoji} {c.label}</option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setIsPrivate(!isPrivate)}
              className={cn('flex items-center gap-2 px-4 py-2 rounded-xl border transition-all text-sm font-medium',
                isPrivate
                  ? 'bg-amber-50 border-amber-300 text-amber-700'
                  : 'bg-green-50 border-green-300 text-green-700'
              )}
            >
              {isPrivate ? <Lock className="w-4 h-4" /> : <Globe className="w-4 h-4" />}
              {isPrivate ? 'Privat' : 'Öffentlich'}
            </button>
            <span className="text-xs text-gray-500">
              {isPrivate ? 'Nur auf Einladung' : 'Jeder kann beitreten'}
            </span>
          </div>

          <button
            onClick={handleCreate}
            disabled={saving || name.trim().length < 3}
            className="w-full py-3 bg-gradient-to-r from-primary-500 to-teal-600 text-white rounded-xl font-semibold hover:shadow-lg disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-95"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Gruppe erstellen
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Group Card ──────────────────────────────────────────────────
function GroupCard({
  group, isMember, onJoin, onLeave,
}: {
  group: Group
  isMember: boolean
  onJoin: (id: string) => Promise<void>
  onLeave: (id: string) => Promise<void>
}) {
  const [busy, setBusy] = useState(false)
  const cat = getCatConfig(group.category)
  const isPrivate = group.is_private || group.is_public === false

  const handleJoin = async () => {
    setBusy(true)
    try { await onJoin(group.id) } finally { setBusy(false) }
  }

  const handleLeave = async () => {
    setBusy(true)
    try { await onLeave(group.id) } finally { setBusy(false) }
  }

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-all duration-200 overflow-hidden group flex flex-col">
      {/* Card header with gradient */}
      <div className={cn('relative h-28 bg-gradient-to-br flex items-center justify-center flex-shrink-0', cat.color)}>
        <span className="text-5xl drop-shadow-sm select-none">{cat.emoji}</span>
        {isPrivate && (
          <span className="absolute top-3 right-3 inline-flex items-center gap-1 px-2 py-0.5 bg-black/30 backdrop-blur-sm rounded-full text-[10px] font-semibold text-white">
            <Lock className="w-2.5 h-2.5" /> Privat
          </span>
        )}
        <span className="absolute bottom-3 left-3 inline-flex items-center gap-1 px-2 py-0.5 bg-black/30 backdrop-blur-sm rounded-full text-[10px] font-medium text-white">
          {cat.emoji} {cat.label}
        </span>
      </div>

      {/* Card body */}
      <div className="p-4 flex flex-col flex-1">
        <h3 className="font-bold text-gray-900 text-sm leading-snug line-clamp-1 mb-1">
          {group.name}
        </h3>
        {group.description ? (
          <p className="text-xs text-gray-500 line-clamp-2 mb-3 flex-1">{group.description}</p>
        ) : (
          <p className="text-xs text-gray-400 italic mb-3 flex-1">Keine Beschreibung</p>
        )}

        {/* Stats row */}
        <div className="flex items-center gap-3 text-xs text-gray-400 mb-3">
          <span className="flex items-center gap-1">
            <Users className="w-3.5 h-3.5" />
            <span className="font-medium text-gray-600">{group.member_count}</span> Mitglieder
          </span>
          <span className="flex items-center gap-1">
            <MessageCircle className="w-3.5 h-3.5" />
            <span className="font-medium text-gray-600">{group.post_count ?? 0}</span> Beiträge
          </span>
        </div>

        {/* Actions */}
        {isMember ? (
          <div className="flex gap-2">
            <Link
              href={`/dashboard/groups/${group.id}`}
              className="flex-1 text-center py-2 bg-primary-50 text-primary-700 rounded-xl text-xs font-semibold hover:bg-primary-100 transition-all border border-primary-100"
            >
              Öffnen →
            </Link>
            <button
              onClick={handleLeave}
              disabled={busy}
              className="py-2 px-3 bg-red-50 text-red-500 rounded-xl text-xs font-medium hover:bg-red-100 transition-all border border-red-100 disabled:opacity-60 flex items-center gap-1"
            >
              {busy ? <Loader2 className="w-3 h-3 animate-spin" /> : <Leave className="w-3.5 h-3.5" />}
            </button>
          </div>
        ) : (
          <button
            onClick={handleJoin}
            disabled={busy}
            className={cn(
              'w-full py-2 rounded-xl text-xs font-semibold transition-all flex items-center justify-center gap-1.5',
              'bg-gradient-to-r from-primary-500 to-teal-600 text-white hover:shadow-md active:scale-95 disabled:opacity-60'
            )}
          >
            {busy
              ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
              : <UserPlus className="w-3.5 h-3.5" />
            }
            {busy ? 'Beitreten...' : 'Beitreten'}
          </button>
        )}
      </div>
    </div>
  )
}

// ── Skeleton Card ────────────────────────────────────────────────
function SkeletonCard() {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden animate-pulse">
      <div className="h-28 bg-gray-200" />
      <div className="p-4 space-y-2">
        <div className="h-4 bg-gray-200 rounded-lg w-2/3" />
        <div className="h-3 bg-gray-100 rounded-lg w-full" />
        <div className="h-3 bg-gray-100 rounded-lg w-4/5" />
        <div className="h-8 bg-gray-100 rounded-xl mt-3" />
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
  const [showFilter, setShowFilter] = useState(false)

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    const [groupsRes, membersRes] = await Promise.all([
      supabase.from('groups').select('*').order('member_count', { ascending: false }),
      user
        ? supabase.from('group_members').select('group_id').eq('user_id', user.id)
        : Promise.resolve({ data: [] as { group_id: string }[] }),
    ])

    setGroups(groupsRes.data ?? [])
    setMyMemberships(new Set((membersRes.data ?? []).map(m => m.group_id)))
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

  // BUG FIX: async handlers with optimistic updates + proper error handling
  const handleJoin = async (groupId: string): Promise<void> => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    // Optimistic update
    setMyMemberships(prev => new Set([...prev, groupId]))
    const supabase = createClient()
    const { error } = await supabase
      .from('group_members')
      .insert({ group_id: groupId, user_id: userId, role: 'member' })
    if (error) {
      // Revert optimistic update on error
      setMyMemberships(prev => { const s = new Set(prev); s.delete(groupId); return s })
      if (error.code === '23505') toast.error('Du bist bereits Mitglied')
      else toast.error('Fehler beim Beitreten: ' + error.message)
      return
    }
    toast.success('Gruppe beigetreten!')
    // Reload in background for accurate member_count
    loadData()
  }

  const handleLeave = async (groupId: string): Promise<void> => {
    if (!userId) return
    const group = groups.find(g => g.id === groupId)
    const creatorId = group?.creator_id || group?.created_by
    if (creatorId === userId) { toast.error('Als Ersteller kannst du die Gruppe nicht verlassen'); return }
    if (!confirm('Gruppe wirklich verlassen?')) return

    // Optimistic update
    setMyMemberships(prev => { const s = new Set(prev); s.delete(groupId); return s })
    const supabase = createClient()
    const { error } = await supabase
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', userId)
    if (error) {
      // Revert
      setMyMemberships(prev => new Set([...prev, groupId]))
      toast.error('Fehler beim Verlassen')
      return
    }
    toast.success('Gruppe verlassen')
    loadData()
  }

  const filtered = groups.filter(g => {
    if (tab === 'mine' && !myMemberships.has(g.id)) return false
    if (filterCat !== 'all' && g.category !== filterCat) return false
    if (searchTerm) {
      const q = searchTerm.toLowerCase()
      if (!g.name.toLowerCase().includes(q) && !(g.description ?? '').toLowerCase().includes(q)) return false
    }
    return true
  })

  const myCount = myMemberships.size

  return (
    <div>
      <div className="max-w-5xl mx-auto space-y-6">
        {/* Editorial header */}
        <header>
          <div className="meta-label meta-label--subtle mb-4">§ 04 / Gemeinschaft</div>
          <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
            <div className="flex items-start gap-4">
              <div className="w-14 h-14 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0 float-idle">
                <Users className="w-6 h-6 text-primary-700" />
              </div>
              <div>
                <h1 className="page-title">Gruppen</h1>
                <p className="page-subtitle mt-2">Schließe dich Gruppen an und vernetz dich mit deiner <span className="text-accent">Nachbarschaft</span>.</p>
              </div>
            </div>
            <button
              onClick={() => setShowCreate(true)}
              className="magnetic shine inline-flex items-center gap-1.5 bg-ink-800 hover:bg-ink-700 text-paper px-5 py-2.5 rounded-full text-sm font-medium tracking-wide transition-colors flex-shrink-0"
            >
              <Plus className="w-4 h-4" /> Neue Gruppe
            </button>
          </div>

          {/* Editorial stats row */}
          <div className="flex items-center gap-3 mt-5 flex-wrap">
            <div className="px-4 py-1.5 rounded-full bg-paper border border-stone-200">
              <span className="font-display text-base font-medium text-ink-800 tabular-nums">{groups.length}</span>
              <span className="text-[10px] tracking-[0.14em] uppercase text-ink-400 ml-1.5">Gruppen</span>
            </div>
            <div className="px-4 py-1.5 rounded-full bg-paper border border-stone-200">
              <span className="font-display text-base font-medium text-ink-800 tabular-nums">{myCount}</span>
              <span className="text-[10px] tracking-[0.14em] uppercase text-ink-400 ml-1.5">beigetreten</span>
            </div>
          </div>
          <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
        </header>
        {/* Search + Filter Bar */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
          <div className="flex gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                className="input pl-10 py-2.5 text-sm"
                placeholder="Gruppen suchen..."
              />
              {searchTerm && (
                <button onClick={() => setSearchTerm('')} className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 hover:bg-gray-100 rounded-lg">
                  <X className="w-3.5 h-3.5 text-gray-400" />
                </button>
              )}
            </div>
            <button
              onClick={() => setShowFilter(!showFilter)}
              className={cn(
                'flex items-center gap-2 px-4 py-2.5 rounded-xl border text-sm font-medium transition-all',
                filterCat !== 'all' || showFilter
                  ? 'bg-primary-50 border-primary-200 text-primary-700'
                  : 'bg-gray-50 border-gray-200 text-gray-600 hover:border-gray-300'
              )}
            >
              <Filter className="w-4 h-4" />
              {filterCat !== 'all' ? getCatConfig(filterCat).emoji : 'Filter'}
            </button>
          </div>

          {/* Filter chips */}
          {showFilter && (
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                onClick={() => { setFilterCat('all'); setShowFilter(false) }}
                className={cn(
                  'px-3 py-1 rounded-full text-xs font-medium border transition-all',
                  filterCat === 'all'
                    ? 'bg-primary-500 text-white border-primary-500'
                    : 'bg-white text-gray-600 border-gray-200 hover:border-primary-300'
                )}
              >
                Alle
              </button>
              {GROUP_CATEGORIES.map(c => (
                <button
                  key={c.value}
                  onClick={() => { setFilterCat(c.value); setShowFilter(false) }}
                  className={cn(
                    'px-3 py-1 rounded-full text-xs font-medium border transition-all',
                    filterCat === c.value
                      ? 'bg-primary-500 text-white border-primary-500'
                      : 'bg-white text-gray-600 border-gray-200 hover:border-primary-300'
                  )}
                >
                  {c.emoji} {c.label}
                </button>
              ))}
            </div>
          )}

          {/* Tabs */}
          <div className="flex gap-1 mt-3 bg-gray-50 rounded-xl p-1">
            {([
              { key: 'all' as const, label: 'Alle Gruppen', count: groups.length },
              { key: 'mine' as const, label: 'Meine Gruppen', count: myCount },
            ]).map(t => (
              <button
                key={t.key}
                onClick={() => setTab(t.key)}
                className={cn(
                  'flex-1 py-1.5 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5',
                  tab === t.key
                    ? 'bg-white text-primary-700 shadow-sm'
                    : 'text-gray-500 hover:text-gray-700'
                )}
              >
                {t.label}
                <span className={cn(
                  'inline-flex items-center justify-center min-w-[18px] h-[18px] rounded-full text-[10px] font-bold px-1',
                  tab === t.key ? 'bg-primary-100 text-primary-700' : 'bg-gray-200 text-gray-500'
                )}>
                  {t.count}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* Results info */}
        {!loading && searchTerm && (
          <p className="text-sm text-gray-500 px-1">
            {filtered.length} Ergebnis{filtered.length !== 1 ? 'se' : ''} für „{searchTerm}"
          </p>
        )}

        {/* Groups Grid */}
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[1, 2, 3, 4, 5, 6].map(i => <SkeletonCard key={i} />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl border border-gray-100 shadow-sm">
            <div className="text-5xl mb-4">🔍</div>
            <p className="text-gray-700 font-bold text-lg">
              {tab === 'mine' ? 'Du bist noch keiner Gruppe beigetreten' : 'Keine Gruppen gefunden'}
            </p>
            <p className="text-sm text-gray-400 mt-2 mb-5">
              {tab === 'mine'
                ? 'Entdecke öffentliche Gruppen und werde Teil der Community'
                : 'Starte die Gemeinschaft mit einer neuen Gruppe'}
            </p>
            {tab === 'mine' ? (
              <button
                onClick={() => setTab('all')}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary-50 text-primary-700 rounded-xl text-sm font-semibold hover:bg-primary-100 transition-all"
              >
                Alle Gruppen entdecken
              </button>
            ) : (
              <button
                onClick={() => setShowCreate(true)}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary-500 to-teal-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all"
              >
                <Plus className="w-4 h-4" /> Erste Gruppe erstellen
              </button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 pb-8">
            {filtered.map(g => (
              <GroupCard
                key={g.id}
                group={g}
                isMember={myMemberships.has(g.id)}
                onJoin={handleJoin}
                onLeave={handleLeave}
              />
            ))}
          </div>
        )}
      </div>

      {showCreate && <CreateGroupModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
