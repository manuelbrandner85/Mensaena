import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'

export const metadata: Metadata = {
  title: 'Haftungsausschluss',
  description:
    'Haftungsausschluss (Disclaimer) der Mensaena-Plattform.',
  alternates: { canonical: `${SITE_URL}/haftungsausschluss` },
}

export default function HaftungsausschlussPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Haftungsausschluss', url: `${SITE_URL}/haftungsausschluss` },
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
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Haftungsausschluss (Disclaimer)</h1>
          <p className="text-xs text-gray-400 mb-6">Stand: April 2026</p>

          <div className="space-y-6 text-sm text-gray-700">
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">1. Haftung für Inhalte</h2>
              <p>
                Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit,
                Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen.
                Als Diensteanbieter sind wir gemäß § 7 Abs. 1 TMG für eigene Inhalte auf diesen
                Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 TMG sind
                wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde
                Informationen zu überwachen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">2. Haftung für Links</h2>
              <p>
                Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen
                Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr
                übernehmen. Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter
                oder Betreiber der Seiten verantwortlich. Bei Bekanntwerden von Rechtsverletzungen
                werden wir derartige Links umgehend entfernen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">3. Nutzer-generierte Inhalte</h2>
              <p>
                Mensaena ist eine Community-Plattform, auf der Nutzer eigene Inhalte erstellen und teilen.
                Die Verantwortung für nutzer-generierte Inhalte (Beiträge, Nachrichten, Kommentare,
                Pinnwand-Einträge) liegt beim jeweiligen Ersteller. Mensaena übernimmt keine Haftung
                für die Richtigkeit, Vollständigkeit oder Rechtmäßigkeit dieser Inhalte.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">4. Verfügbarkeit</h2>
              <p>
                Mensaena bemüht sich um eine möglichst unterbrechungsfreie Verfügbarkeit der Plattform.
                Ein Anspruch auf ständige Verfügbarkeit besteht jedoch nicht. Wartungsarbeiten, technische
                Störungen oder höhere Gewalt können zu vorübergehenden Einschränkungen führen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">5. Krisenhilfe-Disclaimer</h2>
              <div className="p-4 bg-red-50 rounded-xl border border-red-100">
                <p className="text-red-800">
                  <strong>Wichtig:</strong> Die Krisenhilfe-Funktionen auf Mensaena ersetzen keinen
                  professionellen Rettungsdienst. Bei akuter Lebensgefahr rufe immer zuerst die{' '}
                  <strong>112</strong> an. Mensaena übernimmt keine Haftung für die Qualität
                  oder Rechtzeitigkeit von Hilfsleistungen, die über die Plattform vermittelt werden.
                </p>
              </div>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">6. Urheberrecht</h2>
              <p>
                Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen
                dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art
                der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen
                Zustimmung des jeweiligen Autors bzw. Erstellers.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">7. Kein Handel &amp; keine Geldgeschäfte</h2>
              <div className="p-4 bg-amber-50 rounded-xl border border-amber-200">
                <p>
                  Mensaena ist eine gemeinnützige Plattform für kostenlose Nachbarschaftshilfe.
                  <strong> Kommerzieller Handel, Verkäufe und Geldtransaktionen sind auf der Plattform ausdrücklich nicht gestattet.</strong>{' '}
                  Mensaena übernimmt keinerlei Haftung für etwaige Geschäfte, die Nutzer untereinander
                  außerhalb der Plattform vereinbaren.
                </p>
              </div>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">8. Kontakt</h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-3">
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
                E-Mail:{' '}
                <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">
                  info@mensaena.de
                </a>
              </p>
            </section>
          </div>
        </div>

        <div className="text-center mt-6 flex gap-4 justify-center">
          <Link href="/impressum" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            Impressum
          </Link>
          <Link href="/datenschutz" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            Datenschutz
          </Link>
          <Link href="/" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
