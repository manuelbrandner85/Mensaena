/**
 * CinemaVignette — fixed Overlay mit asymmetrischer Vignettierung.
 *
 * Oben dunkler als unten (Nachthimmel-Effekt). Reines CSS, kein State.
 */
export default function CinemaVignette() {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-[35]"
      style={{
        background: `
          radial-gradient(ellipse 140% 110% at 50% 35%,
            transparent 45%,
            rgba(10,15,28,0.35) 65%,
            rgba(10,15,28,0.65) 85%,
            rgba(5,8,15,0.85) 100%
          ),
          linear-gradient(to bottom,
            rgba(5,8,15,0.25),
            transparent 50%
          )
        `,
      }}
    />
  )
}
