'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import LandingSection from './LandingSection'

const steps = [
  {
    num: '01',
    title: 'Registrieren',
    description:
      'Kostenloses Konto in 30 Sekunden. Kein Abo, keine Kreditkarte, keine versteckten Kosten.',
  },
  {
    num: '02',
    title: 'Standort einstellen',
    description:
      'Hinterlege deinen Standort und wähle einen Radius. So findest du Nachbarn in direkter Umgebung.',
  },
  {
    num: '03',
    title: 'Loslegen',
    description:
      'Biete Hilfe an, suche Unterstützung oder lerne einfach deine Nachbarn kennen. Die Gemeinschaft wächst mit jedem Beitrag.',
  },
]

export default function LandingHowItWorks() {
  return (
    <LandingSection
      id="how-it-works"
      background="paper"
      index="04"
      label="So beginnt es"
      title={
        <>
          Drei Schritte zur aktiven <span className="text-accent">Nachbarschaft</span>.
        </>
      }
    >
      <ol className="grid grid-cols-1 md:grid-cols-3 gap-12 md:gap-16">
        {steps.map((step, i) => (
          <li
            key={step.num}
            className={`reveal reveal-delay-${i + 1} border-t border-stone-300 pt-8`}
          >
            <div className="font-display text-7xl md:text-8xl text-primary-500 leading-none tracking-tight">
              {step.num}
            </div>
            <h3 className="font-display text-2xl text-ink-800 mt-8 tracking-tight">
              {step.title}
            </h3>
            <p className="text-ink-500 text-[0.95rem] leading-relaxed mt-3 max-w-sm">
              {step.description}
            </p>
          </li>
        ))}
      </ol>

      <div className="reveal reveal-delay-4 mt-20 flex justify-start">
        <Link
          href="/auth?mode=register"
          className="group inline-flex items-center gap-3 bg-ink-800 hover:bg-ink-700 text-paper px-8 py-4 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
        >
          Jetzt kostenlos starten
          <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
        </Link>
      </div>
    </LandingSection>
  )
}
