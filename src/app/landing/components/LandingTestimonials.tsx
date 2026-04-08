'use client'

import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

const testimonials = [
  {
    quote:
      'Durch Mensaena habe ich endlich meine Nachbarn kennengelernt. Letzte Woche hat mir Herr Müller bei der Gartenarbeit geholfen – einfach so!',
    name: 'Anna K.',
    location: 'Berlin-Kreuzberg',
    initial: 'A',
  },
  {
    quote:
      'Als alleinerziehende Mutter ist Mensaena ein Segen. Die Nachbarschaft hilft sich hier wirklich gegenseitig – nicht nur digital, sondern ganz real.',
    name: 'Sarah M.',
    location: 'München-Schwabing',
    initial: 'S',
  },
  {
    quote:
      'Ich bin 72 und nicht so fit mit Technik, aber Mensaena ist so einfach, dass sogar ich es kann. Jetzt helfe ich anderen beim Kochen!',
    name: 'Helmut B.',
    location: 'Hamburg-Eppendorf',
    initial: 'H',
  },
]

export default function LandingTestimonials() {
  const { ref, isVisible } = useScrollAnimation()

  return (
    <LandingSection background="white">
      <h2 className="text-3xl md:text-4xl font-bold text-center text-gray-900">
        Was unsere Nachbarn sagen
      </h2>

      {/* Desktop: grid */}
      <div
        ref={ref}
        className="hidden md:grid md:grid-cols-3 gap-6 mt-12"
      >
        {testimonials.map((t, i) => (
          <TestimonialCard
            key={i}
            {...t}
            isVisible={isVisible}
            delay={i * 100}
          />
        ))}
      </div>

      {/* Mobile: horizontal snap scroll */}
      <div className="md:hidden mt-10 -mx-4 px-4 overflow-x-auto snap-x snap-mandatory flex gap-4 no-scrollbar pb-4">
        {testimonials.map((t, i) => (
          <div
            key={i}
            className="snap-center min-w-[85vw] flex-shrink-0"
          >
            <TestimonialCard {...t} isVisible={true} delay={0} />
          </div>
        ))}
      </div>

      <p className="text-xs text-gray-400 text-center mt-6">
        *Beispielhafte Darstellung. Echte Erfahrungsberichte folgen.*
      </p>
    </LandingSection>
  )
}

function TestimonialCard({
  quote,
  name,
  location,
  initial,
  isVisible,
  delay,
}: {
  quote: string
  name: string
  location: string
  initial: string
  isVisible: boolean
  delay: number
}) {
  return (
    <div
      className={`bg-white rounded-2xl p-8 shadow-sm border border-warm-100 h-full flex flex-col ${
        isVisible ? 'animate-fade-up' : 'opacity-0'
      }`}
      style={{ animationDelay: `${delay}ms` }}
    >
      {/* Quote mark */}
      <span
        className="text-5xl text-primary-200 font-serif leading-none select-none"
        aria-hidden="true"
      >
        &bdquo;
      </span>
      <p className="text-gray-700 italic mt-2 flex-1 leading-relaxed">
        {quote}
      </p>

      {/* Author */}
      <div className="flex items-center gap-3 mt-6 pt-4 border-t border-warm-100">
        <div className="w-10 h-10 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center font-semibold text-sm flex-shrink-0">
          {initial}
        </div>
        <div>
          <p className="font-semibold text-gray-900 text-sm">{name}</p>
          <p className="text-sm text-gray-500">{location}</p>
        </div>
      </div>
    </div>
  )
}
