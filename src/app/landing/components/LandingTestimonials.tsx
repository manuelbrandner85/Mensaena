'use client'

import LandingSection from './LandingSection'

const testimonials = [
  {
    quote:
      'Durch Mensaena habe ich endlich meine Nachbarn kennengelernt. Letzte Woche hat mir Herr Müller bei der Gartenarbeit geholfen – einfach so.',
    name: 'Anna K.',
    location: 'Berlin-Kreuzberg',
  },
  {
    quote:
      'Als alleinerziehende Mutter ist Mensaena ein Segen. Die Nachbarschaft hilft sich hier wirklich gegenseitig — nicht nur digital, sondern ganz real.',
    name: 'Sarah M.',
    location: 'München-Schwabing',
  },
  {
    quote:
      'Ich bin 72 und nicht so fit mit Technik, aber Mensaena ist so einfach, dass sogar ich es kann. Jetzt helfe ich anderen beim Kochen.',
    name: 'Helmut B.',
    location: 'Hamburg-Eppendorf',
  },
]

export default function LandingTestimonials() {
  return (
    <LandingSection
      id="testimonials"
      background="paper"
      index="06"
      label="Stimmen aus der Gemeinschaft"
      title={
        <>
          Was unsere <span className="text-accent">Nachbarn</span> erzählen.
        </>
      }
    >
      <div className="space-y-24 md:space-y-32">
        {testimonials.map((t, i) => (
          <figure
            key={i}
            className={`reveal reveal-delay-${Math.min(i + 1, 5)} max-w-3xl ${
              i % 2 === 1 ? 'md:ml-auto md:text-right' : ''
            }`}
          >
            <blockquote className="font-display text-3xl md:text-5xl text-ink-800 leading-[1.15] tracking-tight">
              <span className="text-primary-500">„</span>
              {t.quote}
              <span className="text-primary-500">"</span>
            </blockquote>
            <figcaption
              className={`mt-10 flex items-center gap-4 ${
                i % 2 === 1 ? 'md:justify-end' : ''
              }`}
            >
              <span className="block h-px w-10 bg-ink-300" aria-hidden="true" />
              <div>
                <div className="font-display text-lg text-ink-800">{t.name}</div>
                <div className="meta-label meta-label--subtle mt-1">{t.location}</div>
              </div>
            </figcaption>
          </figure>
        ))}
      </div>

      <p className="reveal mt-20 meta-label meta-label--subtle">
        * Beispielhafte Darstellung · Echte Erfahrungsberichte folgen
      </p>
    </LandingSection>
  )
}
