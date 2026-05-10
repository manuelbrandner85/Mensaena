'use client'

/**
 * FilmGrain — fixed Overlay mit warm-getöntem Filmkorn.
 *
 * SVG fractalNoise Filter mit feColorMatrix die das Grau leicht
 * ins amber/warm verschiebt. mix-blend-mode: overlay,
 * opacity: 0.06. Animation grainShift.
 */
export default function FilmGrain() {
  return (
    <div
      aria-hidden="true"
      className="cinema-grain pointer-events-none fixed inset-0 z-40 mix-blend-overlay"
      style={{
        opacity: 0.06,
        animation: 'grainShift 0.6s steps(4) infinite',
      }}
    >
      <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
        <filter id="cinema-grain-filter">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.75"
            numOctaves="3"
            stitchTiles="stitch"
          />
          <feColorMatrix
            values="
              0 0 0 0 0.9
              0 0 0 0 0.85
              0 0 0 0 0.7
              0 0 0 0.5 0
            "
          />
        </filter>
        <rect width="100%" height="100%" filter="url(#cinema-grain-filter)" />
      </svg>
    </div>
  )
}
