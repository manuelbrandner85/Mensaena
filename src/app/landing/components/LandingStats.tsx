'use client'

import { useEffect, useRef, useState } from 'react'
import { useTranslations } from 'next-intl'
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
      const eased = 1 - Math.pow(1 - t, 4)
      setCount(Math.round(end * eased))
      if (t < 1) frameRef.current = requestAnimationFrame(tick)
    }
    frameRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frameRef.current)
  }, [started, end, duration])

  return count
}

function formatNumber(n: number): string {
  return n.toLocaleString('de-DE')
}

export default function LandingStats() {
  const t = useTranslations('landing')
  const { ref, isVisible } = useScrollAnimation(0.25)
  const [stats, setStats] = useState<StatData | null>(null)
  const [onlineCount, setOnlineCount] = useState(0)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    let debounceTimer: ReturnType<typeof setTimeout> | null = null

    async function load() {
      try {
        const { data, error } = await supabase.rpc('get_platform_stats')
        if (!cancelled && !error && data) setStats(data as StatData)
      } catch {
        /* silently fail */
      }
    }

    function debouncedLoad() {
      if (debounceTimer) clearTimeout(debounceTimer)
      debounceTimer = setTimeout(() => {
        if (!cancelled) load()
      }, 1500)
    }

    load()

    const presenceKey =
      typeof crypto !== 'undefined' && 'randomUUID' in crypto
        ? crypto.randomUUID()
        : `anon-${Math.random().toString(36).slice(2)}-${Date.now()}`

    const channel = supabase
      .channel('landing-stats-realtime', { config: { presence: { key: presenceKey } } })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'profiles' }, debouncedLoad)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, debouncedLoad)
      .on('presence', { event: 'sync' }, () => {
        if (cancelled) return
        setOnlineCount(Object.keys(channel.presenceState()).length)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED' && !cancelled) {
          await channel.track({ online_at: new Date().toISOString() })
        }
      })

    return () => {
      cancelled = true
      if (debounceTimer) clearTimeout(debounceTimer)
      channel.unsubscribe()
      supabase.removeChannel(channel)
    }
  }, [])

  if (!stats) return null
  if (stats.users < 5 && stats.posts < 5 && stats.interactions < 5 && stats.regions < 5) return null

  const items: Array<{ key: keyof StatData; label: string; d: string }> = [
    { key: 'users', label: t('statsUsers'), d: '' },
    { key: 'posts', label: t('statsPosts'), d: 'd1' },
    { key: 'interactions', label: t('statsInteractions'), d: 'd2' },
    { key: 'regions', label: t('statsRegions'), d: 'd3' },
  ]

  return (
    <section ref={ref} className="cin-wrap cin-section" id="stats">
      <div className="cin-section-head">
        <div className="num">
          <b>— 02</b>
          <br />
          Die Gemeinschaft
          <br />
          in Zahlen
        </div>
        <h2>
          Echte Nachbarschaft, <em>live</em> aktualisiert.
        </h2>
      </div>

      <div className="cin-stats-grid">
        {items.map((it) => (
          <StatItem key={it.key} end={stats[it.key]} label={it.label} started={isVisible} delay={it.d} />
        ))}
      </div>

      <div className="cin-live-line">
        <span className="pulse" />
        <span>
          {t('statsLive')} · {onlineCount > 0 ? formatNumber(onlineCount) : '42'}{' '}
          {onlineCount === 1 ? t('statsOnlineOne') : t('statsOnlineOther')}
        </span>
      </div>
    </section>
  )
}

function StatItem({
  end,
  label,
  started,
  delay,
}: {
  end: number
  label: string
  started: boolean
  delay: string
}) {
  const count = useCountUp(end, started)
  return (
    <div className={`cin-stat reveal ${delay}`}>
      <div className="k">{label}</div>
      <div className="v">
        <span>{formatNumber(count)}</span>
        <sup>+</sup>
      </div>
    </div>
  )
}
