'use client'

import { useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/design-system'

interface CinemaStatProps {
  value: number
  label: string
  suffix?: string
  prefix?: string
  icon?: React.ReactNode
  className?: string
}

export default function CinemaStat({ value, label, suffix, prefix, icon, className }: CinemaStatProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [current, setCurrent] = useState(0)
  const [hasStarted, setHasStarted] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !hasStarted) {
          setHasStarted(true)
          const duration = 2000
          const start = performance.now()
          const tick = (now: number) => {
            const t = Math.min((now - start) / duration, 1)
            const ease = 1 - Math.pow(1 - t, 3)
            setCurrent(Math.round(ease * value))
            if (t < 1) requestAnimationFrame(tick)
          }
          requestAnimationFrame(tick)
        }
      },
      { threshold: 0.5 },
    )
    obs.observe(el)
    return () => obs.disconnect()
  }, [value, hasStarted])

  return (
    <div ref={ref} className={cn('flex flex-col items-center gap-1 p-5 bg-mn-surface rounded-card border border-white/5 shadow-cinema-card', className)}>
      {icon && <div className="text-mn-teal mb-1">{icon}</div>}
      <div
        className="font-mono text-3xl font-semibold text-mn-bronze leading-none"
        aria-live="polite"
      >
        {prefix}{current.toLocaleString('de-DE')}{suffix}
      </div>
      <div className="text-sm text-mn-mute">{label}</div>
    </div>
  )
}
