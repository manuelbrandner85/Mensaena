'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'

/**
 * LandingHero — cinematic editorial hero.
 *
 * Full-viewport height, oversized serif display headline, one CTA, a
 * soft animated mesh gradient backdrop with subtle noise grain. Zero
 * floating cards, zero badge zoo — pure statement.
 */
export default function LandingHero() {
  const smoothScroll = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section
      id="hero"
      className="relative min-h-dvh flex items-center bg-paper mesh-grain overflow-hidden"
      aria-labelledby="hero-heading"
    >
      {/* Backdrop: soft drifting mesh */}
      <div className="mesh-gradient" aria-hidden="true" />

      {/* Top/bottom vignettes for depth */}
      <div
        className="absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-paper to-transparent pointer-events-none"
        aria-hidden="true"
      />
      <div
        className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-t from-paper to-transparent pointer-events-none"
        aria-hidden="true"
      />

      {/* Content */}
      <div className="relative z-10 w-full max-w-6xl mx-auto px-6 md:px-10 pt-28 pb-24 md:pt-32 md:pb-28">
        {/* Meta label */}
        <div className="reveal meta-label mb-10">01 / Deine Nachbarschaft</div>

        {/* Headline */}
        <h1
          id="hero-heading"
          className="reveal reveal-delay-1 display-xl max-w-5xl"
        >
          Nachbarschaft,
          <br />
          neu <span className="text-accent">gedacht</span>.
        </h1>

        {/* Sub */}
        <p className="reveal reveal-delay-2 mt-10 max-w-xl text-lg md:text-xl text-ink-500 leading-relaxed">
          Hilfe anbieten. Hilfe finden. Menschen in deiner Nähe kennenlernen.
          Kostenlos, gemeinnützig, von der Gemeinschaft getragen.
        </p>

        {/* Single CTA + quiet secondary */}
        <div className="reveal reveal-delay-3 mt-12 flex flex-col sm:flex-row items-start sm:items-center gap-6">
          <Link
            href="/auth?mode=register"
            className="group inline-flex items-center gap-3 bg-ink-800 hover:bg-ink-700 text-paper px-8 py-4 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
          >
            Kostenlos starten
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>
          <button
            onClick={() => smoothScroll('features')}
            className="text-sm font-medium text-ink-500 hover:text-ink-800 transition-colors duration-300 inline-flex items-center gap-2"
          >
            <span className="inline-block h-px w-8 bg-current opacity-50" />
            Mehr erfahren
          </button>
        </div>

        {/* Footnote */}
        <div className="reveal reveal-delay-4 mt-20 grid grid-cols-1 sm:grid-cols-3 gap-6 max-w-3xl border-t border-stone-200 pt-8">
          <HeroFact label="Preis" value="Kostenlos" />
          <HeroFact label="Datenschutz" value="DSGVO-konform" />
          <HeroFact label="Organisation" value="Gemeinnützig" />
        </div>
      </div>

      {/* Scroll hint */}
      <div
        className="absolute bottom-8 left-1/2 -translate-x-1/2 hidden md:flex flex-col items-center gap-2 text-ink-400"
        aria-hidden="true"
      >
        <span className="meta-label meta-label--subtle">Scroll</span>
        <span className="block w-px h-10 bg-ink-300 animate-[pulse_2.6s_ease-in-out_infinite]" />
      </div>
    </section>
  )
}

function HeroFact({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="meta-label meta-label--subtle mb-2">{label}</div>
      <div className="font-display text-xl md:text-2xl text-ink-800">{value}</div>
    </div>
  )
}
