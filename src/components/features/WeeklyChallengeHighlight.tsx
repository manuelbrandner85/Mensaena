'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Sparkles, Trophy, ArrowRight } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

interface Challenge {
  id: string
  title: string
  description: string | null
  category: string
  difficulty: string
  points: number
  participant_count: number
}

/**
 * WeeklyChallengeHighlight – Zeigt die aktiven Wochen-Challenges im Dashboard.
 * Liest `challenges` mit `is_weekly=true` und `week_of` für die aktuelle Woche.
 */
export default function WeeklyChallengeHighlight() {
  const [challenges, setChallenges] = useState<Challenge[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const supabase = createClient()
      // week_of = montag dieser Woche
      const monday = new Date()
      const day = monday.getDay() || 7
      monday.setDate(monday.getDate() - day + 1)
      const weekOf = monday.toISOString().slice(0, 10)

      const { data, error } = await supabase
        .from('challenges')
        .select('id, title, description, category, difficulty, points, participant_count')
        .eq('is_weekly', true)
        .eq('week_of', weekOf)
        .order('points', { ascending: false })
        .limit(3)
      if (cancelled) return
      if (error) {
        console.error('weekly challenges load failed:', error.message)
        setChallenges([])
      } else {
        setChallenges(data ?? [])
      }
      setLoading(false)
    })()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return (
      <div className="rounded-2xl border border-warm-200 bg-white p-5 animate-pulse">
        <div className="h-4 w-48 bg-stone-200 rounded mb-3" />
        <div className="h-3 w-64 bg-stone-100 rounded" />
      </div>
    )
  }

  if (challenges.length === 0) return null

  return (
    <section className="rounded-2xl border border-warm-200 bg-gradient-to-br from-amber-50 via-white to-primary-50/40 shadow-soft p-5">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 text-amber-700 flex items-center justify-center flex-shrink-0">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-ink-900">Challenges dieser Woche</h3>
            <p className="text-xs text-ink-500 mt-0.5">Drei wöchentliche Impulse zum Mitmachen.</p>
          </div>
        </div>
        <Link
          href="/dashboard/challenges"
          className="inline-flex items-center gap-1 text-[11px] font-semibold text-primary-700 hover:text-primary-800"
        >
          Alle <ArrowRight className="w-3 h-3" />
        </Link>
      </div>
      <ul className="space-y-2">
        {challenges.map(c => (
          <li key={c.id} className="rounded-xl border border-stone-100 bg-white p-3">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-ink-900 truncate">{c.title}</p>
                {c.description && <p className="text-xs text-ink-500 mt-0.5 line-clamp-2">{c.description}</p>}
              </div>
              <span className="inline-flex items-center gap-1 flex-shrink-0 px-2 py-0.5 text-[11px] font-semibold bg-amber-50 border border-amber-200 text-amber-800 rounded-full">
                <Trophy className="w-3 h-3" /> {c.points}
              </span>
            </div>
          </li>
        ))}
      </ul>
    </section>
  )
}
