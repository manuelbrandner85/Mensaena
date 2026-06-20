'use client'

import { useEffect, useRef } from 'react'

/**
 * Magnetic — Award-Site-Micro-Interaction: das Kind „zieht" sanft zum Cursor,
 * wenn er nahekommt, und federt zurück. Nur Desktop/feiner Zeiger, respektiert
 * prefers-reduced-motion.
 */
export default function Magnetic({
  children,
  strength = 0.35,
}: {
  children: React.ReactNode
  strength?: number
}) {
  const ref = useRef<HTMLSpanElement>(null)

  useEffect(() => {
    const el = ref.current
    if (!el || typeof window === 'undefined') return
    if (
      window.matchMedia('(pointer: coarse)').matches ||
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    )
      return

    let raf = 0
    const onMove = (e: MouseEvent) => {
      if (raf) return
      raf = requestAnimationFrame(() => {
        raf = 0
        const r = el.getBoundingClientRect()
        const cx = r.left + r.width / 2
        const cy = r.top + r.height / 2
        const dx = e.clientX - cx
        const dy = e.clientY - cy
        const radius = Math.max(r.width, r.height) * 1.7
        if (Math.hypot(dx, dy) < radius) {
          el.style.transform = `translate(${(dx * strength).toFixed(1)}px, ${(dy * strength).toFixed(1)}px)`
        } else if (el.style.transform) {
          el.style.transform = ''
        }
      })
    }
    window.addEventListener('mousemove', onMove, { passive: true })
    return () => {
      if (raf) cancelAnimationFrame(raf)
      window.removeEventListener('mousemove', onMove)
    }
  }, [strength])

  return (
    <span
      ref={ref}
      className="cin-magnetic"
      style={{
        display: 'inline-block',
        transition: 'transform 0.3s cubic-bezier(0.16,1,0.3,1)',
        willChange: 'transform',
      }}
    >
      {children}
    </span>
  )
}
