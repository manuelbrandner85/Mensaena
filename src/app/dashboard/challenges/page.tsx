'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Trophy, Plus, Search, X, Target, Flame, Calendar, Users,
  CheckCircle2, Clock, Star, Zap, Loader2, ChevronRight,
  TrendingUp, Award,
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
  status: string
  progress_pct: number
  completed_at: string | null
}

// ── Config ─────────────────────────────────────────────────────
const CHALLENGE_CATEGORIES = [
  { value: 'umwelt', label: '🌿 Umwelt' },
  { value: 'sozial', label: '🤝 Soziales' },
  { value: 'fitness', label: '💪 Fitness' },
  { value: 'bildung', label: '📚 Bildung' },
  { value: 'kreativ', label: '🎨 Kreativ' },
  { value: 'ernaehrung', label: '🥗 Ernährung' },
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

// ── Create Challenge Modal ──────────────────────────────────────
function CreateChallengeModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('umwelt')
  const [difficulty, setDifficulty] = useState('mittel')
  const [points, setPoints] = useState('50')
  const [days, setDays] = useState('7')
  const [saving, setSaving] = useState(false)

  // Close on Escape
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

      // Rate-Limiting
      const allowed = await checkRateLimit(user.id, 'create_challenge', 2, 60)
      if (!allowed) { toast.error('Zu viele Challenges in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

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
    } catch (err: any) {
      toast.error('Fehler: ' + (err?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-gray-900">🏆 Neue Challenge</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5" /></button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Challenge-Titel *</label>
            <input value={title} onChange={e => setTitle(e.target.value)} maxLength={80}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500" placeholder="z.B. 7 Tage plastikfrei" />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Beschreibung</label>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} maxLength={500}
              className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500" placeholder="Was ist die Challenge?" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium text-gray-700">Kategorie</label>
              <select value={category} onChange={e => setCategory(e.target.value)}
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500">
                {CHALLENGE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium text-gray-700">Schwierigkeit</label>
              <select value={difficulty} onChange={e => setDifficulty(e.target.value)}
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500">
                {DIFFICULTIES.map(d => <option key={d.value} value={d.value}>{d.label}</option>)}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium text-gray-700">Punkte</label>
              <input type="number" value={points} onChange={e => setPoints(e.target.value)} min="10" max="500"
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500" />
            </div>
            <div>
              <label className="text-sm font-medium text-gray-700">Dauer (Tage)</label>
              <input type="number" value={days} onChange={e => setDays(e.target.value)} min="1" max="90"
                className="mt-1 w-full px-3 py-2 border rounded-xl focus:ring-2 focus:ring-amber-500" />
            </div>
          </div>

          <button onClick={handleCreate} disabled={saving || title.trim().length < 5}
            className="w-full py-2.5 bg-amber-500 text-white rounded-xl font-medium hover:bg-amber-600 disabled:opacity-50 flex items-center justify-center gap-2">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trophy className="w-4 h-4" />}
            Challenge starten
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Challenge Card ──────────────────────────────────────────────
function ChallengeCard({ challenge, isJoined, progress, onJoin }: {
  challenge: Challenge; isJoined: boolean; progress?: ChallengeProgress; onJoin: (id: string) => void
}) {
  const diffConfig = DIFFICULTIES.find(d => d.value === challenge.difficulty)
  const daysLeft = Math.max(0, Math.ceil((new Date(challenge.end_date).getTime() - Date.now()) / 86400000))
  const isExpired = daysLeft === 0

  return (
    <div className={cn('bg-white rounded-2xl border overflow-hidden hover:shadow-md transition-all',
      isExpired ? 'border-gray-200 opacity-70' : 'border-gray-100')}>
      {/* Top bar with category */}
      <div className={cn('px-4 py-2 flex items-center justify-between text-sm',
        isExpired ? 'bg-gray-50' : 'bg-gradient-to-r from-amber-50 to-orange-50')}>
        <span>{catEmoji[challenge.category]} {challenge.category}</span>
        <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium', diffConfig?.color ?? 'bg-gray-100')}>
          {diffConfig?.label?.replace(/🟢|🟡|🔴/g, '').trim() ?? challenge.difficulty}
        </span>
      </div>

      <div className="p-4">
        <h3 className="font-bold text-gray-900">{challenge.title}</h3>
        {challenge.description && <p className="text-xs text-gray-500 mt-1 line-clamp-2">{challenge.description}</p>}

        <div className="flex items-center gap-3 mt-3 text-xs text-gray-400">
          <span className="flex items-center gap-1"><Users className="w-3 h-3" /> {challenge.participant_count} Teilnehmer</span>
          <span className="flex items-center gap-1"><Star className="w-3 h-3 text-amber-400" /> {challenge.points} Pkt</span>
          <span className="flex items-center gap-1">
            <Clock className="w-3 h-3" /> {isExpired ? 'Beendet' : `${daysLeft}d übrig`}
          </span>
        </div>

        {/* Progress bar if joined */}
        {isJoined && progress && (
          <div className="mt-3">
            <div className="flex items-center justify-between text-xs mb-1">
              <span className="text-amber-600 font-medium">Dein Fortschritt</span>
              <span className="text-gray-500">{progress.progress_pct}%</span>
            </div>
            <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-amber-400 to-orange-500 rounded-full transition-all"
                style={{ width: `${progress.progress_pct}%` }} />
            </div>
          </div>
        )}

        {!isExpired && (
          <div className="mt-3">
            {isJoined ? (
              <div className="flex items-center gap-2 text-xs text-emerald-600 font-medium">
                <CheckCircle2 className="w-4 h-4" /> Du nimmst teil!
              </div>
            ) : (
              <button onClick={() => onJoin(challenge.id)}
                className="w-full py-1.5 bg-amber-500 text-white rounded-lg text-xs font-medium hover:bg-amber-600 transition-all flex items-center justify-center gap-1">
                <Zap className="w-3.5 h-3.5" /> Teilnehmen
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Main Challenges Page ────────────────────────────────────────
export default function ChallengesPage() {
  const [challenges, setChallenges] = useState<Challenge[]>([])
  const [myProgress, setMyProgress] = useState<Map<string, ChallengeProgress>>(new Map())
  const [userId, setUserId] = useState<string>()
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterCat, setFilterCat] = useState('all')
  const [tab, setTab] = useState<'active' | 'mine' | 'completed'>('active')
  const [showCreate, setShowCreate] = useState(false)

  const loadData = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    const [challRes, progRes] = await Promise.all([
      supabase.from('challenges').select('*').order('created_at', { ascending: false }),
      user ? supabase.from('challenge_progress').select('*').eq('user_id', user.id) : Promise.resolve({ data: [] }),
    ])

    setChallenges(challRes.data ?? [])
    const pMap = new Map<string, ChallengeProgress>()
    ;(progRes.data ?? []).forEach((p: any) => pMap.set(p.challenge_id, p))
    setMyProgress(pMap)
    setLoading(false)
  }, [])

  useEffect(() => { loadData() }, [loadData])

  const handleJoin = async (challengeId: string) => {
    if (!userId) { toast.error('Bitte einloggen'); return }
    const supabase = createClient()
    const { error } = await supabase.from('challenge_progress').insert({
      challenge_id: challengeId,
      user_id: userId,
      status: 'active',
      progress_pct: 0,
    })
    if (error) {
      if (error.code === '23505') toast.error('Du nimmst bereits teil')
      else toast.error('Fehler beim Beitreten')
      return
    }
    const ch = challenges.find(c => c.id === challengeId)
    if (ch) {
      await supabase.from('challenges').update({ participant_count: ch.participant_count + 1 }).eq('id', challengeId)
    }
    toast.success('Du nimmst teil! 🎯')
    loadData()
  }

  const now = Date.now()
  const filtered = challenges.filter(c => {
    const isActive = new Date(c.end_date).getTime() > now
    if (tab === 'active' && !isActive) return false
    if (tab === 'mine' && !myProgress.has(c.id)) return false
    if (tab === 'completed' && isActive) return false
    if (filterCat !== 'all' && c.category !== filterCat) return false
    if (searchTerm && !c.title.toLowerCase().includes(searchTerm.toLowerCase())) return false
    return true
  })

  const totalPoints = Array.from(myProgress.values())
    .filter(p => p.status === 'completed')
    .reduce((sum, p) => sum + (challenges.find(c => c.id === p.challenge_id)?.points ?? 0), 0)

  return (
    <div className="min-h-screen bg-gradient-to-b from-amber-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-amber-500 to-orange-600 text-white px-4 sm:px-6 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm"><Trophy className="w-6 h-6" /></div>
            <h1 className="text-2xl font-bold">Challenges</h1>
          </div>
          <p className="text-amber-100 text-sm">Nimm an Challenges teil, sammle Punkte und mache die Welt besser</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              🏆 {challenges.filter(c => new Date(c.end_date).getTime() > now).length} aktive Challenges
            </div>
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              ⭐ {totalPoints} Punkte gesammelt
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 -mt-4">
        {/* Filter */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-amber-500" placeholder="Challenge suchen..." />
            </div>
            <select value={filterCat} onChange={e => setFilterCat(e.target.value)}
              className="px-3 py-2 border rounded-xl text-sm focus:ring-2 focus:ring-amber-500">
              <option value="all">Alle Kategorien</option>
              {CHALLENGE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
            <button onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-4 py-2 bg-amber-500 text-white rounded-xl text-sm font-medium hover:bg-amber-600 transition-all">
              <Plus className="w-4 h-4" /> Neue Challenge
            </button>
          </div>

          <div className="flex gap-1 mt-3 bg-gray-50 rounded-xl p-1">
            {[
              { key: 'active' as const, label: '🔥 Aktiv' },
              { key: 'mine' as const, label: '🎯 Meine' },
              { key: 'completed' as const, label: '✅ Beendet' },
            ].map(t => (
              <button key={t.key} onClick={() => setTab(t.key)}
                className={cn('flex-1 py-1.5 rounded-lg text-xs font-medium transition-all',
                  tab === t.key ? 'bg-white text-amber-700 shadow-sm' : 'text-gray-500 hover:text-gray-700')}>
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
          <div className="text-center py-16">
            <Trophy className="w-12 h-12 text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500 font-medium">Keine Challenges gefunden</p>
            <button onClick={() => setShowCreate(true)} className="mt-3 text-sm text-amber-600 hover:text-amber-700 font-medium">
              Erstelle die erste Challenge →
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-8">
            {filtered.map(c => (
              <ChallengeCard key={c.id} challenge={c} isJoined={myProgress.has(c.id)}
                progress={myProgress.get(c.id)} onJoin={handleJoin} />
            ))}
          </div>
        )}
      </div>

      {showCreate && <CreateChallengeModal onClose={() => setShowCreate(false)} onCreated={loadData} />}
    </div>
  )
}
