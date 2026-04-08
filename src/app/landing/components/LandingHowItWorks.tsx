'use client'

import Link from 'next/link'
import { UserPlus, MapPin, Users } from 'lucide-react'
import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

const steps = [
  {
    num: 1,
    Icon: UserPlus,
    title: 'Registrieren',
    description:
      'Erstelle in 30 Sekunden ein kostenloses Konto. Kein Abo, keine Kreditkarte, keine versteckten Kosten.',
  },
  {
    num: 2,
    Icon: MapPin,
    title: 'Standort einstellen',
    description:
      'Hinterlege deinen Standort und wähle deinen Radius. So findest du Nachbarn in deiner direkten Umgebung.',
  },
  {
    num: 3,
    Icon: Users,
    title: 'Loslegen',
    description:
      'Biete Hilfe an, suche Unterstützung oder lerne einfach deine Nachbarn kennen. Die Gemeinschaft wächst mit jedem Beitrag.',
  },
]

export default function LandingHowItWorks() {
  const { ref, isVisible } = useScrollAnimation()

  return (
    <LandingSection id="how-it-works" background="white">
      <div ref={ref} className="max-w-4xl mx-auto">
        <h2
          id="how-it-works-heading"
          className="text-3xl md:text-4xl font-bold text-center text-gray-900"
        >
          In 3 Schritten zur aktiven Nachbarschaft
        </h2>

        {/* Desktop: horizontal */}
        <div className="hidden md:grid grid-cols-3 gap-0 mt-12 relative">
          {/* Dashed connector line */}
          <div
            className="absolute top-6 left-[16.7%] right-[16.7%] border-t-2 border-dashed border-primary-300 z-0"
            aria-hidden="true"
          />

          {steps.map((step, i) => (
            <div
              key={step.num}
              className={`relative z-10 text-center px-6 ${
                isVisible ? 'animate-fade-up' : 'opacity-0'
              }`}
              style={{ animationDelay: `${i * 150}ms` }}
            >
              <div className="w-12 h-12 green-gradient text-white rounded-full flex items-center justify-center text-xl font-bold mx-auto shadow-glow-sm">
                {step.num}
              </div>
              <step.Icon
                className="w-8 h-8 text-primary-500 mx-auto mt-4"
                aria-hidden="true"
              />
              <h3 className="text-xl font-semibold text-gray-900 mt-3">
                {step.title}
              </h3>
              <p className="text-gray-600 mt-2 text-sm leading-relaxed">
                {step.description}
              </p>
            </div>
          ))}
        </div>

        {/* Mobile: vertical with dashed left border */}
        <div className="md:hidden mt-10 relative">
          <div
            className="absolute left-6 top-0 bottom-0 border-l-2 border-dashed border-primary-300"
            aria-hidden="true"
          />
          <div className="space-y-10">
            {steps.map((step, i) => (
              <div
                key={step.num}
                className={`relative pl-16 ${
                  isVisible ? 'animate-fade-up' : 'opacity-0'
                }`}
                style={{ animationDelay: `${i * 150}ms` }}
              >
                <div className="absolute left-0 w-12 h-12 green-gradient text-white rounded-full flex items-center justify-center text-xl font-bold shadow-glow-sm">
                  {step.num}
                </div>
                <step.Icon
                  className="w-7 h-7 text-primary-500 mb-2"
                  aria-hidden="true"
                />
                <h3 className="text-lg font-semibold text-gray-900">
                  {step.title}
                </h3>
                <p className="text-gray-600 mt-1 text-sm leading-relaxed">
                  {step.description}
                </p>
              </div>
            ))}
          </div>
        </div>

        {/* CTA */}
        <div className="mt-12 text-center">
          <Link
            href="/auth?mode=register"
            className="btn-primary px-8 py-4 text-lg min-h-[44px]"
          >
            Jetzt kostenlos starten →
          </Link>
        </div>
      </div>
    </LandingSection>
  )
}
