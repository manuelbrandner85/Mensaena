import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'

export const metadata: Metadata = {
  title: 'Community-Richtlinien',
  description:
    'Community-Richtlinien der Mensaena-Plattform. Respektvolles Miteinander für eine starke Nachbarschaft.',
  alternates: { canonical: `${SITE_URL}/community-guidelines` },
}

export default function CommunityGuidelinesPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Community-Richtlinien', url: `${SITE_URL}/community-guidelines` },
        ])}
      />
      <div className="max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2 mb-8">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={140}
            height={94}
            className="h-10 w-auto object-contain"
          />
        </Link>
        <div className="card p-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Community-Richtlinien</h1>
          <p className="text-xs text-gray-400 mb-6">Stand: April 2026</p>

          <div className="space-y-6 text-sm text-gray-700">
            <div className="p-4 bg-primary-50 rounded-xl border border-primary-100">
              <p className="text-primary-800 font-medium">
                Mensaena lebt von gegenseitigem Respekt und Zusammenhalt. Diese Richtlinien helfen uns,
                eine sichere und freundliche Umgebung für alle zu schaffen.
              </p>
            </div>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">1. Respektvoller Umgang</h2>
              <ul className="list-disc pl-5 space-y-1">
                <li>Behandle alle Mitglieder mit Respekt und Wuerde.</li>
                <li>Keine Beleidigungen, Bedrohungen oder persönlichen Angriffe.</li>
                <li>Akzeptiere unterschiedliche Meinungen und Lebensstile.</li>
                <li>Kommuniziere sachlich und konstruktiv.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">2. Keine Diskriminierung</h2>
              <p>
                Diskriminierung aufgrund von Herkunft, Geschlecht, Religion, sexueller Orientierung,
                Behinderung oder anderer persoenlicher Merkmale ist strikt untersagt.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">3. Ehrlichkeit &amp; Vertrauen</h2>
              <ul className="list-disc pl-5 space-y-1">
                <li>Erstelle authentische Profile mit korrekten Angaben.</li>
                <li>Keine Fake-Accounts oder Identitaetstaeuchung.</li>
                <li>Stehe zu deinen Zusagen und Angeboten.</li>
                <li>Melde Vertrauensbrueche an die Moderation.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">4. Inhaltsrichtlinien</h2>
              <p className="mb-2">Folgende Inhalte sind nicht erlaubt:</p>
              <ul className="list-disc pl-5 space-y-1">
                <li>Gewaltverherrlichende oder extremistische Inhalte</li>
                <li>Spam, Kettenbriefe oder unerwuenschte Werbung</li>
                <li>Falschinformationen oder Verschwoerungstheorien</li>
                <li>Urheberrechtlich geschuetztes Material ohne Erlaubnis</li>
                <li>Pornografische oder ungeeignete Inhalte</li>
                <li>Persoenliche Daten Dritter ohne deren Einwilligung</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">5. Krisensystem</h2>
              <p>
                Das Krisenhilfe-System ist für echte Notfaelle und dringende Situationen gedacht.
                Missbrauch des Krisensystems fuehrt zur Sperrung. Bei lebensbedrohlichen Notfaellen
                wende dich immer zuerst an die 112.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">6. Datenschutz</h2>
              <ul className="list-disc pl-5 space-y-1">
                <li>Teile keine persönlichen Daten anderer Nutzer öffentlich.</li>
                <li>Respektiere die Privatsphaere-Einstellungen anderer.</li>
                <li>Keine Screenshots von privaten Nachrichten ohne Zustimmung.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">7. Melden &amp; Moderation</h2>
              <p>
                Wenn du Verstoesse gegen diese Richtlinien bemerkst, melde sie bitte über die
                Melde-Funktion oder per E-Mail an{' '}
                <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">
                  info@mensaena.de
                </a>.
                Unser Moderations-Team prüft alle Meldungen und ergreift entsprechende Maßnahmen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">8. Konsequenzen</h2>
              <p>Bei Verstoessen gegen diese Richtlinien kann Mensaena:</p>
              <ul className="list-disc pl-5 space-y-1 mt-2">
                <li>Inhalte entfernen oder ausblenden</li>
                <li>Verwarnungen aussprechen</li>
                <li>Funktionen temporaer einschraenken</li>
                <li>Konten vorübergehend oder dauerhaft sperren</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">9. Kontakt</h2>
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

            <div className="p-4 bg-sage-50 rounded-xl border border-sage-100 mt-4">
              <p className="text-sage-800 text-xs">
                Diese Richtlinien können angepasst werden. Wesentliche Änderungen werden rechtzeitig kommuniziert.
                Fragen? Schreib uns an{' '}
                <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">info@mensaena.de</a>.
              </p>
            </div>
          </div>
        </div>

        <div className="text-center mt-6 flex gap-4 justify-center">
          <Link href="/nutzungsbedingungen" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            Nutzungsbedingungen
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
