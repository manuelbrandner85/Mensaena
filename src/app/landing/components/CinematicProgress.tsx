'use client'

import { useEffect, useRef, useState } from 'react'

/**
 * CinematicProgress — globale Scroll-Fortschrittsanzeige (Agentur-Politur).
 *
 * Feine Bronze-Linie am oberen Rand füllt sich mit dem Seiten-Scroll; rechts
 * ein dezenter Akt-Zähler. Rein imperativ (rAF), kein Re-Render pro Frame.
 * Bei prefers-reduced-motion ausgeblendet.
 */
const ACTS = ['Ankommen', 'Verbinden', 'Welten', 'Manifest', 'Mitmachen']

export default function CinematicProgress() {
  const barRef = useRef<HTMLDivElement>(null)
  const actRef = useRef<HTMLSpanElement>(null)
  const [show, setShow] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    setShow(true)

    let raf = 0
    let lastAct = -1
    const update = () => {
      raf = 0
      const doc = document.documentElement
      const max = doc.scrollHeight - window.innerHeight
      const p = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0
      if (barRef.current) barRef.current.style.transform = `scaleX(${p.toFixed(4)})`
      const actIdx = Math.min(ACTS.length - 1, Math.floor(p * ACTS.length))
      if (actIdx !== lastAct && actRef.current) {
        lastAct = actIdx
        actRef.current.textContent = `${String(actIdx + 1).padStart(2, '0')} · ${ACTS[actIdx]}`
      }
    }
    const onScroll = () => {
      if (raf) return
      raf = requestAnimationFrame(update)
    }
    update()
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })
    return () => {
      if (raf) cancelAnimationFrame(raf)
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
    }
  }, [])

  if (!show) return null

  return (
    <>
      <div className="cin-prog" aria-hidden="true">
        <div ref={barRef} className="cin-prog-bar" />
      </div>
      <div className="cin-prog-act" aria-hidden="true">
        <span ref={actRef} className="cin-prog-act-label">01 · Ankommen</span>
      </div>
    </>
  )
}
