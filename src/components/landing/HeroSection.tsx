'use client'

import Link from 'next/link'
import { ArrowRight, MapPin, Users, Leaf, Shield } from 'lucide-react'

export default function HeroSection() {
  return (
    <section className="relative min-h-screen flex items-center hero-gradient overflow-hidden pt-16">
      {/* Background Decorations */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 bg-primary-200/30 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-trust-100/40 rounded-full blur-3xl" />
        <div className="absolute top-1/3 left-1/2 w-64 h-64 bg-sage-200/20 rounded-full blur-2xl" />
        {/* Subtle grid */}
        <div
          className="absolute inset-0 opacity-[0.03]"
          style={{
            backgroundImage: `radial-gradient(circle, #66BB6A 1px, transparent 1px)`,
            backgroundSize: '32px 32px',
          }}
        />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="max-w-3xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-100 text-primary-700 rounded-full text-sm font-medium mb-8 border border-primary-200">
            <Leaf className="w-4 h-4" />
            die Gemeinwohl Plattform
          </div>

          {/* Headline */}
          <h1 className="text-5xl md:text-6xl lg:text-7xl font-bold text-gray-900 leading-tight text-balance mb-6">
            Gemeinsam{' '}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-primary-600 to-primary-800">
              stärker
            </span>{' '}
            vor Ort.
          </h1>

          {/* Subheadline */}
          <p className="text-xl md:text-2xl text-gray-600 leading-relaxed mb-10 text-balance">
            Mensaena verbindet Menschen in deiner Nachbarschaft. Hilfe finden, Hilfe geben – 
            nachhaltig, lokal und persönlich.
          </p>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
            <Link href="/register" className="btn-primary text-base px-8 py-4 w-full sm:w-auto">
              Jetzt kostenlos registrieren
              <ArrowRight className="w-5 h-5" />
            </Link>
            <Link href="/login" className="btn-secondary text-base px-8 py-4 w-full sm:w-auto">
              Anmelden
            </Link>
            <a
              href="#features"
              className="btn-ghost text-base px-6 py-4 text-gray-500 hover:text-gray-700"
            >
              Mehr erfahren ↓
            </a>
          </div>

          {/* Trust Indicators */}
          <div className="flex flex-wrap items-center justify-center gap-6 text-sm text-gray-500">
            <div className="flex items-center gap-2">
              <Shield className="w-4 h-4 text-primary-600" />
              <span>100% kostenlos</span>
            </div>
            <div className="w-1 h-1 rounded-full bg-gray-300 hidden sm:block" />
            <div className="flex items-center gap-2">
              <MapPin className="w-4 h-4 text-primary-600" />
              <span>Lokal & persönlich</span>
            </div>
            <div className="w-1 h-1 rounded-full bg-gray-300 hidden sm:block" />
            <div className="flex items-center gap-2">
              <Users className="w-4 h-4 text-primary-600" />
              <span>Echte Gemeinschaft</span>
            </div>
            <div className="w-1 h-1 rounded-full bg-gray-300 hidden sm:block" />
            <div className="flex items-center gap-2">
              <Leaf className="w-4 h-4 text-primary-600" />
              <span>Nachhaltig</span>
            </div>
          </div>
        </div>

        {/* Hero Visual Cards */}
        <div className="mt-20 grid grid-cols-1 sm:grid-cols-3 gap-4 max-w-4xl mx-auto">
          <HeroCard
            emoji="🆘"
            title="Hilfe gesucht"
            desc="Nachbarin sucht Begleitung zum Arzt"
            time="vor 5 Min."
            color="bg-red-50 border-red-100"
            dot="bg-red-400"
          />
          <HeroCard
            emoji="🌿"
            title="Gemüse verschenken"
            desc="Frische Zucchini aus dem Garten – kostenlos abholen"
            time="vor 12 Min."
            color="bg-primary-50 border-primary-100"
            dot="bg-primary-400"
            featured
          />
          <HeroCard
            emoji="🐕"
            title="Gassi-Hilfe"
            desc="Suche jemanden für Hundespaziergänge diese Woche"
            time="vor 28 Min."
            color="bg-trust-50 border-trust-100"
            dot="bg-trust-300"
          />
        </div>
      </div>
    </section>
  )
}

function HeroCard({
  emoji, title, desc, time, color, dot, featured,
}: {
  emoji: string
  title: string
  desc: string
  time: string
  color: string
  dot: string
  featured?: boolean
}) {
  return (
    <div
      className={`p-4 rounded-2xl border ${color} transition-all duration-200 hover:-translate-y-1 hover:shadow-md
        ${featured ? 'sm:-translate-y-3 shadow-hover ring-2 ring-primary-200' : 'shadow-card'}`}
    >
      <div className="flex items-start gap-3">
        <span className="text-2xl">{emoji}</span>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className={`w-2 h-2 rounded-full ${dot} flex-shrink-0`} />
            <span className="text-xs font-semibold text-gray-800">{title}</span>
          </div>
          <p className="text-xs text-gray-600 leading-relaxed line-clamp-2">{desc}</p>
          <p className="text-xs text-gray-400 mt-2">{time}</p>
        </div>
      </div>
    </div>
  )
}
