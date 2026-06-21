'use client'

import { useRef } from 'react'
import Link from 'next/link'
import { useSectionProgress } from '../hooks/useSectionProgress'

/**
 * PinnedModules — gepinnte horizontale „Hilfe-Welten"-Galerie.
 *
 * Vertikales Scrollen treibt eine horizontale Filmstrip-Bewegung (Agentur-
 * Scrollytelling). Jede Welt ist eine cinematische Karte mit eigenem Farbklang
 * (Dusk-Palette). Vorbereitet für cinematische Thumbnails: das `.scene` der
 * Karte kann später durch ein <img>/<canvas> mit KI-gerendertem Frame ersetzt werden.
 *
 * Bei prefers-reduced-motion: --p=0 (Hook), Track steht → die Karten sind als
 * horizontal scrollbarer Streifen weiterhin erreichbar (overflow-x:auto via CSS).
 */

type World = {
  no: string
  title: string
  line: string
  hue: string // CSS-Gradient als Fallback / Tönung unter dem Bild
  img: string // KI-Dorf-Vignette (Higgsfield)
}

const WORLDS: World[] = [
  {
    no: '01',
    title: 'Werkzeug & Dinge',
    line: 'Bohrmaschine, Leiter, Anhänger — leihen statt kaufen, direkt von nebenan.',
    hue: 'linear-gradient(140deg,#15303a,#0b1a22 60%,#081319)',
    img: '/dorf/world-01.webp',
  },
  {
    no: '02',
    title: 'Zeit & Hände',
    line: 'Einkauf, Umzug, ein offenes Ohr. Hilfe, die in Minuten ankommt.',
    hue: 'linear-gradient(140deg,#3a2a18,#1b130b 60%,#0d0a06)',
    img: '/dorf/world-02.webp',
  },
  {
    no: '03',
    title: 'Krisen & Notlagen',
    line: 'Hochwasser, Stromausfall, akute Not — die Nachbarschaft mobilisiert sofort.',
    hue: 'linear-gradient(140deg,#3a1614,#1f0d0c 60%,#120807)',
    img: '/dorf/world-03.webp',
  },
  {
    no: '04',
    title: 'Wohnen & Viertel',
    line: 'Schwarzes Brett, Mitfahrten, Treffpunkte. Das Viertel, das zusammenhält.',
    hue: 'linear-gradient(140deg,#163039,#0e2129 60%,#081319)',
    img: '/dorf/world-04.webp',
  },
  {
    no: '05',
    title: 'Wissen & Können',
    line: 'Reparieren, lernen, weitergeben. Jede Fähigkeit zählt für alle.',
    hue: 'linear-gradient(140deg,#2b3a2a,#15201a 60%,#0a0f0c)',
    img: '/dorf/world-05.webp',
  },
  {
    no: '06',
    title: 'Tiere & Garten',
    line: 'Gassi, Pflanzengießen, Ernte teilen. Fürsorge, die verbindet.',
    hue: 'linear-gradient(140deg,#2e3417,#181c0c 60%,#0c0e06)',
    img: '/dorf/world-06.webp',
  },
  {
    no: '07',
    title: 'Gemeinschaft',
    line: 'Gruppen, Events, gemeinsame Sache. Aus Nachbarn wird ein Wir.',
    hue: 'linear-gradient(140deg,#2b2440,#15122099 60%,#0b0a14)',
    img: '/dorf/world-07.webp',
  },
]

export default function PinnedModules() {
  const sectionRef = useRef<HTMLElement>(null)
  const trackRef = useRef<HTMLDivElement>(null)
  const stageRef = useRef<HTMLDivElement>(null)

  useSectionProgress(sectionRef, (p) => {
    const track = trackRef.current
    const stage = stageRef.current
    if (!track || !stage) return
    const overflow = track.scrollWidth - stage.clientWidth
    if (overflow > 0) {
      track.style.transform = `translate3d(${-(p * overflow).toFixed(1)}px,0,0)`
    }
  })

  return (
    <section
      ref={sectionRef}
      className="cin-worlds"
      style={{ height: `${WORLDS.length * 60 + 60}vh` }}
      aria-label="Hilfe-Welten"
    >
      <div ref={stageRef} className="cin-worlds-stage">
        <div className="cin-worlds-head">
          <div className="cin-eyebrow">— Welten der Hilfe</div>
          <h2>
            Sieben Welten
            <br />
            <em>der Hilfe.</em>
          </h2>
          <p className="cin-worlds-hint" aria-hidden="true">Scrollen →</p>
        </div>

        <div ref={trackRef} className="cin-worlds-track">
          {WORLDS.map((w) => (
            <Link
              key={w.no}
              href="/auth?mode=register"
              className="cin-world"
              style={{ ['--scene' as string]: w.hue }}
            >
              <div className="cin-world-scene" aria-hidden="true">
                <img src={w.img} alt="" loading="lazy" decoding="async" className="photo" />
                <span className="scrim" />
                <span className="grain" />
                <span className="glow" />
              </div>
              <div className="cin-world-body">
                <span className="no">{w.no}</span>
                <h3>{w.title}</h3>
                <p>{w.line}</p>
                <span className="go">Entdecken <i>→</i></span>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  )
}
