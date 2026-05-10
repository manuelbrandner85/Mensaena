'use client'

import { useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/design-system'

interface CinemaProgressProps {
  value: number
  max?: number
  label?: string
  showValue?: boolean
  color?: 'amber' | 'teal' | 'herzrot' | 'leben'
  className?: string
  animate?: boolean
}

const fills = {
  amber:  'from-mn-amber to-mn-amber-warm',
  teal:   'from-mn-teal to-mn-teal-soft',
  herzrot:'from-mn-herzrot to-mn-herzrot-warm',
  leben:  'from-mn-leben to-mn-leben-soft',
}

export default function CinemaProgress({
  value, max = 100, label, showValue, color = 'amber', className, animate = true
}: CinemaProgressProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(animate ? 0 : (value / max) * 100)

  useEffect(() => {
    if (!animate) return
    const el = ref.current
    if (!el) return
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          requestAnimationFrame(() => setWidth((value / max) * 100))
          obs.disconnect()
        }
      },
      { threshold: 0.5 },
    )
    obs.observe(el)
    return () => obs.disconnect()
  }, [value, max, animate])

  return (
    <div ref={ref} className={cn('w-full', className)}>
      {(label || showValue) && (
        <div className="flex justify-between mb-1.5 text-xs text-mn-mute">
          {label && <span>{label}</span>}
          {showValue && <span className="font-mono text-mn-amber">{Math.round((value / max) * 100)}%</span>}
        </div>
      )}
      <div className="h-2 bg-mn-surface rounded-full overflow-hidden">
        <div
          className={cn('h-full rounded-full bg-gradient-to-r', fills[color])}
          style={{ width: `${width}%`, transition: animate ? 'width 0.8s ease-out' : undefined }}
        />
      </div>
    </div>
  )
}
