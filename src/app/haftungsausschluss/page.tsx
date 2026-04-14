import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Haftungsausschluss',
  description:
    'Haftungsausschluss (Disclaimer) der Mensaena-Plattform.',
  alternates: { canonical: `${SITE_URL}/haftungsausschluss` },
}

export default function HaftungsausschlussPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Haftungsausschluss', url: `${SITE_URL}/haftungsausschluss` },
        ])}
      />
      <LegalPageShell
        index="§ 04"
        eyebrow="Disclaimer"
        title="Haftungsausschluss"
        intro="Sorgfalt und Grenzen unserer Verantwortung. Klar geregelt."
      >
        <h2>1. Haftung für Inhalte</h2>
        <p>
          Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit,
          Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen.
          Als Diensteanbieter sind wir gemäß § 7 Abs. 1 TMG für eigene Inhalte auf diesen
          Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 TMG sind
          wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde
          Informationen zu überwachen.
        </p>

        <h2>2. Haftung für Links</h2>
        <p>
          Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen
          Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen.
          Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Links umgehend entfernen.
        </p>

        <h2>3. Nutzer-generierte Inhalte</h2>
        <p>
          Mensaena ist eine Community-Plattform, auf der Nutzer eigene Inhalte erstellen und teilen.
          Die Verantwortung für nutzer-generierte Inhalte liegt beim jeweiligen Ersteller.
          Mensaena übernimmt keine Haftung für die Richtigkeit, Vollständigkeit oder
          Rechtmäßigkeit dieser Inhalte.
        </p>

        <h2>4. Verfügbarkeit</h2>
        <p>
          Mensaena bemüht sich um eine möglichst unterbrechungsfreie Verfügbarkeit der Plattform.
          Ein Anspruch auf ständige Verfügbarkeit besteht jedoch nicht.
        </p>

        <h2>5. Krisenhilfe-Disclaimer</h2>
        <div className="not-prose p-5 bg-red-50 rounded-2xl border border-red-100 my-4">
          <p className="text-red-800 leading-relaxed">
            <strong>Wichtig:</strong> Die Krisenhilfe-Funktionen auf Mensaena ersetzen keinen
            professionellen Rettungsdienst. Bei akuter Lebensgefahr rufe immer zuerst die{' '}
            <strong>112</strong> an. Mensaena übernimmt keine Haftung für die Qualität
            oder Rechtzeitigkeit von Hilfsleistungen, die über die Plattform vermittelt werden.
          </p>
        </div>

        <h2>6. Urheberrecht</h2>
        <p>
          Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen
          dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art
          der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen
          Zustimmung des jeweiligen Autors.
        </p>

        <h2>7. Kein Handel &amp; keine Geldgeschäfte</h2>
        <div className="not-prose p-5 bg-amber-50 rounded-2xl border border-amber-200 my-4">
          <p className="text-amber-800 leading-relaxed">
            Mensaena ist eine gemeinnützige Plattform für kostenlose Nachbarschaftshilfe.
            <strong> Kommerzieller Handel, Verkäufe und Geldtransaktionen sind auf der Plattform ausdrücklich nicht gestattet.</strong>{' '}
            Mensaena übernimmt keinerlei Haftung für etwaige Geschäfte, die Nutzer untereinander
            außerhalb der Plattform vereinbaren.
          </p>
        </div>

        <h2>8. Kontakt</h2>
        <p>
          E-Mail:{' '}
          <a href="mailto:info@mensaena.de">info@mensaena.de</a>
        </p>

        <p className="text-xs text-ink-400 pt-6 mt-6 border-t border-stone-200 tracking-wide uppercase">Stand: April 2026</p>
      </LegalPageShell>
    </>
  )
}
