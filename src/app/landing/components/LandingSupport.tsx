'use client'

import Link from 'next/link'
import { Heart, ArrowRight, Smartphone, Building2, Shield } from 'lucide-react'

/**
 * LandingSupport — editorial donation section.
 *
 * Mensaena finanziert sich ausschließlich durch Spenden. Diese Sektion
 * vermittelt das in dezent-redaktionellem Stil und führt zur /spenden-Seite.
 */
export default function LandingSupport() {
  return (
    <section
      id="support"
      className="relative bg-paper px-6 md:px-10 py-24 md:py-36 scroll-mt-24"
      aria-labelledby="support-heading"
    >
      <div
        className="absolute inset-0 pointer-events-none opacity-40"
        style={{
          background:
            'radial-gradient(ellipse 50% 40% at 50% 0%, rgba(30,170,166,0.12), transparent 70%)',
        }}
        aria-hidden="true"
      />

      <div className="relative max-w-6xl mx-auto">
        {/* Header */}
        <header className="reveal max-w-3xl mb-16 md:mb-20">
          <div className="meta-label mb-7 text-primary-700">— 08 / Unterstützung</div>
          <h2 id="support-heading" className="display-lg text-balance">
            Werbefrei. Spendenfinanziert.{' '}
            <span className="text-primary-600">Für immer.</span>
          </h2>
          <p className="reveal reveal-delay-2 section-subtitle">
            Mensaena hat keine Werbung, keine Investoren und keine bezahlten Mitarbeiter:innen.
            Damit das so bleibt, finanzieren wir uns ausschließlich durch Menschen wie dich.
          </p>
        </header>

        {/* Card */}
        <div className="reveal reveal-delay-3 grid md:grid-cols-5 gap-0 bg-white rounded-3xl border border-stone-200 shadow-card overflow-hidden">
          {/* Left: Story */}
          <div className="md:col-span-3 p-10 md:p-14 border-b md:border-b-0 md:border-r border-stone-200">
            <div className="flex items-center gap-3 mb-8">
              <div className="w-11 h-11 rounded-2xl bg-primary-500 text-white flex items-center justify-center shadow-glow-teal">
                <Heart className="w-5 h-5 fill-white/30" />
              </div>
              <span className="meta-label text-primary-700">Goldenes Herz für Spender:innen</span>
            </div>

            <h3 className="font-display text-3xl md:text-4xl text-ink-800 leading-[1.1] tracking-tight mb-6 text-balance">
              Drei Euro halten Mensaena einen Monat lang am Laufen &mdash; pro 60&nbsp;Nachbar:innen.
            </h3>

            <p className="text-ink-500 leading-relaxed mb-10 max-w-xl">
              Server, Domain, SMS-Verifikation, Kartenservice. Alles, was du auf Mensaena nutzt,
              läuft im Hintergrund und kostet jeden Monat Geld. Deine Spende deckt diese Kosten
              direkt &mdash; transparent und ohne Umweg.
            </p>

            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5">
              <Link
                href="/spenden"
                className="group inline-flex items-center gap-3 bg-ink-900 hover:bg-ink-800 text-paper px-7 py-3.5 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
              >
                Mensaena unterstützen
                <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
              </Link>
              <Link
                href="/spenden#transparenz"
                className="meta-label meta-label--subtle hover:text-primary-700 transition-colors duration-300"
              >
                Wo das Geld hingeht →
              </Link>
            </div>
          </div>

          {/* Right: Quick facts */}
          <div className="md:col-span-2 p-10 md:p-14 bg-stone-50/60">
            <div className="meta-label meta-label--subtle mb-6">In 30 Sekunden</div>
            <ul className="space-y-7">
              <Fact
                Icon={Smartphone}
                title="Banking-App scannen"
                text="QR-Code öffnen, scannen, bestätigen. Funktioniert mit allen deutschen, österreichischen und schweizerischen Banking-Apps."
              />
              <Fact
                Icon={Building2}
                title="SEPA-Überweisung"
                text="IBAN kopieren, klassische Überweisung. Mit oder ohne Spendenbescheinigung."
              />
              <Fact
                Icon={Shield}
                title="100 % transparent"
                text="Wir veröffentlichen unsere Kosten. Jeder Cent fließt in den Betrieb der Plattform."
              />
            </ul>
          </div>
        </div>

        {/* Caveat */}
        <p className="reveal reveal-delay-4 mt-10 text-xs text-ink-400 max-w-3xl leading-relaxed">
          Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt.
          Spenden sind daher nicht steuerlich absetzbar &mdash; wir arbeiten daran.
        </p>
      </div>
    </section>
  )
}

function Fact({
  Icon,
  title,
  text,
}: {
  Icon: React.ComponentType<{ className?: string }>
  title: string
  text: string
}) {
  return (
    <li className="flex gap-4">
      <div className="flex-shrink-0 w-9 h-9 rounded-xl bg-white border border-stone-200 flex items-center justify-center">
        <Icon className="w-4 h-4 text-primary-600" aria-hidden="true" />
      </div>
      <div className="min-w-0">
        <div className="text-sm font-semibold text-ink-800 mb-1">{title}</div>
        <p className="text-[13px] text-ink-500 leading-relaxed">{text}</p>
      </div>
    </li>
  )
}
