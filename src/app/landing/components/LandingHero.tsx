'use client'

import Link from 'next/link'
import { HandHeart, Wrench, Calendar } from 'lucide-react'

export default function LandingHero() {
  const smoothScroll = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section
      id="hero"
      className="min-h-dvh flex items-center hero-gradient relative overflow-hidden"
      aria-labelledby="hero-heading"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 pt-20 md:py-20 md:pt-24 w-full">
        <div className="grid lg:grid-cols-5 gap-8 lg:gap-16 items-center">
          {/* Text */}
          <div className="lg:col-span-3 text-center lg:text-left">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 bg-primary-100 text-primary-800 text-sm rounded-full px-4 py-1.5 mb-6 border border-primary-200 animate-landing-fade-in">
              <span aria-hidden="true">🏘️</span>
              Nachbarschaftshilfe neu gedacht
            </div>

            {/* Headline – responsive font sizes */}
            <div className="relative">
              <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[420px] h-[420px] rounded-full bg-primary-200/25 blur-3xl animate-pulse-soft pointer-events-none" aria-hidden="true" />
              <h1 id="hero-heading" className="relative text-4xl md:text-6xl lg:text-7xl font-bold text-gray-900 leading-tight">
                <span className="block animate-fade-up" style={{ animationDelay: '0ms' }}>
                  Deine Nachbarschaft.
                </span>
                <span className="block animate-fade-up" style={{ animationDelay: '100ms' }}>
                  Deine Gemeinschaft.
                </span>
                <span className="block animate-fade-up gradient-text" style={{ animationDelay: '200ms' }}>
                  Dein Mensaena.
                </span>
              </h1>
            </div>

            {/* Subheadline */}
            <p className="text-base md:text-xl text-gray-600 max-w-xl mt-5 md:mt-6 leading-relaxed animate-fade-up mx-auto lg:mx-0" style={{ animationDelay: '300ms' }}>
              Hilfe anbieten. Hilfe finden. Nachbarn kennenlernen. Mensaena verbindet 
              Menschen in deiner N&auml;he – kostenlos, gemeinn&uuml;tzig und von der Gemeinschaft getragen.
            </p>

            {/* CTA Buttons – full width on mobile */}
            <div className="mt-6 md:mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 animate-fade-up" style={{ animationDelay: '400ms' }}>
              <Link
                href="/auth?mode=register"
                className="btn-primary px-8 py-4 text-base md:text-lg w-full sm:w-auto justify-center touch-target shadow-glow hover:shadow-glow-teal transition-shadow duration-300"
              >
                Kostenlos starten →
              </Link>
              <button
                onClick={() => smoothScroll('features')}
                className="btn-secondary px-8 py-4 text-base md:text-lg w-full sm:w-auto justify-center touch-target hover:shadow-md transition-shadow duration-300"
              >
                Mehr erfahren ↓
              </button>
            </div>

            {/* Trust line */}
            <div className="mt-5 md:mt-6 flex flex-wrap items-center justify-center lg:justify-start gap-x-4 gap-y-1 text-sm text-gray-500 animate-fade-up" style={{ animationDelay: '500ms' }}>
              <span><span className="text-primary-500">✓</span> 100% kostenlos</span>
              <span className="text-gray-300">·</span>
              <span><span className="text-primary-500">✓</span> DSGVO-konform</span>
              <span className="text-gray-300">·</span>
              <span><span className="text-primary-500">✓</span> Gemeinn&uuml;tzig</span>
            </div>
          </div>

          {/* Visual – Desktop only (floating cards) */}
          <div className="hidden lg:flex lg:col-span-2 justify-center relative" aria-hidden="true">
            <div className="relative w-full max-w-sm">
              {/* Card 1 */}
              <div className="absolute -top-2 -left-4 w-64 bg-white rounded-2xl shadow-lg border border-warm-200 p-5 transform -rotate-3 animate-landing-float z-10">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-primary-100 rounded-xl flex items-center justify-center">
                    <HandHeart className="w-5 h-5 text-primary-600" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-900">Hilfe angeboten</p>
                    <p className="text-xs text-gray-500">Einkaufshilfe f&uuml;r Nachbarn</p>
                  </div>
                </div>
              </div>

              {/* Card 2 */}
              <div className="absolute top-24 -right-4 w-60 bg-white rounded-2xl shadow-lg border border-warm-200 p-5 transform rotate-2 animate-landing-float z-20" style={{ animationDelay: '1s' }}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center">
                    <Wrench className="w-5 h-5 text-amber-600" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-900">Werkzeug leihen</p>
                    <p className="text-xs text-gray-500">Bohrmaschine · 2 km</p>
                  </div>
                </div>
              </div>

              {/* Card 3 */}
              <div className="absolute top-52 left-2 w-56 bg-white rounded-2xl shadow-lg border border-warm-200 p-5 transform -rotate-1 animate-landing-float z-10" style={{ animationDelay: '2s' }}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-trust-100 rounded-xl flex items-center justify-center">
                    <Calendar className="w-5 h-5 text-trust-400" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-900">Stra&szlig;enfest</p>
                    <p className="text-xs text-gray-500">Samstag · 15:00 Uhr</p>
                  </div>
                </div>
              </div>

              {/* Spacer for layout */}
              <div className="h-80" />
            </div>
          </div>

          {/* Mobile: single-column horizontal snap-scroll cards */}
          <div className="lg:hidden -mx-4 px-4 overflow-x-auto snap-x snap-mandatory flex gap-3 pb-2 no-scrollbar" aria-hidden="true">
            <div className="snap-center shrink-0 w-64 bg-white rounded-2xl shadow-md border border-warm-200 p-4 flex items-center gap-3">
              <div className="w-10 h-10 bg-primary-100 rounded-xl flex items-center justify-center shrink-0">
                <HandHeart className="w-5 h-5 text-primary-600" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-900">Hilfe angeboten</p>
                <p className="text-xs text-gray-500">Einkaufshilfe f&uuml;r Nachbarn</p>
              </div>
            </div>
            <div className="snap-center shrink-0 w-64 bg-white rounded-2xl shadow-md border border-warm-200 p-4 flex items-center gap-3">
              <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center shrink-0">
                <Wrench className="w-5 h-5 text-amber-600" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-900">Werkzeug leihen</p>
                <p className="text-xs text-gray-500">Bohrmaschine · 2 km</p>
              </div>
            </div>
            <div className="snap-center shrink-0 w-64 bg-white rounded-2xl shadow-md border border-warm-200 p-4 flex items-center gap-3">
              <div className="w-10 h-10 bg-trust-100 rounded-xl flex items-center justify-center shrink-0">
                <Calendar className="w-5 h-5 text-trust-400" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-900">Stra&szlig;enfest</p>
                <p className="text-xs text-gray-500">Samstag · 15:00 Uhr</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
