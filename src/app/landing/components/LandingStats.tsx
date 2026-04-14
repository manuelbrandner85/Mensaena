'use client'

import { useEffect, useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

interface StatData {
  users: number
  posts: number
  interactions: number
  regions: number
}

function useCountUp(end: number, started: boolean, duration = 1800) {
  const [count, setCount] = useState(0)
  const frameRef = useRef<number>(0)

  useEffect(() => {
    if (!started || end <= 0) return
    const startTime = performance.now()

    const tick = (now: number) => {
      const elapsed = now - startTime
      const t = Math.min(1, elapsed / duration)
      // easeOutQuart for a classy, decelerating count-up
      const eased = 1 - Math.pow(1 - t, 4)
      setCount(Math.round(end * eased))
      if (t < 1) {
        frameRef.current = requestAnimationFrame(tick)
      }
    }

    frameRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frameRef.current)
  }, [started, end, duration])

  return count
}

function formatNumber(n: number): string {
  return n.toLocaleString('de-DE')
}

const statConfig = [
  { key: 'users' as const,        label: 'Aktive Nachbarn' },
  { key: 'posts' as const,        label: 'Hilfsangebote' },
  { key: 'interactions' as const, label: 'Interaktionen' },
  { key: 'regions' as const,      label: 'Nachbarschaften' },
]

export default function LandingStats() {
  const { ref, isVisible } = useScrollAnimation(0.25)
  const [stats, setStats] = useState<StatData | null>(null)

  useEffect(() => {
    async function load() {
      try {
        const supabase = createClient()
        const { data, error } = await supabase.rpc('get_platform_stats')
        if (!error && data) {
          setStats(data as StatData)
        }
      } catch {
        // Silently fail
      }
    }
    load()
  }, [])

  if (!stats) return null
  const allSmall =
    stats.users < 5 && stats.posts < 5 && stats.interactions < 5 && stats.regions < 5
  if (allSmall) return null

  return (
    <section
      ref={ref}
      id="stats"
      className="relative bg-paper py-24 md:py-36 px-6 md:px-10 scroll-mt-24 border-t border-stone-200"
    >
      <div className="max-w-6xl mx-auto">
        <div className="reveal meta-label mb-16">02 / Die Gemeinschaft in Zahlen</div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-x-16 gap-y-20 md:gap-y-28">
          {statConfig.map((s, i) => (
            <StatItem
              key={s.key}
              end={stats[s.key]}
              label={s.label}
              started={isVisible}
              index={i}
            />
          ))}
        </div>
      </div>
    </section>
  )
}

function StatItem({
  end,
  label,
  started,
  index,
}: {
  end: number
  label: string
  started: boolean
  index: number
}) {
  const count = useCountUp(end, started)

  return (
    <div
      className={`reveal reveal-delay-${Math.min(index + 1, 5)} flex flex-col`}
    >
      <div className="flex items-baseline gap-3 border-b border-stone-200 pb-6">
        <span className="display-numeral">{formatNumber(count)}</span>
        <span className="font-display text-2xl text-primary-600 translate-y-[-4px]">+</span>
      </div>
      <div className="mt-6 meta-label meta-label--subtle">{label}</div>
    </div>
  )
}
