'use client'

import { useEffect, useState } from 'react'

/**
 * CinematicPreloader — branded Intro-Reveal beim Laden der Landingpage.
 *
 * Award-Site-Geste: dunkler Vollbild-Vorhang, der Mensaena-Wortmarke + eine
 * Bronze-Ladelinie aufbaut und dann nach oben weggleitet und den Hero freigibt.
 * Sperrt den Scroll nur während des Intros. Respektiert prefers-reduced-motion
 * (sehr kurz). Läuft nur clientseitig.
 */
export default function CinematicPreloader() {
  const [phase, setPhase] = useState<'in' | 'out' | 'done'>('in')

  useEffect(() => {
    if (typeof window === 'undefined') return
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const hold = reduced ? 300 : 2150
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const t1 = setTimeout(() => setPhase('out'), hold)
    const t2 = setTimeout(() => setPhase('done'), hold + 900)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      document.body.style.overflow = prev
    }
  }, [])

  useEffect(() => {
    if (phase === 'out' || phase === 'done') document.body.style.overflow = ''
  }, [phase])

  if (phase === 'done') return null

  return (
    <div className={`cin-preloader${phase === 'out' ? ' is-out' : ''}`} aria-hidden="true">
      <div className="cin-pre-inner">
        <div className="cin-eyebrow cin-pre-eyebrow">— Die Gemeinwohl-Plattform</div>
        <div className="cin-pre-word">
          Mensaena<i>.</i>
        </div>
        <div className="cin-pre-bar">
          <span />
        </div>
      </div>
      <div className="cin-pre-grain" />
    </div>
  )
}
