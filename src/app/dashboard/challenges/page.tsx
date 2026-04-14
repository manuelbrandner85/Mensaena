'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Trophy, Plus, Search, X, Target, Users,
  CheckCircle2, Clock, Star, Zap, Loader2,
  Trash2, AlertTriangle,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ──────────────────────────────────────────────────────
interface Challenge {
  id: string
  title: string
  description: string | null
  category: string
  difficulty: string
  points: number
  max_participants: number | null
  participant_count: number
  start_date: string
  end_date: string
  status: string
  created_at: string
  creator_id: string
}

interface ChallengeProgress {
  challenge_id: string
  user_id: string
  date: string
  checked_in: boolean
  verified_by_admin: boolean
}

interface ProgressStats {
  checkinCount: number
  verifiedCount: number
}

// ── Config ─────────────────────────────────────────────────────
const CHALLENGE_CATEGORIES = [
  { value: 'umwelt',       label: '🌿 Umwelt' },
  { value: 'sozial',       label: '🤝 Soziales' },
  { value: 'fitness',      label: '💪 Fitness' },
  { value: 'bildung',      label: '📚 Bildung' },
  { value: 'kreativ',      label: '🎨 Kreativ' },
  { value: 'ernaehrung',   label: '🥗 Ernährung' },
  { value: 'gemeinschaft', label: '🏘️ Gemeinschaft' },
]

const DIFFICULTIES = [
  { value: 'leicht', label: '🟢 Leicht', color: 'bg-green-100 text-green-700' },
  { value: 'mittel', label: '🟡 Mittel', color: 'bg-yellow-100 text-yellow-700' },
  { value: 'schwer', label: '🔴 Schwer', color: 'bg-red-100 text-red-700' },
]

const catEmoji: Record<string, string> = {
  umwelt: '🌿', sozial: '🤝', fitness: '💪', bildung: '📚',
  kreativ: '🎨', ernaehrung: '🥗', gemeinschaft: '🏘️',
}

// ── Delete Confirmation Modal ───────────────────────────────────
function DeleteConfirmModal({
  challenge,
  onConfirm,
  onCancel,
  deleting,
}: {
  challenge: Challenge
  onConfirm: () => void
  onCancel: () => void
  deleting: boolean
}) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onCancel() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onCancel])

  return (
    <div
      className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onCancel}
    >
      <div
        className="bg-white rounded-2xl max-w-md w-full shadow-2xl overflow-hidden"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="bg-red-50 border-b border-red-100 px-6 py-4 flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <AlertTriangle className="w-5 h-5 text-red-600" />
          </div>
          <div>
            <h2 className="font-bold text-gray-900 text-sm">Challenge löschen</h2>
            <p className="text-xs text-red-600 mt-0.5">Diese Aktion kann nicht rückgängig gemacht werden</p>
          </div>
        </div>

        {/* Body */}
        <div className="px-6 py-5">
          <p className="text-sm text-gray-700">
            Bist du sicher, dass du die Challenge
            <span className="font-semibold text-gray-900"> „{challenge.title}"</span> löschen möchtest?
          </p>
          <div className="mt-3 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 text-xs text-amber-700 space-y-1">
            <p className="font-semibold">Folgendes wird gelöscht:</p>
            <ul className="list-disc list-inside space-y-0.5 text-amber-600">
              <li>Die Challenge selbst</li>
              <li>Alle Teilnahmen ({challenge.participant_count} Teilnehmer)</li>
              <li>Alle Fortschritts-Einträge</li>
            </ul>
          </div>
        </div>

        {/* Actions */}
        <div className="px-6 pb-5 flex gap-3">
          <button
            onClick={onCancel}
            disabled={deleting}
            className="flex-1 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-all disabled:opacity-60"
          >
            Abbrechen
          </button>
          <button
            onClick={onConfirm}
            disabled={deleting}
            className="flex-1 py-2.5 bg-red-600 text-white rounded-xl text-sm font-semibold hover:bg-red-700 transition-all disabled:opacity-60 flex items-center justify-center gap-2"
          >
            {deleting
              ? <Loader2 className="w-4 h-4 animate-spin" />
              : <Trash2 className="w-4 h-4" />
            }
            {deleting ? 'Wird gelöscht...' : 'Ja, löschen'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Create Challenge Modal ──────────────────────────────────────
function CreateChallengeModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('umwelt')
  const [difficulty, setDifficulty] = useState('mittel')
  const [points, setPoints] = useState('50')
  const [days, setDays] = useState('7')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  const handleCreate = async () => {
    if (title.trim().length < 5) { toast.error('Titel mindestens 5 Zeichen'); return }
    if (description.trim().length > 500) { toast.error('Beschreibung max. 500 Zeichen'); return }
    const daysNum = parseInt(days)
    if (isNaN(daysNum) || daysNum < 1 || daysNum > 90) { toast.error('Dauer: 1–90 Tage'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      const allowed = await checkRateLimit(user.id, 'create_challenge', 2, 60)
      if (!allowed) { toast.error('Zu viele Challenges in kurzer Zeit.'); setSaving(false); return }

      const startDate = new Date()
      const endDate = new Date()
      endDate.setDate(endDate.getDate() + parseInt(days))

      const { error } = await supabase.from('challenges').insert({
        title: title.trim(),
        description: description.trim() || null,
        category,
        difficulty,
        points: parseInt(points) || 50,
        start_date: startDate.toISOString(),
        end_date: endDate.toISOString(),
        status: 'active',
        participant_count: 0,
        creator_id: user.id,
      })
      if (error) throw error
      toast.success('Challenge erstellt!')
      onCreated()
      onClose()
    } catch (e: unknown) {
      toast.error('Fehler: ' + ((e as { message?: string })?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Trophy className="w-5 h-5 text-amber-500" /> Neue Challenge
          </h2>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-xl transition-colors">
            <X className="w-5 h-5 text-gray-400" />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="label">Challenge-Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={80}
              className="input" placeholder="z.B. 7 Tage plastikfrei" />
          </div>
          <div>
            <label className="label">Beschreibung</label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={500}
              className="input resize-none" placeholder="Was ist die Challenge?" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Kategorie</label>
              <select value={category} onChange={e => setCategory(e.target.value)} className="input">
                {CHALLENGE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Schwierigkeit</label>
              <select value={difficulty} onChange={e => setDifficulty(e.target.value)} className="input">
                {DIFFICULTIES.map(d => <option key={d.value} value={d.value}>{d.label}</option>)}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Punkte</label>
              <input type="number" value={points} onChange={e => setPoints(e.target.value)} min="10" max="500" className="input" />
            </div>
            <div>
              <label className="label">Dauer (Tage)</label>
              <input type="number" value={days} onChange={e => setDays(e.target.value)} min="1" max="90" className="input" />
            </div>
          </div>
          <button onClick={handleCreate} disabled={saving || title.trim().length < 5}
            className="w-full py-3 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-xl font-semibold hover:shadow-lg disabled:opacity-50 flex items-center justify-center gap-2 transition-all active:scale-95">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trophy className="w-4 h-4" />}
            Challenge starten
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Challenge Card ──────────────────────────────────────────────
function ChallengeCard({
  challenge, isJoined, checkedInToday, progressStats, onJoin, onCheckin, checkingIn, canDelete, onDelete,
}: {
  challenge: Challenge
  isJoined: boolean
  checkedInToday: boolean
  progressStats?: ProgressStats
  onJoin: (id: string) => void
  onCheckin: (id: string) => void
  checkingIn: boolean
  canDelete: boolean
  onDelete: (challenge: Challenge) => void
}) {
  const diffConfig = DIFFICULTIES.find(d => d.value === challenge.difficulty)
  const daysLeft = Math.max(0, Math.ceil((new Date(challenge.end_date).getTime() - Date.now()) / 86400000))
  const isExpired = daysLeft === 0
  const totalDays = Math.max(
    1,
    Math.round((new Date(challenge.end_date).getTime() - new Date(challenge.start_date).getTime()) / 86_400_000) + 1,
  )

  return (
    <div className={cn(
      'bg-white rounded-2xl border overflow-hidden hover:shadow-md transition-all hover:-translate-y-[2px] flex flex-col',
      isExpired ? 'border-gray-200 opacity-70' : 'border-warm-200',
    )}>
      {/* Top bar */}
      <div className={cn(
        'px-4 py-2 flex items-center justify-between text-sm',
        isExpired ? 'bg-gray-50' : 'bg-gradient-to-r from-amber-50 to-orange-50',
      )}>
        <span>{catEmoji[challenge.category]} {challenge.category}</span>
        <div className="flex items-center gap-2">
          <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium', diffConfig?.color ?? 'bg-gray-100')}>
            {diffConfig?.label?.replace(/🟢|🟡|🔴/g, '').trim() ?? challenge.difficulty}
          </span>
          {/* Delete button – only for admin/creator */}
          {canDelete && (
            <button
              onClick={e => { e.stopPropagation(); onDelete(challenge) }}
              className="p-1 rounded-lg hover:bg-red-100 text-gray-400 hover:text-red-500 transition-colors"
              title="Challenge löschen"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      <div className="p-4 flex flex-col flex-1">
        <h3 className="font-bold text-gray-900">{challenge.title}</h3>
        {challenge.description && (
          <p className="text-xs text-gray-500 mt-1 line-clamp-2 flex-1">{challenge.description}</p>
        )}

        <div className="flex items-center gap-3 mt-3 text-xs text-gray-400">
          <span className="flex items-center gap-1">
            <Users className="w-3 h-3" /> {challenge.participant_count} Teilnehmer
          </span>
          <span className="flex items-center gap-1">
            <Star className="w-3 h-3 text-amber-400" /> {challenge.points} Pkt
          </span>
          <span className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            {isExpired ? 'Beendet' : `${daysLeft}d übrig`}
          </span>
        </div>

        {!isExpired && (
          <div className="mt-3">
            {isJoined ? (
              <button
                onClick={() => onCheckin(challenge.id)}
                disabled={checkedInToday || checkingIn}
                className={cn(
                  'w-full py-1.5 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1',
                  checkedInToday
                    ? 'bg-green-100 text-green-700 cursor-default'
                    : checkingIn
                      ? 'bg-amber-100 text-amber-600 cursor-wait'
                      : 'bg-amber-500 text-white hover:bg-amber-600 active:scale-95',
                )}
              >
                {checkingIn
                  ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  : <CheckCircle2 className="w-3.5 h-3.5" />}
                {checkedInToday ? 'Heute erledigt ✓' : checkingIn ? 'Wird gespeichert…' : 'Heute erledigt'}
              </button>
            ) : (
              <button
                onClick={() => onJoin(challenge.id)}
                className="w-full py-1.5 bg-amber-500 text-white rounded-lg text-xs font-medium hover:bg-amber-600 transition-all flex items-center justify-center gap-1"
              >
                <Zap className="w-3.5 h-3.5" /> Teilnehmen
              </button>
            )}
          </div>
        )}

        {/* Fortschrittsbalken */}
        {isJoined && progressStats && (
          <div className="mt-2">
            <div className="flex items-center justify-between text-xs text-gray-400 mb-1">
              <span>{progressStats.checkinCount} von {totalDays} Tagen</span>
              {progressStats.verifiedCount > 0 && (
                <span className="text-green-600 font-medium">{progressStats.verifiedCount} verifiziert</span>
              )}
            </div>
            <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden flex">
              <div
                className="h-full bg-green-500 transition-all"
                style={{ width: `${Math.min(100, (progressStats.verifiedCount / totalDays) * 100)}%` }}
              />
              <div
                className="h-full bg-yellow-400 transition-all"
                style={{ width: `${Math.min(100, ((progressStats.checkinCount - progressStats.verifiedCount) / totalDays) * 100)}%` }}
              />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// ── Main Challenges Page ────────────────────────────────────────
export default function ChallengesPage() {
  const [challenges, setChallenges] = useState<Challenge[]>([])
  const [joinedIds, setJoinedIds] = useState<Set<string>>(new Set())
  const [todayCheckinIds, setTodayCheckinIds] = useState<Set<string>>(new Set())
  const [progressStatsMap, setProgressStatsMap] = useState<Map<string, ProgressStats>>(new Map())
  const [checkingInId, setCheckingInId] = useState<string | null>(null)
  const [userId, setUserId] = useState<string>()
  const [userRole, setUserRole] = useState<string>('user')
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterCat, setFilterCat] = useState('all')
  const [tab, setTab] = useState<'active' | 'mine' | 'completed'>('active')
  const [showCreate, setShowCreate] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<Challenge | null>(null)
  const [deleting, setDeleting] = useState(false)

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      setUserId(user.id)
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single()
      setUserRole(profile?.role ?? 'user')
    }

    const today = new Date().toISOString().split('T')[0]

    const [challRes, progRes] = await Promise.all([
      supabase.from('challenges').select('*').order('created_at', { ascending: false }),
      user
        ? supabase
            .from('challenge_progress')
            .select('challenge_id, date, checked_in, verified_by_admin')
            .eq('user_id', user.id)
        : Promise.resolve({ data: [] as ChallengeProgress[] }),
    ])

    setChallenges(challRes.data ?? [])

    const rows = (progRes.data ?? []) as ChallengeProgress[]
    const joined = new Set(rows.map(r => r.challenge_id))
    const todayChecked = new Set(
      rows.filter(r => r.date === today && r.checked_in).map(r => r.challenge_id)
    )

    const statsMap = new Map<string, ProgressStats>()
    rows.forEach(r => {
      if (!r.checked_in) return
      const cur = statsMap.get(r.challenge_id) ?? { checkinCount: 0, verifiedCount: 0 }
      cur.checkinCount++
      if (r.verified_by_admin) cur.verifiedCount++
      statsMap.set(r.challenge_id, cur)
    })

    setJoinedIds(joined)
    setTodayCheckinIds(todayChecked)
    setProgressStatsMap(statsMap)
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

  const handleJoin = async (challengeId: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    // Erster Check-in legt automatisch den Eintrag an und inkrementiert participant_count
    setCheckingInId(challengeId)
    try {
      const res = await fetch(`/api/challenges/${challengeId}/checkin`, { method: 'POST' })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        toast.error(body?.error ?? 'Fehler beim Beitreten')
        return
      }
      setJoinedIds(prev => new Set([...prev, challengeId]))
      setTodayCheckinIds(prev => new Set([...prev, challengeId]))
      setChallenges(prev => prev.map(c =>
        c.id === challengeId ? { ...c, participant_count: c.participant_count + 1 } : c
      ))
      toast.success('Du nimmst teil und heute ist erledigt! 🎯')
    } finally {
      setCheckingInId(null)
    }
  }

  const handleCheckin = async (challengeId: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    setCheckingInId(challengeId)
    try {
      const res = await fetch(`/api/challenges/${challengeId}/checkin`, { method: 'POST' })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        toast.error(body?.error ?? 'Fehler beim Check-in')
        return
      }
      setTodayCheckinIds(prev => new Set([...prev, challengeId]))
      setProgressStatsMap(prev => {
        const cur = prev.get(challengeId) ?? { checkinCount: 0, verifiedCount: 0 }
        const next = new Map(prev)
        next.set(challengeId, { ...cur, checkinCount: cur.checkinCount + 1 })
        return next
      })
      toast.success('Heute erledigt! ✅')
    } finally {
      setCheckingInId(null)
    }
  }

  const handleDeleteConfirm = async () => {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      const res = await fetch(`/api/challenges/${deleteTarget.id}`, { method: 'DELETE' })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        toast.error(body?.error ?? 'Fehler beim Löschen')
        return
      }
      // Optimistisch aus der Liste entfernen
      setChallenges(prev => prev.filter(c => c.id !== deleteTarget.id))
      toast.success(`Challenge „${deleteTarget.title}" gelöscht`)
      setDeleteTarget(null)
    } catch {
      toast.error('Netzwerkfehler beim Löschen')
    } finally {
      setDeleting(false)
    }
  }

  const isAdmin = userRole === 'admin'
  const now = Date.now()

  const filtered = challenges.filter(c => {
    const active = new Date(c.end_date).getTime() > now
    if (tab === 'active' && !active) return false
    if (tab === 'mine' && !joinedIds.has(c.id)) return false
    if (tab === 'completed' && active) return false
    if (filterCat !== 'all' && c.category !== filterCat) return false
    if (searchTerm && !c.title.toLowerCase().includes(searchTerm.toLowerCase())) return false
    return true
  })

  const joinedCount = joinedIds.size

  return (
    <div className="min-h-screen bg-gradient-to-b from-amber-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-amber-500 to-orange-600 text-white px-4 sm:px-6 py-8 shadow-soft">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm">
              <Trophy className="w-6 h-6" />
            </div>
            <h1 className="text-2xl font-bold tracking-tight">Challenges</h1>
          </div>
          <p className="text-amber-100 text-sm">Nimm an Challenges teil, sammle Punkte und mache die Welt besser</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              🏆 {challenges.filter(c => new Date(c.end_date).getTime() > now).length} aktive Challenges
            </div>
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              🎯 {joinedCount} teilgenommen
            </div>
            {isAdmin && (
              <div className="bg-red-500/30 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm border border-red-300/40">
                🛡️ Admin-Modus
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 -mt-4">
        {/* Filter */}
        <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                className="input pl-10 py-2.5"
                placeholder="Challenge suchen..."
              />
              {searchTerm && (
                <button onClick={() => setSearchTerm('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                  <X className="w-3.5 h-3.5 text-gray-400" />
                </button>
              )}
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)} className="input w-auto min-w-[160px]">
              <option value="all">Alle Kategorien</option>
              {CHALLENGE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
            <button
              onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 flex-shrink-0"
            >
              <Plus className="w-4 h-4" /> Neue Challenge
            </button>
          </div>

          <div className="flex gap-1 mt-3 bg-gray-50 rounded-xl p-1">
            {([
              { key: 'active' as const, label: '🔥 Aktiv' },
              { key: 'mine' as const, label: '🎯 Meine' },
              { key: 'completed' as const, label: '✅ Beendet' },
            ]).map(t => (
              <button
                key={t.key}
                onClick={() => setTab(t.key)}
                className={cn(
                  'flex-1 py-1.5 rounded-lg text-xs font-medium transition-all',
                  tab === t.key ? 'bg-white text-amber-700 shadow-sm' : 'text-gray-500 hover:text-gray-700',
                )}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Grid */}
        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {[1, 2, 3, 4].map(i => <div key={i} className="h-48 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl border border-warm-200 shadow-sm">
            <Trophy className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-700 font-bold text-lg">Keine Challenges gefunden</p>
            <p className="text-sm text-gray-500 mt-1 mb-4">Motiviere die Community mit einer Challenge</p>
            <button
              onClick={() => setShowCreate(true)}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95"
            >
              <Plus className="w-4 h-4" /> Erste Challenge starten
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-8">
            {filtered.map(c => (
              <ChallengeCard
                key={c.id}
                challenge={c}
                isJoined={joinedIds.has(c.id)}
                checkedInToday={todayCheckinIds.has(c.id)}
                progressStats={progressStatsMap.get(c.id)}
                onJoin={handleJoin}
                onCheckin={handleCheckin}
                checkingIn={checkingInId === c.id}
                canDelete={isAdmin || c.creator_id === userId}
                onDelete={setDeleteTarget}
              />
            ))}
          </div>
        )}
      </div>

      {/* Modals */}
      {showCreate && (
        <CreateChallengeModal onClose={() => setShowCreate(false)} onCreated={loadData} />
      )}
      {deleteTarget && (
        <DeleteConfirmModal
          challenge={deleteTarget}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setDeleteTarget(null)}
          deleting={deleting}
        />
      )}
    </div>
  )
}
