'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { useRouter } from 'next/navigation'
import {
  Trophy, Plus, Search, X, Users,
  CheckCircle2, Clock, Star, Zap, Loader2,
  Trash2, AlertTriangle, Camera,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'

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
  streak: number
  checkinDates: Set<string>
  verifiedDates: Set<string>
}

function calcStreak(dates: string[]): number {
  if (!dates.length) return 0
  const set = new Set(dates)
  const fmt = (d: Date) => d.toISOString().split('T')[0]
  const d = new Date()
  let streak = 0
  if (!set.has(fmt(d))) {
    d.setDate(d.getDate() - 1)
    if (!set.has(fmt(d))) return 0
    streak = 1
    d.setDate(d.getDate() - 1)
  } else {
    streak = 1
    d.setDate(d.getDate() - 1)
  }
  while (set.has(fmt(d))) { streak++; d.setDate(d.getDate() - 1) }
  return streak
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

// ── Streak Heatmap ──────────────────────────────────────────────
function StreakHeatmap({
  startDate,
  endDate,
  checkinDates,
  verifiedDates,
}: {
  startDate: string
  endDate: string
  checkinDates: Set<string>
  verifiedDates: Set<string>
}) {
  const fmt = (d: Date) => d.toISOString().split('T')[0]
  const today = fmt(new Date())
  const start = new Date(startDate)
  const end = new Date(endDate)
  const totalDays = Math.max(1, Math.round((end.getTime() - start.getTime()) / 86_400_000) + 1)
  // Begrenzung: zeige max. die letzten 35 Tage, um Platz zu sparen
  const maxCells = 35
  const visibleDays = Math.min(totalDays, maxCells)
  const offset = totalDays - visibleDays
  const cells: { date: string; state: 'verified' | 'checkin' | 'missed' | 'future' | 'today-empty' }[] = []
  for (let i = 0; i < visibleDays; i++) {
    const d = new Date(start)
    d.setDate(d.getDate() + offset + i)
    const key = fmt(d)
    const isFuture = key > today
    const isToday = key === today
    let state: 'verified' | 'checkin' | 'missed' | 'future' | 'today-empty'
    if (verifiedDates.has(key)) state = 'verified'
    else if (checkinDates.has(key)) state = 'checkin'
    else if (isFuture) state = 'future'
    else if (isToday) state = 'today-empty'
    else state = 'missed'
    cells.push({ date: key, state })
  }

  const stateClass = (s: typeof cells[number]['state']) => {
    switch (s) {
      case 'verified':    return 'bg-green-500'
      case 'checkin':     return 'bg-yellow-400'
      case 'today-empty': return 'bg-amber-100 ring-1 ring-amber-400'
      case 'missed':      return 'bg-gray-200'
      case 'future':      return 'bg-gray-100 border border-dashed border-gray-200'
    }
  }

  return (
    <div className="mt-2.5">
      {offset > 0 && (
        <div className="text-[10px] text-gray-400 mb-1">
          Letzte {visibleDays} von {totalDays} Tagen
        </div>
      )}
      <div className="flex flex-wrap gap-[3px]">
        {cells.map(c => (
          <div
            key={c.date}
            title={new Date(c.date).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' })}
            className={cn('w-2.5 h-2.5 rounded-[2px]', stateClass(c.state))}
          />
        ))}
      </div>
    </div>
  )
}

// ── Challenge Card ──────────────────────────────────────────────
function ChallengeCard({
  challenge, isJoined, checkedInToday, progressStats, userId, onJoin, onCheckin, checkingIn, canDelete, onDelete,
}: {
  challenge: Challenge
  isJoined: boolean
  checkedInToday: boolean
  progressStats?: ProgressStats
  userId?: string
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

  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)

  const handleProofUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !userId) return
    setUploading(true)
    try {
      const supabase = createClient()
      const today = new Date().toISOString().split('T')[0]
      const ext = file.name.split('.').pop() ?? 'jpg'
      const path = `${challenge.id}/${userId}/${today}.${ext}`
      const { error: upErr } = await supabase.storage
        .from('challenge-proofs')
        .upload(path, file, { upsert: true })
      if (upErr) { toast.error('Upload fehlgeschlagen'); return }
      const { data: { publicUrl } } = supabase.storage
        .from('challenge-proofs')
        .getPublicUrl(path)
      const res = await fetch(`/api/challenges/${challenge.id}/proof`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ proof_image_url: publicUrl }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        toast.error(body?.error ?? 'Fehler beim Speichern')
        return
      }
      toast.success('Beweis-Foto hochgeladen! 📸')
    } finally {
      setUploading(false)
      e.target.value = ''
    }
  }

  return (
    <div className={cn(
      'spotlight hover-lift relative bg-white rounded-2xl border overflow-hidden shadow-soft hover:shadow-card transition-all flex flex-col',
      isExpired ? 'border-gray-200 opacity-70' : 'border-warm-200',
    )}>
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{
          background: isExpired
            ? 'linear-gradient(90deg, #9CA3AF, #9CA3AF33)'
            : 'linear-gradient(90deg, #F59E0B, #F59E0B33)',
        }}
      />
      {/* Top bar */}
      <div className={cn(
        'relative px-4 py-2 pt-3 flex items-center justify-between text-sm overflow-hidden',
        isExpired ? 'bg-gray-50' : 'bg-gradient-to-r from-amber-50 via-orange-50 to-amber-50',
      )}>
        {!isExpired && <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />}
        <span className="relative flex items-center gap-1.5">
          <span className="text-base float-idle inline-block">{catEmoji[challenge.category]}</span>
          <span className="font-medium text-amber-900">{challenge.category}</span>
        </span>
        <div className="relative flex items-center gap-2">
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
                  'shine w-full py-2 rounded-xl text-xs font-semibold transition-all flex items-center justify-center gap-1.5',
                  checkedInToday
                    ? 'bg-primary-100 text-primary-700 cursor-default shadow-soft'
                    : checkingIn
                      ? 'bg-amber-100 text-amber-600 cursor-wait'
                      : 'bg-gradient-to-r from-amber-500 to-orange-500 text-white hover:shadow-md active:scale-95',
                )}
                style={!checkedInToday && !checkingIn ? { boxShadow: '0 4px 16px -4px rgba(245,158,11,0.5)' } : undefined}
              >
                {checkingIn
                  ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  : <CheckCircle2 className="w-3.5 h-3.5" />}
                {checkedInToday ? 'Heute erledigt ✓' : checkingIn ? 'Wird gespeichert…' : 'Heute erledigt'}
              </button>
            ) : (
              <button
                onClick={() => onJoin(challenge.id)}
                className="shine w-full py-2 bg-gradient-to-r from-amber-500 to-orange-500 text-white rounded-xl text-xs font-semibold hover:shadow-md transition-all flex items-center justify-center gap-1.5 active:scale-95"
                style={{ boxShadow: '0 4px 16px -4px rgba(245,158,11,0.5)' }}
              >
                <Zap className="w-3.5 h-3.5" /> Teilnehmen
              </button>
            )}
          </div>
        )}

        {/* Fortschrittsbalken + Streak */}
        {isJoined && progressStats && (
          <div className="mt-2">
            <div className="flex items-center justify-between text-xs text-gray-400 mb-1">
              <span>{progressStats.checkinCount} von {totalDays} Tagen</span>
              <div className="flex items-center gap-2">
                {progressStats.streak > 0 && (
                  <span className="text-orange-500 font-medium">🔥 {progressStats.streak} Tage in Folge</span>
                )}
                {progressStats.verifiedCount > 0 && (
                  <span className="text-green-600 font-medium">{progressStats.verifiedCount} verifiziert</span>
                )}
              </div>
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

            {/* Streak-Heatmap */}
            <StreakHeatmap
              startDate={challenge.start_date}
              endDate={challenge.end_date}
              checkinDates={progressStats.checkinDates}
              verifiedDates={progressStats.verifiedDates}
            />
          </div>
        )}

        {/* Foto-Upload */}
        {isJoined && checkedInToday && (
          <>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleProofUpload}
            />
            <button
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              className="mt-2 w-full py-1.5 border border-dashed border-gray-300 rounded-lg text-xs text-gray-400 hover:border-amber-400 hover:text-amber-600 transition-all flex items-center justify-center gap-1 disabled:opacity-60"
            >
              {uploading
                ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                : <Camera className="w-3.5 h-3.5" />}
              {uploading ? 'Wird hochgeladen…' : 'Beweis-Foto hinzufügen'}
            </button>
          </>
        )}
      </div>
    </div>
  )
}

// ── Main Challenges Page ────────────────────────────────────────
export default function ChallengesPage() {
  const router = useRouter()
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
  const [deleteTarget, setDeleteTarget] = useState<Challenge | null>(null)
  const [deleting, setDeleting] = useState(false)

  const loadData = useCallback(async (signal?: { cancelled: boolean }) => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (signal?.cancelled) return
    if (user) {
      setUserId(user.id)
      const { data: profile, error: profErr } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle()
      if (signal?.cancelled) return
      if (profErr) console.error('challenges profile query failed:', profErr.message)
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
        : Promise.resolve({ data: [] as ChallengeProgress[], error: null }),
    ])
    if (signal?.cancelled) return
    if (challRes.error) console.error('challenges query failed:', challRes.error.message)
    if ('error' in progRes && progRes.error) console.error('challenge_progress query failed:', progRes.error.message)

    setChallenges(challRes.data ?? [])

    const rows = (progRes.data ?? []) as ChallengeProgress[]
    const joined = new Set(rows.map(r => r.challenge_id))
    const todayChecked = new Set(
      rows.filter(r => r.date === today && r.checked_in).map(r => r.challenge_id)
    )

    // Dates pro Challenge sammeln für Streak-Berechnung
    const datesByChallenge = new Map<string, string[]>()
    const statsMap = new Map<string, ProgressStats>()
    rows.forEach(r => {
      if (!r.checked_in) return
      const cur = statsMap.get(r.challenge_id) ?? {
        checkinCount: 0,
        verifiedCount: 0,
        streak: 0,
        checkinDates: new Set<string>(),
        verifiedDates: new Set<string>(),
      }
      cur.checkinCount++
      cur.checkinDates.add(r.date)
      if (r.verified_by_admin) {
        cur.verifiedCount++
        cur.verifiedDates.add(r.date)
      }
      statsMap.set(r.challenge_id, cur)
      const dates = datesByChallenge.get(r.challenge_id) ?? []
      dates.push(r.date)
      datesByChallenge.set(r.challenge_id, dates)
    })
    datesByChallenge.forEach((dates, cid) => {
      const s = statsMap.get(cid)
      if (s) s.streak = calcStreak(dates)
    })

    setJoinedIds(joined)
    setTodayCheckinIds(todayChecked)
    setProgressStatsMap(statsMap)
    setLoading(false)
  }, [])

  useEffect(() => {
    const signal = { cancelled: false }
    loadData(signal)
    return () => { signal.cancelled = true }
  }, [loadData])

  const handleJoin = async (challengeId: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    setCheckingInId(challengeId)
    try {
      const supabase = createClient()
      const today = new Date().toISOString().split('T')[0]
      // Idempotent: upsert verhindert Duplikate
      const { error } = await supabase.from('challenge_progress').upsert(
        { challenge_id: challengeId, user_id: userId, date: today, checked_in: true },
        { onConflict: 'challenge_id,user_id,date' }
      )
      if (error) { toast.error(error.message ?? 'Fehler beim Beitreten'); return }
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
      const supabase = createClient()
      const today = new Date().toISOString().split('T')[0]
      const { error } = await supabase.from('challenge_progress').upsert(
        { challenge_id: challengeId, user_id: userId, date: today, checked_in: true },
        { onConflict: 'challenge_id,user_id,date' }
      )
      if (error) { toast.error(error.message ?? 'Fehler beim Check-in'); return }
      setTodayCheckinIds(prev => new Set([...prev, challengeId]))
      setProgressStatsMap(prev => {
        const cur = prev.get(challengeId) ?? {
          checkinCount: 0,
          verifiedCount: 0,
          streak: 0,
          checkinDates: new Set<string>(),
          verifiedDates: new Set<string>(),
        }
        const nextDates = new Set(cur.checkinDates)
        nextDates.add(today)
        const next = new Map(prev)
        next.set(challengeId, {
          ...cur,
          checkinCount: cur.checkinCount + 1,
          streak: cur.streak + 1,
          checkinDates: nextDates,
        })
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
      const supabase = createClient()
      const { error } = await supabase
        .from('challenges')
        .delete()
        .eq('id', deleteTarget.id)
      if (error) { toast.error(error.message ?? 'Fehler beim Löschen'); return }
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
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 11 / Challenges</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-amber-50 border border-amber-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Trophy className="w-6 h-6 text-amber-600" />
            </div>
            <div>
              <h1 className="page-title">Challenges</h1>
              <p className="page-subtitle mt-2">Sammle <span className="text-accent">Punkte</span> und mache die Welt besser.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0 text-xs tracking-wide text-ink-500">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{challenges.filter(c => new Date(c.end_date).getTime() > now).length}</span> aktiv
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{joinedCount}</span> meine
            </span>
            {isAdmin && (
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-red-50 border border-red-200 text-red-700">
                Admin
              </span>
            )}
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div>
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
              onClick={() => router.push('/dashboard/challenges/create')}
              className="shine flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-xl text-sm font-semibold hover:shadow-lg transition-all active:scale-95 flex-shrink-0"
              style={{ boxShadow: '0 4px 16px -4px rgba(245,158,11,0.5)' }}
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
              onClick={() => router.push('/dashboard/challenges/create')}
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
                userId={userId}
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
