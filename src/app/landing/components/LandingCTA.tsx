'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'

/**
 * LandingCTA — editorial closing section.
 *
 * A deep ink background with a single oversized serif call, one action,
 * and a quiet secondary link. Feels like the final page of an editorial.
 */
export default function LandingCTA() {
  return (
    <section
      id="cta"
      className="relative bg-ink-900 text-stone-100 overflow-hidden py-32 md:py-44 px-6 md:px-10 scroll-mt-24"
      aria-labelledby="cta-heading"
    >
      {/* Soft accent gradient */}
      <div
        className="absolute inset-0 pointer-events-none opacity-60"
        style={{
          background:
            'radial-gradient(ellipse 60% 50% at 50% 50%, rgba(30,170,166,0.18), transparent 65%)',
        }}
        aria-hidden="true"
      />

      <div className="relative max-w-5xl mx-auto">
        <div className="reveal meta-label mb-10">08 / Bereit?</div>

        <h2
          id="cta-heading"
          className="reveal reveal-delay-1 display-xl !text-stone-100 max-w-4xl"
        >
          Deine Nachbarschaft
          <br />
          wartet auf <span className="text-accent">dich</span>.
        </h2>

        <p className="reveal reveal-delay-2 mt-10 max-w-xl text-lg md:text-xl text-stone-400 leading-relaxed">
          Schließ dich einer wachsenden Gemeinschaft an, die zeigt, dass
          Nachbarschaftshilfe mehr ist als nur ein Wort.
        </p>

        <div className="reveal reveal-delay-3 mt-14 flex flex-col sm:flex-row items-start sm:items-center gap-6">
          <Link
            href="/auth?mode=register"
            className="group inline-flex items-center gap-3 bg-paper hover:bg-stone-100 text-ink-800 px-8 py-4 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
          >
            Jetzt kostenlos starten
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>
          <Link
            href="/auth?mode=login"
            className="meta-label text-stone-400 hover:text-primary-400 transition-colors duration-300"
          >
            Bereits dabei? Anmelden
          </Link>
        </div>
      </div>
    </section>
  )
}
