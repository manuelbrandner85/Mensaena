'use client'

import { useRef } from 'react'
import { useSectionProgress } from '../hooks/useSectionProgress'

/**
 * StickyManifesto — gepinnter typografischer Höhepunkt.
 *
 * Beim Scrollen leuchtet das Manifest Wort für Wort auf (Scroll-Scrubbing der
 * Opazität). Imperativ pro Frame, kein Re-Render. Bei prefers-reduced-motion
 * (Hook setzt --p=0) steht der Satz vollständig sichtbar (siehe CSS-Fallback).
 */

const LEAD = 'Eine Stadt'
const STATEMENT =
  'ist kein Ort. Sie ist das, was Nachbarn füreinander tun — jeden Tag, ganz konkret, kostenlos.'

export default function StickyManifesto() {
  const sectionRef = useRef<HTMLElement>(null)
  const wordRefs = useRef<Array<HTMLSpanElement | null>>([])

  const words = STATEMENT.split(' ')

  useSectionProgress(sectionRef, (p) => {
    const n = words.length
    // Reveal über die ersten ~78% des Scrolls, danach steht alles
    const span = 0.78
    for (let i = 0; i < n; i++) {
      const start = (i / n) * span
      const end = start + span / n + 0.04
      const wp = end > start ? (p - start) / (end - start) : 1
      const v = wp < 0 ? 0 : wp > 1 ? 1 : wp
      const el = wordRefs.current[i]
      if (el) el.style.opacity = (0.12 + 0.88 * v).toFixed(3)
    }
  })

  return (
    <section ref={sectionRef} className="cin-manifest" style={{ height: '230vh' }} aria-label="Manifest">
      <div className="cin-manifest-stage">
        <div className="cin-wrap">
          <div className="cin-eyebrow">— Manifest</div>
          <p className="cin-manifest-text">
            <span className="lead">{LEAD}</span>{' '}
            {words.map((w, i) => (
              <span
                key={i}
                className="w"
                ref={(el) => {
                  wordRefs.current[i] = el
                }}
              >
                {w}{' '}
              </span>
            ))}
          </p>
        </div>
      </div>
    </section>
  )
}
