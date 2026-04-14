import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'

export const metadata: Metadata = {
  title: 'Impressum',
  description:
    'Impressum der Mensaena-Plattform – Angaben gemäß § 5 TMG.',
  alternates: { canonical: `${SITE_URL}/impressum` },
}

export default function ImpressumPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Impressum', url: `${SITE_URL}/impressum` },
        ])}
      />
      <div className="max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2 mb-8">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={150}
            height={100}
            className="h-10 w-auto object-contain"
          />
        </Link>
        <div className="card p-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Impressum</h1>
          <div className="prose prose-sm text-gray-700 space-y-4">
            <p><strong>Angaben gemäß &sect; 5 TMG</strong></p>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <p className="font-medium text-gray-900">Uwe Vetter</p>
                <p>
                  Via d&apos;Ascoli 25<br />
                  I-93021 Aragona (AG)<br />
                  Italien
                </p>
              </div>
              <div>
                <p className="font-medium text-gray-900">Manuel Brandner</p>
                <p>
                  Im Wahlsberg 10<br />
                  55545 Bad Kreuznach<br />
                  Deutschland
                </p>
              </div>
            </div>

            <p>
              <strong>Kontakt</strong><br />
              E-Mail:{' '}
              <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">
                info@mensaena.de
              </a>
            </p>
            <p>
              <strong>Verantwortlich für den Inhalt nach &sect; 55 Abs.&nbsp;2 RStV</strong><br />
              Uwe Vetter &amp; Manuel Brandner (s.o.)
            </p>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">Haftungsausschluss</h2>
              <p>
                Die Inhalte dieser Seiten wurden mit größter Sorgfalt erstellt.
                Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte
                können wir jedoch keine Gewähr übernehmen.
              </p>
            </section>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">Streitschlichtung</h2>
              <p>
                Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit:{' '}
                <a
                  href="https://ec.europa.eu/consumers/odr"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary-600 hover:underline"
                >
                  https://ec.europa.eu/consumers/odr
                </a>
                .<br />
                Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren
                vor einer Verbraucherschlichtungsstelle teilzunehmen.
              </p>
            </section>
          </div>
        </div>
        <Link href="/" className="block text-center mt-6 text-sm text-gray-500 hover:text-gray-700">← Zurück zur Startseite</Link>
      </div>
    </div>
  )
}
