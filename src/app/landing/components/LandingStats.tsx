'use client'

import { useEffect, useState, useRef } from 'react'
import { Users, HandHeart, CheckCircle, MapPin } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

interface StatData {
  users: number
  posts: number
  interactions: number
  regions: number
}

function useCountUp(end: number, started: boolean, duration = 2000) {
  const [count, setCount] = useState(0)
  const frameRef = useRef<number>(0)

  useEffect(() => {
    if (!started || end <= 0) return
    const step = Math.max(1, Math.floor(end / (duration / 16)))
    let current = 0

    const tick = () => {
      current += step
      if (current >= end) {
        setCount(end)
      } else {
        setCount(current)
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
  { key: 'users' as const, label: 'Aktive Nachbarn', Icon: Users },
  { key: 'posts' as const, label: 'Hilfsangebote', Icon: HandHeart },
  { key: 'interactions' as const, label: 'Erfolgreiche Interaktionen', Icon: CheckCircle },
  { key: 'regions' as const, label: 'Nachbarschaften', Icon: MapPin },
]

export default function LandingStats() {
  const { ref, isVisible } = useScrollAnimation(0.15)
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
        // Silently fail – section will not render
      }
    }
    load()
  }, [])

  // Don't render if no data or all values < 5
  if (!stats) return null
  const allSmall = stats.users < 5 && stats.posts < 5 && stats.interactions < 5 && stats.regions < 5
  if (allSmall) return null

  return (
    <section
      ref={ref}
      id="stats"
      className="green-gradient text-white py-12 md:py-16 px-4"
    >
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
          {statConfig.map(({ key, label, Icon }) => (
            <StatItem
              key={key}
              end={stats[key]}
              label={label}
              Icon={Icon}
              started={isVisible}
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
  Icon,
  started,
}: {
  end: number
  label: string
  Icon: React.ComponentType<{ className?: string }>
  started: boolean
}) {
  const count = useCountUp(end, started)

  return (
    <div className="text-center">
      <Icon className="w-8 h-8 text-white/70 mx-auto mb-2" aria-hidden="true" />
      <div className="text-4xl md:text-5xl font-extrabold">{formatNumber(count)}</div>
      <div className="text-white/80 text-sm mt-1">{label}</div>
    </div>
  )
}
