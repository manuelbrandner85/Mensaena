'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import { X, FileText, Users, HandHelping, Heart, Trophy } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

const STORAGE_KEY = 'mensaena_last_digest_seen'
const SHOW_INTERVAL_MS = 6 * 24 * 60 * 60 * 1000 // 6 days

interface DigestData {
  newPosts: number
  completedHelps: number
  newNeighbors: number
  personalImpact: number
  popularPost: { id: string; title: string; votes: number } | null
}

interface WeeklyDigestProps {
  userId: string
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function shouldShowDigest(): boolean {
  if (typeof window === 'undefined') return false
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return true
    const lastSeen = Number(raw)
    if (Number.isNaN(lastSeen)) return true
    // Always allow on Mondays after the 6-day cooldown is up
    const isMonday = new Date().getDay() === 1
    const longEnough = Date.now() - lastSeen > SHOW_INTERVAL_MS
    return isMonday || longEnough
  } catch {
    return true
  }
}

function useCountUp(target: number, durationMs = 900): number {
  const [value, setValue] = useState(0)
  const startRef = useRef<number | null>(null)
  useEffect(() => {
    startRef.current = null
    let raf = 0
    const tick = (t: number) => {
      if (startRef.current === null) startRef.current = t
      const progress = Math.min(1, (t - startRef.current) / durationMs)
      setValue(Math.round(target * progress))
      if (progress < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, durationMs])
  return value
}

// ── Stat cell ────────────────────────────────────────────────────────────────

function StatCell({
  icon: Icon,
  label,
  value,
  accent,
}: {
  icon: React.ComponentType<{ className?: string }>
  label: string
  value: number
  accent: string
}) {
  const animated = useCountUp(value)
  return (
    <div className="bg-white/80 backdrop-blur-sm rounded-xl p-3.5 border border-white/50">
      <div className={`inline-flex items-center justify-center w-7 h-7 rounded-lg ${accent} mb-1.5`}>
        <Icon className="w-4 h-4 text-white" />
      </div>
      <p className="text-2xl font-bold text-ink-800 leading-none tabular-nums">{animated}</p>
      <p className="text-[11px] text-ink-500 mt-1 leading-tight">{label}</p>
    </div>
  )
}

// ── Main component ───────────────────────────────────────────────────────────

export default function WeeklyDigest({ userId }: WeeklyDigestProps) {
  const [show, setShow] = useState(false)
  const [data, setData] = useState<DigestData | null>(null)

  const dismiss = useCallback(() => {
    try { localStorage.setItem(STORAGE_KEY, String(Date.now())) } catch {}
    setShow(false)
  }, [])

  useEffect(() => {
    if (!shouldShowDigest()) return
    setShow(true)

    let cancelled = false
    const supabase = createClient()
    const sinceIso = new Date(Date.now() - 7 * 86_400_000).toISOString()

    const run = async () => {
      const [newPostsRes, completedRes, neighborsRes, votesRes, personalRes] = await Promise.allSettled([
        supabase.from('posts').select('*', { count: 'exact', head: true }).gt('created_at', sinceIso).eq('status', 'active'),
        (supabase.from('interactions') as unknown as ReturnType<typeof supabase.from>)
          .select('*', { count: 'exact', head: true })
          .eq('status', 'completed')
          .gt('updated_at', sinceIso),
        supabase.from('profiles').select('*', { count: 'exact', head: true }).gt('created_at', sinceIso),
        supabase.from('post_votes').select('post_id').eq('vote', 1).gt('created_at', sinceIso).limit(500),
        (supabase.from('interactions') as unknown as ReturnType<typeof supabase.from>)
          .select('*', { count: 'exact', head: true })
          .or(`offerer_id.eq.${userId},requester_id.eq.${userId}`)
          .gt('updated_at', sinceIso),
      ])

      const countOf = (r: PromiseSettledResult<{ count: number | null }>): number =>
        r.status === 'fulfilled' ? r.value.count ?? 0 : 0

      // Popular post: tally votes client-side
      let popularPost: DigestData['popularPost'] = null
      if (votesRes.status === 'fulfilled' && votesRes.value.data) {
        const tally = new Map<string, number>()
        for (const row of votesRes.value.data as { post_id: string }[]) {
          tally.set(row.post_id, (tally.get(row.post_id) ?? 0) + 1)
        }
        const top = [...tally.entries()].sort((a, b) => b[1] - a[1])[0]
        if (top) {
          const { data: post } = await supabase
            .from('posts')
            .select('id, title')
            .eq('id', top[0])
            .maybeSingle()
          if (post) popularPost = { id: post.id as string, title: post.title as string, votes: top[1] }
        }
      }

      if (cancelled) return
      setData({
        newPosts:        countOf(newPostsRes),
        completedHelps:  countOf(completedRes),
        newNeighbors:    countOf(neighborsRes),
        personalImpact:  countOf(personalRes),
        popularPost,
      })
    }

    run()
    return () => { cancelled = true }
  }, [userId])

  if (!show || !data) return null

  const {
    newPosts, completedHelps, newNeighbors, personalImpact, popularPost,
  } = data

  // If literally nothing happened, skip rendering to avoid a sad empty card
  const nothingNew = newPosts === 0 && completedHelps === 0 && newNeighbors === 0 && personalImpact === 0
  if (nothingNew) return null

  return (
    <div
      className="relative rounded-2xl p-5 text-white overflow-hidden shadow-card animate-slide-up"
      style={{
        background: 'linear-gradient(135deg, #1EAAA6 0%, #4F6D8A 100%)',
      }}
    >
      <button
        type="button"
        onClick={dismiss}
        aria-label="Ausblenden"
        className="absolute top-3 right-3 w-8 h-8 rounded-full flex items-center justify-center bg-white/10 hover:bg-white/25 transition-colors"
      >
        <X className="w-4 h-4 text-white" />
      </button>

      <div className="mb-4">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-white/70">
          Wochenrückblick
        </p>
        <h3 className="text-lg font-display font-bold mt-0.5">Was letzte Woche passiert ist</h3>
      </div>

      <div className="grid grid-cols-2 gap-2.5 mb-4">
        <StatCell icon={FileText}     label="Neue Beiträge in deiner Nähe" value={newPosts}       accent="bg-primary-500" />
        <StatCell icon={HandHelping}  label="Abgeschlossene Hilfen"        value={completedHelps} accent="bg-green-500"   />
        <StatCell icon={Users}        label="Neue Nachbarn"                 value={newNeighbors}   accent="bg-blue-500"    />
        <StatCell icon={Heart}        label="Deine Aktivitäten"             value={personalImpact} accent="bg-rose-500"    />
      </div>

      {popularPost && (
        <Link
          href={`/dashboard/posts/${popularPost.id}`}
          className="flex items-center gap-2.5 bg-white/10 hover:bg-white/20 rounded-xl px-3.5 py-2.5 transition-colors"
        >
          <div className="w-7 h-7 rounded-lg bg-amber-400 flex items-center justify-center flex-shrink-0">
            <Trophy className="w-4 h-4 text-amber-900" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-white/70 leading-none">
              Beliebtester Beitrag
            </p>
            <p className="text-sm font-semibold truncate">{popularPost.title}</p>
          </div>
          <span className="text-xs font-medium text-white/80 flex-shrink-0">
            ↑ {popularPost.votes}
          </span>
        </Link>
      )}
    </div>
  )
}
