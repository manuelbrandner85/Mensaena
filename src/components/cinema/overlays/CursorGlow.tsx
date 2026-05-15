'use client'

import { useEffect, useRef, useState } from 'react'

/**
 * CursorGlow — dezenter amber Glow der der Maus folgt.
 *
 * Auf Touch-Devices und bei prefers-reduced-motion deaktiviert.
 */
export default function CursorGlow() {
  const ref = useRef<HTMLDivElement>(null)
  const [enabled, setEnabled] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const isTouch = window.matchMedia('(pointer: coarse)').matches
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (isTouch || reduced) return
    setEnabled(true)

    const onMove = (e: MouseEvent) => {
      if (!ref.current) return
      ref.current.style.left = `${e.clientX}px`
      ref.current.style.top  = `${e.clientY}px`
    }
    window.addEventListener('mousemove', onMove, { passive: true })
    return () => window.removeEventListener('mousemove', onMove)
  }, [])

  if (!enabled) return null

  return (
    <div
      ref={ref}
      aria-hidden="true"
      className="pointer-events-none fixed z-30 -translate-x-1/2 -translate-y-1/2"
      style={{
        width:  '300px',
        height: '300px',
        background:
          'radial-gradient(circle, rgba(199,147,99,0.04), transparent 70%)',
        transition: 'left 0.15s ease-out, top 0.15s ease-out',
        left: '-300px',
        top:  '-300px',
      }}
    />
  )
}
