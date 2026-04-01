'use client'

import { useEffect, useRef, useState } from 'react'

interface CountUpProps {
  to: number
  duration?: number   // ms
  suffix?: string
  className?: string
}

/**
 * Animated count-up number.
 * Uses requestAnimationFrame for smooth 60fps counting.
 */
export default function CountUp({ to, duration = 800, suffix = '', className = '' }: CountUpProps) {
  const [display, setDisplay] = useState(0)
  const startRef  = useRef<number | null>(null)
  const rafRef    = useRef<number>(0)
  const startedAt = useRef(0)

  useEffect(() => {
    if (to === 0) { setDisplay(0); return }

    const startVal = 0
    startedAt.current = performance.now()

    const tick = (now: number) => {
      const elapsed = now - startedAt.current
      const progress = Math.min(elapsed / duration, 1)
      // ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplay(Math.round(startVal + (to - startVal) * eased))
      if (progress < 1) {
        rafRef.current = requestAnimationFrame(tick)
      }
    }

    rafRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(rafRef.current)
  }, [to, duration])

  return (
    <span className={className}>
      {display.toLocaleString('de-AT')}{suffix}
    </span>
  )
}
