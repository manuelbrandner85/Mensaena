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
  const [onlineCount, setOnlineCount] = useState(0)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false

    async function load() {
      try {
        const { data, error } = await supabase.rpc('get_platform_stats')
        if (!cancelled && !error && data) {
          setStats(data as StatData)
        }
      } catch {
        // Silently fail
      }
    }

    load()

    const presenceKey =
      typeof crypto !== 'undefined' && 'randomUUID' in crypto
        ? crypto.randomUUID()
        : `anon-${Math.random().toString(36).slice(2)}-${Date.now()}`

    // Realtime: Stats bei neuen Profilen oder Posts automatisch aktualisieren
    // + Presence: gerade aktive Besucher auf der Landing-Page zählen
    const channel = supabase
      .channel('landing-stats-realtime', {
        config: { presence: { key: presenceKey } },
      })
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'profiles' },
        () => load(),
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'posts' },
        () => load(),
      )
      .on('presence', { event: 'sync' }, () => {
        if (cancelled) return
        const state = channel.presenceState()
        setOnlineCount(Object.keys(state).length)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED' && !cancelled) {
          await channel.track({ online_at: new Date().toISOString() })
        }
      })

    return () => {
      cancelled = true
      channel.unsubscribe()
      supabase.removeChannel(channel)
    }
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

        <div className="flex items-center justify-center gap-2 mt-6 text-sm text-stone-500">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-2 w-2 bg-teal-500" />
          </span>
          <span>Live aktualisiert</span>
          {onlineCount > 0 && (
            <>
              <span aria-hidden="true" className="text-stone-300">·</span>
              <span>
                <span className="font-medium text-stone-700">{formatNumber(onlineCount)}</span>{' '}
                {onlineCount === 1 ? 'Nachbar' : 'Nachbarn'} gerade online
              </span>
            </>
          )}
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
