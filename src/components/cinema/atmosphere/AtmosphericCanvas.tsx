'use client'

import { useMemo } from 'react'

/**
 * AtmosphericCanvas — pure CSS/SVG Atmosphäre.
 *
 * Cloudflare Workers haben 3 MiB Limit; Three.js würde den Bundle sprengen.
 * Stattdessen: positionierte Spans (Laternen/Glühwürmchen) + CSS Animationen
 * + SVG fractalNoise für den Bodennebel.
 *
 * Fixed bg, z-0, pointer-events:none. Reagiert nicht auf Scroll
 * (statisches "Welt-Hintergrund"-Bild plus minimale Animationen).
 */
type Props = {
  /** Glühwürmchen ein/aus. */
  fireflies?: boolean
  /** Wet-Asphalt-Reflection ein/aus. */
  asphalt?: boolean
}

export default function AtmosphericCanvas({
  fireflies = true,
  asphalt   = true,
}: Props) {
  // Deterministische Pseudo-Random-Werte (kein hydration mismatch).
  const lanterns = useMemo(() => generateLanterns(40), [])
  const flies    = useMemo(() => generateFireflies(10), [])

  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-0 overflow-hidden"
    >
      {/* Base Nachthimmel-Gradient */}
      <div
        className="absolute inset-0"
        style={{
          background: `
            radial-gradient(ellipse 100% 50% at 50% 100%, rgba(199,147,99,0.08), transparent 60%),
            radial-gradient(ellipse 80% 60% at 30% 30%, rgba(43,86,99,0.04), transparent 60%),
            #0A0F1C
          `,
        }}
      />

      {/* Bodennebel — SVG fractalNoise */}
      <svg
        className="absolute inset-x-0 bottom-0 w-full"
        style={{ height: '55%', mixBlendMode: 'screen', opacity: 0.10 }}
        xmlns="http://www.w3.org/2000/svg"
      >
        <filter id="cinema-fog-noise">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.012 0.04"
            numOctaves="3"
            seed="7"
          />
          <feColorMatrix
            values="
              0 0 0 0 0.961
              0 0 0 0 0.620
              0 0 0 0 0.043
              0 0 0 0.45 0
            "
          />
        </filter>
        <rect
          width="120%"
          height="100%"
          x="-10%"
          filter="url(#cinema-fog-noise)"
          style={{ animation: 'cinemaFogDrift 28s linear infinite' }}
        />
      </svg>

      {/* Laternen-Lichter */}
      {lanterns.map((l, i) => (
        <span
          key={`l-${i}`}
          className="absolute rounded-full"
          style={{
            left:  `${l.x}%`,
            top:   `${l.y}%`,
            width:  `${l.size}px`,
            height: `${l.size}px`,
            background: `radial-gradient(circle, ${l.color} 0%, ${l.color}88 35%, transparent 70%)`,
            filter: 'blur(1px)',
            opacity: 0,
            animation: `lanternGlow ${l.duration}s ease-in-out ${l.delay}s infinite`,
            boxShadow: l.hero
              ? `0 0 ${l.size * 2.5}px ${l.color}66, 0 0 ${l.size * 4}px ${l.color}33`
              : `0 0 ${l.size}px ${l.color}55`,
          }}
        />
      ))}

      {/* Glühwürmchen */}
      {fireflies &&
        flies.map((f, i) => (
          <span
            key={`f-${i}`}
            className="absolute rounded-full bg-mn-bronze-soft"
            style={{
              left:  `${f.x}%`,
              top:   `${f.y}%`,
              width:  '3px',
              height: '3px',
              filter: 'blur(0.5px)',
              boxShadow: '0 0 6px rgba(253,230,138,0.7), 0 0 12px rgba(253,230,138,0.35)',
              opacity: 0,
              animation: `cinemaFireflyDrift ${f.duration}s ease-in-out ${f.delay}s infinite`,
            }}
          />
        ))}

      {/* Wet asphalt reflection (untere 12%) */}
      {asphalt && (
        <div
          className="absolute inset-x-0 bottom-0"
          style={{
            height: '12%',
            background: `
              radial-gradient(ellipse 60% 100% at 50% 100%, rgba(199,147,99,0.10) 0%, rgba(199,147,99,0.04) 50%, transparent 100%)
            `,
            filter: 'blur(2px)',
            mixBlendMode: 'screen',
          }}
        />
      )}
    </div>
  )
}

/* ─── Lantern + Firefly generators ─────────────────────────────────────── */

const LANTERN_COLORS = [
  'rgba(199,147,99,0.55)',  // amber
  'rgba(199,147,99,0.55)',  // amber-warm
  'rgba(253,230,138,0.55)', // amber-soft
  'rgba(212,160,84,0.55)',  // trust
]

function mulberry32(seed: number) {
  return () => {
    seed |= 0
    seed = (seed + 0x6D2B79F5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function generateLanterns(n: number) {
  const rand = mulberry32(42)
  return Array.from({ length: n }, (_, i) => {
    const hero = i < 5
    return {
      x:        rand() * 100,
      y:        hero ? rand() * 35 + 5 : rand() * 70 + 10,
      size:     hero ? 14 + rand() * 10 : 4 + rand() * 8,
      color:    LANTERN_COLORS[Math.floor(rand() * LANTERN_COLORS.length)],
      duration: 4 + rand() * 6,
      delay:    rand() * 6,
      hero,
    }
  })
}

function generateFireflies(n: number) {
  const rand = mulberry32(1337)
  return Array.from({ length: n }, () => ({
    x:        10 + rand() * 80,
    y:        20 + rand() * 50,
    duration: 7 + rand() * 5,
    delay:    rand() * 8,
  }))
}
