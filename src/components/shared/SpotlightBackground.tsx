'use client'

import { useEffect, useRef } from 'react'

/**
 * SpotlightBackground — tracks the cursor and publishes `--mx`/`--my`
 * CSS variables on the root element so any nested `.spotlight` card
 * gets a radial glow that follows the mouse.
 *
 * Wrap sections or page containers with it; it emits CSS vars on its
 * own root div and uses pointer events without capturing them.
 */
export default function SpotlightBackground({
  children,
  className = '',
}: {
  children: React.ReactNode
  className?: string
}) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    // Respect reduced motion
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    let raf = 0
    const onMove = (e: MouseEvent) => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const rect = el.getBoundingClientRect()
        const mx = ((e.clientX - rect.left) / rect.width) * 100
        const my = ((e.clientY - rect.top) / rect.height) * 100
        el.style.setProperty('--mx', `${mx}%`)
        el.style.setProperty('--my', `${my}%`)
      })
    }
    el.addEventListener('mousemove', onMove)
    return () => {
      el.removeEventListener('mousemove', onMove)
      cancelAnimationFrame(raf)
    }
  }, [])

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  )
}
