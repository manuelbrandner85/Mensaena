'use client'

/**
 * FloatingParticles
 * Renders subtle animated blobs in the background of the dashboard.
 * Purely decorative – pointer-events: none.
 */
export default function FloatingParticles() {
  return (
    <div className="particles-layer" aria-hidden="true">
      {/* Green blobs */}
      <div className="particle-1" />
      <div className="particle-2" />
      <div className="particle-3" />
      <div className="particle-4" />
      <div className="particle-5" />
      <div className="particle-6" />
      <div className="particle-7" />

      {/* Extra tiny dots */}
      <div
        className="absolute w-6 h-6 rounded-full"
        style={{
          top: '22%', left: '42%',
          background: 'radial-gradient(circle, rgba(30,170,166,0.5) 0%, transparent 70%)',
          animation: 'float 5s ease-in-out 1s infinite',
        }}
      />
      <div
        className="absolute w-8 h-8 rounded-full"
        style={{
          top: '75%', left: '30%',
          background: 'radial-gradient(circle, rgba(79,109,138,0.2) 0%, transparent 70%)',
          animation: 'float 9s ease-in-out 3.5s infinite',
        }}
      />
      <div
        className="absolute w-10 h-10 rounded-full"
        style={{
          top: '45%', right: '28%',
          background: 'radial-gradient(circle, rgba(30,170,166,0.22) 0%, transparent 70%)',
          animation: 'float 11s ease-in-out 1.2s infinite',
        }}
      />
    </div>
  )
}
