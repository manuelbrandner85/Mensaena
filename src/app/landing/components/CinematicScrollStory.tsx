'use client'

import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'

/**
 * CinematicScrollStory — Scrollytelling-Herzstück der Landing-Page.
 *
 * Technik wie auf den modernsten Websites (Apple-Stil): eine cinematische
 * FRAME-SEQUENZ wird beim Scrollen Bild für Bild auf ein <canvas> "gescrubbt".
 * Darüber laufen Story-Kapitel, deren Text scroll-synchron ein- und ausblendet.
 * Komplett im Browser — kein Game-Engine-Stream, keine Plugins.
 *
 * Bildquelle: eine KI-generierte, fotorealistische Dorflandschaft-Kamerafahrt
 * (Higgsfield → 10s-Clip → ffmpeg in WebP-Frames, public/hero-seq/). Die Frames
 * sind statische WebPs, CDN-günstig und laufen auf jedem Gerät.
 *
 * Ohne Frames rendert eine cinematische CSS-Parallax-Szene (teal→ink, Bronze-
 * Horizont, Tiefen-Drift), die scroll-gesteuert "durch die Szene fährt" — sieht
 * sofort live hochwertig aus und wird automatisch durch die Frame-Sequenz
 * ersetzt, sobald sie vorliegt.
 *
 * Aktivierung der Frames:
 *   NEXT_PUBLIC_HERO_SEQ_COUNT=121   (Anzahl Frames; 0/leer = CSS-Fallback)
 *   NEXT_PUBLIC_HERO_SEQ_BASE=/hero-seq/   (Pfad)
 *   NEXT_PUBLIC_HERO_SEQ_EXT=webp
 */

const SEQ_BASE = process.env.NEXT_PUBLIC_HERO_SEQ_BASE?.trim() || '/hero-seq/'
const SEQ_COUNT = Number(process.env.NEXT_PUBLIC_HERO_SEQ_COUNT || 211)
const SEQ_EXT = process.env.NEXT_PUBLIC_HERO_SEQ_EXT?.trim() || 'webp'
const SEQ_PAD = 4

type Chapter = {
  no: string
  eyebrow: string
  title: React.ReactNode
  body: string
}

const CHAPTERS: Chapter[] = [
  {
    no: '01',
    eyebrow: 'Ankommen',
    title: (
      <>
        Eine Straße.
        <br />
        <em>Hundert Türen.</em>
      </>
    ),
    body: 'Hinter jeder ein Mensch, der etwas geben kann — oder gerade etwas braucht. Wir machen das Unsichtbare sichtbar.',
  },
  {
    no: '02',
    eyebrow: 'Verbinden',
    title: (
      <>
        Hilfe finden.
        <br />
        <em>In Minuten.</em>
      </>
    ),
    body: 'Anbieten, anfragen, antworten — direkt in deiner Nähe. Keine Bürokratie, keine Wartezeit. Nur Nachbarn.',
  },
  {
    no: '03',
    eyebrow: 'Wachsen',
    title: (
      <>
        Aus Nachbarn wird
        <br />
        <em>Gemeinschaft.</em>
      </>
    ),
    body: 'Aus kleinen Gesten wird Vertrauen. Aus Vertrauen wird ein Ort, an dem niemand allein bleibt.',
  },
  {
    no: '04',
    eyebrow: 'Mitmachen',
    title: (
      <>
        Dein Viertel,
        <br />
        <em>neu gedacht.</em>
      </>
    ),
    body: 'Kostenlos. Gemeinnützig. Von der Gemeinschaft getragen.',
  },
]

function clamp(v: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, v))
}

export default function CinematicScrollStory() {
  const sectionRef = useRef<HTMLElement>(null)
  const stageRef = useRef<HTMLDivElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const chapterRefs = useRef<Array<HTMLDivElement | null>>([])
  const [hasFrames, setHasFrames] = useState(false)
  const [reduced, setReduced] = useState(false)

  // Frame-Sequenz vorladen (nur wenn konfiguriert + erstes Bild existiert)
  const imagesRef = useRef<HTMLImageElement[]>([])
  const loadedRef = useRef(0)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const isReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    setReduced(isReduced)

    if (SEQ_COUNT <= 0 || isReduced) return

    let cancelled = false
    const probe = new Image()
    const first = `${SEQ_BASE}${String(1).padStart(SEQ_PAD, '0')}.${SEQ_EXT}`
    probe.onload = () => {
      if (cancelled) return
      setHasFrames(true)
      // alle Frames laden
      const imgs: HTMLImageElement[] = []
      for (let i = 1; i <= SEQ_COUNT; i++) {
        const img = new Image()
        img.src = `${SEQ_BASE}${String(i).padStart(SEQ_PAD, '0')}.${SEQ_EXT}`
        img.onload = () => {
          loadedRef.current++
        }
        imgs.push(img)
      }
      imagesRef.current = imgs
    }
    probe.onerror = () => {
      /* keine Frames → CSS-Fallback bleibt */
    }
    probe.src = first
    return () => {
      cancelled = true
    }
  }, [])

  // Canvas-Größe an Viewport + DPR anpassen
  useEffect(() => {
    if (!hasFrames) return
    const canvas = canvasRef.current
    if (!canvas) return
    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      canvas.width = Math.floor(window.innerWidth * dpr)
      canvas.height = Math.floor(window.innerHeight * dpr)
    }
    resize()
    window.addEventListener('resize', resize)
    return () => window.removeEventListener('resize', resize)
  }, [hasFrames])

  // Scroll-Fortschritt → Frame + Kapitel (rAF-gedrosselt, imperativ für Glätte)
  useEffect(() => {
    if (typeof window === 'undefined' || reduced) return
    const section = sectionRef.current
    const stage = stageRef.current
    if (!section || !stage) return

    let raf = 0
    let lastFrame = -1

    const drawFrame = (p: number) => {
      const imgs = imagesRef.current
      if (!hasFrames || imgs.length === 0) return
      const idx = clamp(Math.round(p * (imgs.length - 1)), 0, imgs.length - 1)
      if (idx === lastFrame) return
      const img = imgs[idx]
      if (!img || !img.complete || img.naturalWidth === 0) return
      const canvas = canvasRef.current
      const ctx = canvas?.getContext('2d')
      if (!canvas || !ctx) return
      lastFrame = idx
      const cw = canvas.width
      const ch = canvas.height
      const ir = img.naturalWidth / img.naturalHeight
      const cr = cw / ch
      let dw: number, dh: number, dx: number, dy: number
      if (ir > cr) {
        dh = ch
        dw = ch * ir
        dx = (cw - dw) / 2
        dy = 0
      } else {
        dw = cw
        dh = cw / ir
        dx = 0
        dy = (ch - dh) / 2
      }
      ctx.clearRect(0, 0, cw, ch)
      ctx.drawImage(img, dx, dy, dw, dh)
    }

    const update = () => {
      raf = 0
      const rect = section.getBoundingClientRect()
      const total = rect.height - window.innerHeight
      const p = total > 0 ? clamp(-rect.top / total, 0, 1) : 0
      stage.style.setProperty('--p', p.toFixed(4))
      drawFrame(p)

      // Kapitel-Sichtbarkeit: gleichmäßige Fenster über den Fortschritt
      const n = CHAPTERS.length
      for (let i = 0; i < n; i++) {
        const center = (i + 0.5) / n
        const dist = Math.abs(p - center)
        // innerhalb eines halben Fensters voll sichtbar, dann ausblenden
        const vis = clamp(1 - dist / (0.5 / n + 0.06), 0, 1)
        const el = chapterRefs.current[i]
        if (el) {
          el.style.opacity = vis.toFixed(3)
          el.style.transform = `translateY(${((1 - vis) * 26).toFixed(1)}px)`
          el.style.pointerEvents = vis > 0.6 ? 'auto' : 'none'
        }
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
  }, [hasFrames, reduced])

  // Reduced Motion: statische, ruhige Variante (kein Pinning, kein Scrub)
  if (reduced) {
    return (
      <section className="cin-story cin-story--static" aria-label="Mensaena Geschichte">
        <div className="cin-story-bg cin-story-bg--fallback" aria-hidden="true" />
        <div className="cin-wrap cin-story-static-wrap">
          {CHAPTERS.map((c) => (
            <div className="cin-story-chapter is-static" key={c.no}>
              <div className="cin-eyebrow">— {c.no} / {c.eyebrow}</div>
              <h2>{c.title}</h2>
              <p>{c.body}</p>
            </div>
          ))}
          <div className="cin-story-cta">
            <Link className="cin-btn primary" href="/auth?mode=register">
              Jetzt mitmachen <span className="arrow">→</span>
            </Link>
          </div>
        </div>
      </section>
    )
  }

  return (
    <section
      ref={sectionRef}
      className="cin-story"
      style={{ height: `${(CHAPTERS.length + 1) * 100}vh` }}
      aria-label="Mensaena Geschichte"
    >
      <div ref={stageRef} className="cin-story-stage">
        {/* Cinematische KI-Frame-Sequenz (Canvas-Scrubbing) … */}
        {hasFrames && <canvas ref={canvasRef} className="cin-story-canvas" aria-hidden="true" />}

        {/* … oder cinematische CSS-Parallax-Szene als Live-Fallback */}
        {!hasFrames && (
          <div className="cin-story-bg cin-story-bg--fallback" aria-hidden="true">
            <span className="layer sky" />
            <span className="layer horizon" />
            <span className="layer hills back" />
            <span className="layer hills mid" />
            <span className="layer hills front" />
            <span className="layer dust" />
          </div>
        )}

        <div className="cin-story-scrim" aria-hidden="true" />

        {/* Story-Kapitel (scroll-synchron) */}
        <div className="cin-wrap cin-story-captions">
          {CHAPTERS.map((c, i) => (
            <div
              className="cin-story-chapter"
              key={c.no}
              ref={(el) => {
                chapterRefs.current[i] = el
              }}
            >
              <div className="cin-eyebrow">— {c.no} / {c.eyebrow}</div>
              <h2>{c.title}</h2>
              <p>{c.body}</p>
              {i === CHAPTERS.length - 1 && (
                <div className="cin-story-cta">
                  <Link className="cin-btn primary" href="/auth?mode=register">
                    Jetzt mitmachen <span className="arrow">→</span>
                  </Link>
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Fortschritts-Schiene */}
        <div className="cin-story-rail" aria-hidden="true">
          <span className="fill" />
        </div>
      </div>
    </section>
  )
}
