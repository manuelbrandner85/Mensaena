'use client'

import { useEffect, useState } from 'react'

/**
 * AnamorphicFlare — horizontaler Licht-Streak.
 *
 * Wird einmal pro Mount/Trigger angezeigt. Steuerung per `show` Prop
 * (z.B. von framer-motion InView in der Hero-Sektion).
 */
type Props = {
  show?: boolean
  /** Vertikale Position (0–1, 0.5 = Mitte). */
  top?: string
  /** Dauer der ganzen Animation in ms. */
  duration?: number
}

export default function AnamorphicFlare({
  show = true,
  top = '50%',
  duration = 1800,
}: Props) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (!show) return
    setVisible(true)
    const t = window.setTimeout(() => setVisible(false), duration)
    return () => window.clearTimeout(t)
  }, [show, duration])

  if (!visible) return null

  return (
    <div
      aria-hidden="true"
      className="cinema-flare pointer-events-none fixed left-1/2 z-[36] -translate-x-1/2"
      style={{
        top,
        width: '45vw',
        height: '1px',
        filter: 'blur(3px)',
        boxShadow: '0 0 20px rgba(199,147,99,0.10)',
        background:
          'linear-gradient(90deg, transparent, rgba(199,147,99,0.12) 30%, rgba(199,147,99,0.20) 50%, rgba(199,147,99,0.12) 70%, transparent)',
        animation: `anamorphicFlare ${duration}ms ease-in-out forwards`,
      }}
    />
  )
}
