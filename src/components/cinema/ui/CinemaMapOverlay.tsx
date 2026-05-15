'use client'

/**
 * CinemaMapOverlay
 * Editorial atmosphere layer that sits on top of the Leaflet map container.
 * Adds a subtle radial vignette + 5 floating "lantern" glow particles, all
 * pointer-events-none so map interaction is preserved.
 */

const lanterns = [
  { top: '12%', left: '18%', size: 220, hue: 'rgba(199,147,99,0.10)', delay: '0s'   },
  { top: '38%', left: '72%', size: 180, hue: 'rgba(199,147,99,0.08)', delay: '1.6s' },
  { top: '68%', left: '28%', size: 260, hue: 'rgba(125,211,252,0.07)', delay: '0.8s' },
  { top: '78%', left: '78%', size: 200, hue: 'rgba(199,147,99,0.09)', delay: '2.4s' },
  { top: '52%', left: '46%', size: 320, hue: 'rgba(125,211,252,0.05)', delay: '3.2s' },
]

export default function CinemaMapOverlay() {
  return (
    <>
      {/* Radial vignette — slightly darkens the map edges */}
      <div
        className="absolute inset-0 pointer-events-none z-[400]"
        style={{
          background: 'radial-gradient(ellipse at 50% 50%, transparent 55%, rgba(10,15,28,0.45) 100%)',
        }}
        aria-hidden
      />
      {/* Lantern glow particles */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden z-[401]" aria-hidden>
        {lanterns.map((l, i) => (
          <div
            key={i}
            className="absolute rounded-full"
            style={{
              top: l.top,
              left: l.left,
              width: l.size,
              height: l.size,
              background: `radial-gradient(circle, ${l.hue} 0%, transparent 70%)`,
              animation: `lanternDrift 14s ease-in-out ${l.delay} infinite`,
              filter: 'blur(2px)',
              transform: 'translate(-50%, -50%)',
            }}
          />
        ))}
      </div>
    </>
  )
}
