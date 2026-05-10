'use client'

import Link from 'next/link'
import { Heart, ArrowRight, Smartphone, Building2, Shield } from 'lucide-react'

export default function LandingSupport() {
  return (
    <section
      id="support"
      className="cinema-section relative px-6 md:px-10 py-24 md:py-36 scroll-mt-24"
      aria-labelledby="support-heading"
    >
      <div className="relative max-w-6xl mx-auto">
        <header className="reveal max-w-3xl mb-16 md:mb-20">
          <div className="cinema-meta-label mb-7">— 08 / Unterstützung</div>
          <h2
            id="support-heading"
            className="reveal reveal-delay-1 text-balance"
            style={{
              fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
              fontWeight: 400,
              fontSize: 'clamp(2.25rem, 5vw, 3.75rem)',
              lineHeight: 1.05,
              letterSpacing: '-0.025em',
              color: '#F5F0E8',
            }}
          >
            Werbefrei. Spendenfinanziert.{' '}
            <span style={{ color: 'rgba(245,158,11,0.85)' }}>Für immer.</span>
          </h2>
          <p className="reveal reveal-delay-2 mt-6 text-lg leading-relaxed" style={{ color: 'rgba(245,240,232,0.50)' }}>
            Mensaena hat keine Werbung, keine Investoren und keine bezahlten Mitarbeiter:innen.
            Damit das so bleibt, finanzieren wir uns ausschließlich durch Menschen wie dich.
          </p>
        </header>

        <div
          className="reveal reveal-delay-3 cinema-card grid md:grid-cols-5 gap-0 overflow-hidden"
          style={{ padding: 0 }}
        >
          {/* Left: Story */}
          <div
            className="md:col-span-3 p-10 md:p-14"
            style={{ borderRight: '1px solid rgba(245,158,11,0.10)' }}
          >
            <div className="flex items-center gap-3 mb-8">
              <div className="cinema-icon-surface w-11 h-11 rounded-2xl flex items-center justify-center">
                <Heart className="w-5 h-5 text-mn-amber" style={{ fill: 'rgba(245,158,11,0.25)' }} />
              </div>
              <span className="cinema-meta-label">Goldenes Herz für Spender:innen</span>
            </div>

            <h3
              className="leading-[1.1] tracking-tight mb-6 text-balance"
              style={{
                fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
                fontSize: 'clamp(1.5rem, 3vw, 2rem)',
                color: '#F5F0E8',
              }}
            >
              Drei Euro halten Mensaena einen Monat lang am Laufen &mdash; pro 60&nbsp;Nachbar:innen.
            </h3>

            <p className="leading-relaxed mb-10 max-w-xl" style={{ color: 'rgba(245,240,232,0.50)' }}>
              Server, Domain, SMS-Verifikation, Kartenservice. Alles, was du auf Mensaena nutzt,
              läuft im Hintergrund und kostet jeden Monat Geld. Deine Spende deckt diese Kosten
              direkt &mdash; transparent und ohne Umweg.
            </p>

            <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5">
              <Link
                href="/spenden"
                className="cta-cinema-amber group inline-flex items-center gap-3 text-mn-void px-7 py-3.5 rounded-full text-sm font-medium tracking-wide"
              >
                Mensaena unterstützen
                <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
              </Link>
              <Link
                href="/spenden#transparenz"
                className="cinema-meta-label cinema-meta-label--subtle hover:opacity-70 transition-opacity duration-300"
              >
                Wo das Geld hingeht →
              </Link>
            </div>
          </div>

          {/* Right: Quick facts */}
          <div className="md:col-span-2 p-10 md:p-14" style={{ background: 'rgba(245,158,11,0.03)' }}>
            <div className="cinema-meta-label cinema-meta-label--subtle mb-6">In 30 Sekunden</div>
            <ul className="space-y-7">
              <Fact Icon={Smartphone} title="Banking-App scannen" text="QR-Code öffnen, scannen, bestätigen. Funktioniert mit allen deutschen, österreichischen und schweizerischen Banking-Apps." />
              <Fact Icon={Building2} title="SEPA-Überweisung" text="IBAN kopieren, klassische Überweisung. Mit oder ohne Spendenbescheinigung." />
              <Fact Icon={Shield} title="100 % transparent" text="Wir veröffentlichen unsere Kosten. Jeder Cent fließt in den Betrieb der Plattform." />
            </ul>
          </div>
        </div>

        <p
          className="reveal reveal-delay-4 mt-10 text-xs max-w-3xl leading-relaxed"
          style={{ color: 'rgba(245,240,232,0.50)' }}
        >
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
      <div className="cinema-icon-surface flex-shrink-0 w-9 h-9 rounded-xl flex items-center justify-center">
        <Icon className="w-4 h-4 text-mn-amber" aria-hidden="true" />
      </div>
      <div className="min-w-0">
        <div className="text-sm font-semibold mb-1" style={{ color: '#F5F0E8' }}>{title}</div>
        <p className="text-[13px] leading-relaxed" style={{ color: 'rgba(245,240,232,0.75)' }}>{text}</p>
      </div>
    </li>
  )
}
