'use client'

import type { ReactNode } from 'react'

type Testimonial = {
  quote: ReactNode
  name: string
  loc: string
  d: string
}

const TESTIMONIALS: Testimonial[] = [
  {
    quote: (
      <>
        Durch Mensaena habe ich endlich meine Nachbarn kennengelernt. Letzte Woche hat mir Herr
        Müller bei der <em>Gartenarbeit</em> geholfen — einfach so.
      </>
    ),
    name: 'Anna K.',
    loc: 'Berlin-Kreuzberg',
    d: '',
  },
  {
    quote: (
      <>
        Als alleinerziehende Mutter ist Mensaena ein Segen. Die Nachbarschaft hilft sich hier
        wirklich gegenseitig — nicht nur digital, sondern <em>ganz real</em>.
      </>
    ),
    name: 'Sarah M.',
    loc: 'München-Schwabing',
    d: 'd1',
  },
  {
    quote: (
      <>
        Ich bin 72 und nicht so fit mit Technik. Aber Mensaena ist so <em>einfach</em>, dass sogar
        ich es kann. Jetzt helfe ich anderen beim Kochen.
      </>
    ),
    name: 'Helmut B.',
    loc: 'Hamburg-Eppendorf',
    d: 'd2',
  },
]

export default function LandingTestimonials() {
  return (
    <section className="cin-wrap cin-section" id="testimonials">
      <div className="cin-section-head">
        <div className="num">
          <b>— 06</b>
          <br />
          Stimmen aus der
          <br />
          Gemeinschaft
        </div>
        <h2>
          Was unsere <em>Nachbarn</em> erzählen.
        </h2>
      </div>

      <div className="cin-testimonials cin-section-end">
        <div className="big-quote" aria-hidden="true">
          "
        </div>
        <div className="grid">
          {TESTIMONIALS.map((t) => (
            <figure key={t.name} className={`cin-testimonial reveal ${t.d}`}>
              <blockquote>
                <span className="q">„</span>
                {t.quote}
                <span className="q">"</span>
              </blockquote>
              <figcaption className="who">
                <span className="line" />
                <span className="name">{t.name}</span>
                <span className="loc">{t.loc}</span>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  )
}
