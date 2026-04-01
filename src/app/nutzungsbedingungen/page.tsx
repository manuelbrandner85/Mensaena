import Link from 'next/link'
import Image from 'next/image'

export const metadata = {
  title: 'Nutzungsbedingungen – Mensaena',
  description: 'Nutzungsbedingungen der Mensaena-Plattform.',
}

export default function NutzungsbedingungenPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <div className="max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2 mb-8 group">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={140}
            height={94}
            className="h-10 w-auto object-contain"
          />
        </Link>
        <div className="card p-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Nutzungsbedingungen</h1>
          <p className="text-xs text-gray-400 mb-6">Stand: April 2026</p>

          <div className="space-y-6 text-sm text-gray-700">
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">1. Geltungsbereich</h2>
              <p>
                Diese Nutzungsbedingungen gelten für die Nutzung der Mensaena-Plattform
                (mensaena.de und mensaena.manuelbrandner4.workers.dev) und aller damit verbundenen Dienste.
                Mit der Registrierung akzeptierst du diese Bedingungen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">2. Leistungsbeschreibung</h2>
              <p>
                Mensaena ist eine kostenlose Gemeinwohl-Plattform zur lokalen Vernetzung von Menschen.
                Die Plattform ermöglicht das Inserieren von Hilfsangeboten und -gesuchen, Community-Chats,
                Tierhilfe, regionale Versorgung, Krisenunterstützung und weitere Funktionen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">3. Registrierung & Konto</h2>
              <ul className="list-disc pl-5 space-y-1">
                <li>Die Registrierung ist ab 16 Jahren erlaubt.</li>
                <li>Du bist für die Sicherheit deines Kontos selbst verantwortlich.</li>
                <li>Jede Person darf nur ein Konto besitzen.</li>
                <li>Falschangaben bei der Registrierung können zur Sperrung führen.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">4. Verhaltensregeln</h2>
              <p className="mb-2">Auf Mensaena ist Folgendes untersagt:</p>
              <ul className="list-disc pl-5 space-y-1">
                <li>Hassrede, Diskriminierung oder Belästigung anderer Nutzer</li>
                <li>Verbreitung von Falschinformationen oder Spam</li>
                <li>Werbung für kommerzielle Zwecke ohne ausdrückliche Erlaubnis</li>
                <li>Teilen von rechtswidrigen oder anstößigen Inhalten</li>
                <li>Missbrauch des Krisensystems für nicht dringende Anfragen</li>
              </ul>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">5. Inhalte & Verantwortung</h2>
              <p>
                Nutzer sind selbst für die von ihnen erstellten Inhalte verantwortlich.
                Mensaena behält sich vor, Inhalte zu entfernen, die gegen diese Bedingungen verstoßen.
                Mensaena übernimmt keine Haftung für die Richtigkeit von Nutzerinhalten.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">6. Kostenlosigkeit</h2>
              <p>
                Die Nutzung von Mensaena ist und bleibt kostenlos. Es gibt keine versteckten Gebühren,
                keine Abonnements und keine Werbung. Mensaena finanziert sich über freiwillige Spenden
                und ehrenamtliches Engagement.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">7. Konto-Kündigung</h2>
              <p>
                Du kannst dein Konto jederzeit unter Einstellungen löschen. Mensaena kann Konten bei
                schwerwiegenden Verstößen gegen diese Bedingungen sperren oder löschen.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">8. Änderungen</h2>
              <p>
                Mensaena behält sich vor, diese Nutzungsbedingungen anzupassen. Wesentliche Änderungen
                werden den Nutzern rechtzeitig mitgeteilt.
              </p>
            </section>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">9. Kontakt</h2>
              <p>
                Bei Fragen zu diesen Nutzungsbedingungen wende dich an:{' '}
                <a href="mailto:hallo@mensaena.de" className="text-primary-600 hover:underline">
                  hallo@mensaena.de
                </a>
              </p>
            </section>
          </div>
        </div>

        <div className="text-center mt-6 flex gap-4 justify-center">
          <Link href="/datenschutz" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            Datenschutzerklärung
          </Link>
          <Link href="/" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            ← Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
