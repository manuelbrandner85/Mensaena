import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Impressum',
  description:
    'Impressum der Mensaena-Plattform – Angaben gemäß § 5 TMG.',
  alternates: { canonical: `${SITE_URL}/impressum` },
}

export default function ImpressumPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Impressum', url: `${SITE_URL}/impressum` },
        ])}
      />
      <LegalPageShell
        index="§ 01"
        eyebrow="Rechtliches"
        title="Impressum"
        intro="Angaben gemäß § 5 TMG zum Betreiber dieser Plattform."
      >
        <p><strong>Angaben gemäß &sect; 5 TMG</strong></p>

        <div className="not-prose grid grid-cols-1 sm:grid-cols-2 gap-6 my-6">
          <div>
            <p className="font-display text-lg text-ink-800 mb-1">Uwe Vetter</p>
            <p className="text-sm text-ink-600 leading-relaxed">
              Via d&apos;Ascoli 25<br />
              I-93021 Aragona (AG)<br />
              Italien
            </p>
          </div>
          <div>
            <p className="font-display text-lg text-ink-800 mb-1">Manuel Brandner</p>
            <p className="text-sm text-ink-600 leading-relaxed">
              Im Wahlsberg 10<br />
              55545 Bad Kreuznach<br />
              Deutschland
            </p>
          </div>
        </div>

        <p>
          <strong>Kontakt</strong><br />
          E-Mail:{' '}
          <a href="mailto:info@mensaena.de">
            info@mensaena.de
          </a>
        </p>
        <p>
          <strong>Verantwortlich für den Inhalt nach &sect; 55 Abs.&nbsp;2 RStV</strong><br />
          Uwe Vetter &amp; Manuel Brandner (s.o.)
        </p>

        <h2>Haftungsausschluss</h2>
        <p>
          Die Inhalte dieser Seiten wurden mit größter Sorgfalt erstellt.
          Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte
          können wir jedoch keine Gewähr übernehmen.
        </p>

        <h2>Streitschlichtung</h2>
        <p>
          Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit:{' '}
          <a
            href="https://ec.europa.eu/consumers/odr"
            target="_blank"
            rel="noopener noreferrer"
          >
            https://ec.europa.eu/consumers/odr
          </a>
          .<br />
          Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren
          vor einer Verbraucherschlichtungsstelle teilzunehmen.
        </p>
      </LegalPageShell>
    </>
  )
}
