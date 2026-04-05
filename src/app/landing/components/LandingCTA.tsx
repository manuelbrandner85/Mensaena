'use client'

import Link from 'next/link'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

export default function LandingCTA() {
  const { ref, isVisible } = useScrollAnimation()

  return (
    <section
      ref={ref}
      id="cta"
      className="green-gradient py-16 md:py-24 px-4 text-center text-white"
      aria-labelledby="cta-heading"
    >
      <div
        className={`max-w-3xl mx-auto ${
          isVisible ? 'animate-fade-up' : 'opacity-0'
        }`}
      >
        <h2 id="cta-heading" className="text-3xl md:text-4xl font-bold">
          Bereit, deine Nachbarschaft zu verändern?
        </h2>
        <p className="text-lg text-white/80 max-w-2xl mx-auto mt-4 leading-relaxed">
          Schließe dich einer wachsenden Gemeinschaft an, die zeigt, dass 
          Nachbarschaftshilfe mehr ist als nur ein Wort.
        </p>
        <div className="mt-8">
          <Link
            href="/auth?mode=register"
            className="inline-flex items-center justify-center bg-white text-primary-700 px-8 py-4 text-lg font-semibold rounded-xl hover:bg-primary-50 hover:shadow-lg transition-all duration-200 min-h-[44px]"
          >
            Jetzt kostenlos starten →
          </Link>
        </div>
        <div className="mt-4">
          <Link
            href="/auth?mode=login"
            className="text-white/70 hover:text-white underline text-sm transition-colors"
          >
            Bereits registriert? Anmelden
          </Link>
        </div>
      </div>
    </section>
  )
}
