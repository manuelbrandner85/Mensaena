'use client'

import { useEffect } from 'react'
import Lenis from 'lenis'

/**
 * SmoothScroll — globaler Lenis-Provider.
 *
 * Wird im CinemaLayout gemountet. Filmisches Scroll-Feeling.
 * Bei prefers-reduced-motion: Lenis deaktiviert, native Scroll bleibt.
 */
export default function SmoothScroll({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (typeof window === 'undefined') return
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduced) return

    const lenis = new Lenis({
      duration:        1.4,
      smoothWheel:     true,
      wheelMultiplier: 0.8,
      touchMultiplier: 1.5,
    })

    let rafId = 0
    const raf = (time: number) => {
      lenis.raf(time)
      rafId = requestAnimationFrame(raf)
    }
    rafId = requestAnimationFrame(raf)

    return () => {
      cancelAnimationFrame(rafId)
      lenis.destroy()
    }
  }, [])

  return <>{children}</>
}
