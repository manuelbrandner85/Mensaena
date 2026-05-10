'use client'

import dynamic from 'next/dynamic'
import { useEffect, useState } from 'react'
import CinemaAppBar from './CinemaAppBar'
import CinemaVignette from './overlays/CinemaVignette'
import FilmGrain from './overlays/FilmGrain'
import CursorGlow from './overlays/CursorGlow'
import SmoothScroll from './providers/SmoothScroll'

// AtmosphericCanvas lädt Three.js — lazy laden um Hydration-Cost zu sparen.
// SSR aus, weil WebGL clientseitig only ist.
const AtmosphericCanvas = dynamic(
  () => import('./atmosphere/AtmosphericCanvas'),
  {
    ssr:     false,
    loading: () => null,
  },
)

type Props = {
  children: React.ReactNode
  /** Glühwürmchen ein/aus (Landing/Auth = an, Dashboard/Chat = aus). */
  fireflies?: boolean
  /** Wet-Asphalt-Reflection ein/aus. */
  asphalt?: boolean
  /** AppBar ausblenden (z.B. für Onboarding-Flows). */
  hideAppBar?: boolean
}

/**
 * CinemaLayout — der Welten-Wrapper.
 *
 * Wrapt: <SmoothScroll> → AtmosphericCanvas (fixed bg) → CSS Overlays
 * (Vignette, Grain, Cursor) → AppBar → main content.
 *
 * Setzt `bg-mn-void` auf den Wrapper, damit der Cinema-Hintergrund auch
 * bei langsamer Three.js-Hydration sichtbar ist (kein Weiß-Flash).
 *
 * Bei prefers-reduced-motion: AtmosphericCanvas wird nicht geladen,
 * Vignette+Grain bleiben statisch.
 */
export default function CinemaLayout({
  children,
  fireflies = true,
  asphalt   = true,
  hideAppBar = false,
}: Props) {
  const [reducedMotion, setReducedMotion] = useState(false)

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    setReducedMotion(mq.matches)
    const onChange = (e: MediaQueryListEvent) => setReducedMotion(e.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  return (
    <SmoothScroll>
      <div className="relative min-h-screen bg-mn-void text-mn-ink font-sans antialiased selection:bg-mn-amber/20">
        {/* Three.js atmosphere — lazy, only when motion is OK */}
        {!reducedMotion && (
          <AtmosphericCanvas fireflies={fireflies} asphalt={asphalt} />
        )}

        {/* Static fallback gradient when Three.js not loaded */}
        {reducedMotion && (
          <div
            aria-hidden="true"
            className="pointer-events-none fixed inset-0 z-0"
            style={{
              background: `
                radial-gradient(circle at 30% 20%, rgba(245,158,11,0.05), transparent 55%),
                radial-gradient(circle at 70% 80%, rgba(14,165,233,0.04), transparent 55%),
                #0A0F1C
              `,
            }}
          />
        )}

        {/* CSS overlay stack */}
        <CinemaVignette />
        <FilmGrain />
        <CursorGlow />

        {/* AppBar */}
        {!hideAppBar && <CinemaAppBar />}

        {/* Main content */}
        <main id="main-content" className="relative z-10">
          {children}
        </main>
      </div>
    </SmoothScroll>
  )
}
