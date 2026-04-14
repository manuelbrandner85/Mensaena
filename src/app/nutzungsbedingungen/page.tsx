import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Nutzungsbedingungen',
  description:
    'Nutzungsbedingungen der Mensaena-Plattform – kostenlos, gemeinnützig und fair.',
  alternates: { canonical: `${SITE_URL}/nutzungsbedingungen` },
}

export default function NutzungsbedingungenPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Nutzungsbedingungen', url: `${SITE_URL}/nutzungsbedingungen` },
        ])}
      />
      <LegalPageShell
        index="§ 03"
        eyebrow="Nutzungsbedingungen"
        title="Spielregeln der Gemeinschaft"
        intro="Kostenlos, gemeinnützig und fair. Hier steht, wie wir miteinander umgehen."
      >
        <h2>1. Geltungsbereich</h2>
        <p>
          Diese Nutzungsbedingungen gelten für die Nutzung der Mensaena-Plattform
          (mensaena.de und www.mensaena.de) und aller damit verbundenen Dienste.
          Mit der Registrierung akzeptierst du diese Bedingungen.
        </p>

        <h2>2. Leistungsbeschreibung</h2>
        <p>
          Mensaena ist eine kostenlose Gemeinwohl-Plattform zur lokalen Vernetzung von Menschen.
          Die Plattform ermöglicht das Inserieren von Hilfsangeboten und -gesuchen, Community-Chats,
          Tierhilfe, regionale Versorgung, Krisenunterstützung und weitere Funktionen.
        </p>

        <h2>3. Registrierung &amp; Konto</h2>
        <ul>
          <li>Die Registrierung ist ab 16 Jahren erlaubt.</li>
          <li>Du bist für die Sicherheit deines Kontos selbst verantwortlich.</li>
          <li>Jede Person darf nur ein Konto besitzen.</li>
          <li>Falschangaben bei der Registrierung können zur Sperrung führen.</li>
        </ul>

        <h2>4. Verhaltensregeln &amp; Handelsverbot</h2>
        <p>Auf Mensaena ist Folgendes untersagt:</p>
        <ul>
          <li>Hassrede, Diskriminierung oder Belästigung anderer Nutzer</li>
          <li>Verbreitung von Falschinformationen oder Spam</li>
          <li>Werbung für kommerzielle Zwecke ohne ausdrückliche Erlaubnis</li>
          <li>Teilen von rechtswidrigen oder anstößigen Inhalten</li>
          <li>Missbrauch des Krisensystems für nicht dringende Anfragen</li>
        </ul>
        <div className="not-prose mt-4 p-5 bg-amber-50 rounded-2xl border border-amber-200">
          <p className="text-sm font-semibold text-amber-800 mb-2">Kein Handel &amp; keine Geldgeschäfte</p>
          <p className="text-sm text-amber-700 leading-relaxed">
            Auf der Mensaena-Plattform dürfen <strong>keine kommerziellen Geschäfte, Verkäufe oder Geldtransaktionen</strong> durchgeführt werden.
            Mensaena ist ausschließlich für kostenlose, gemeinnützige Nachbarschaftshilfe gedacht.
            Verstöße können zur Sperrung des Kontos führen.
          </p>
        </div>

        <h2>5. Inhalte &amp; Verantwortung</h2>
        <p>
          Nutzer sind selbst für die von ihnen erstellten Inhalte verantwortlich.
          Mensaena behält sich vor, Inhalte zu entfernen, die gegen diese Bedingungen verstoßen.
          Mensaena übernimmt keine Haftung für die Richtigkeit von Nutzerinhalten.
        </p>

        <h2>6. Kostenlosigkeit</h2>
        <p>
          Die Nutzung von Mensaena ist und bleibt kostenlos. Es gibt keine versteckten Gebühren,
          keine Abonnements und keine Werbung. Mensaena finanziert sich über freiwillige Spenden
          und ehrenamtliches Engagement.
        </p>

        <h2>7. Konto-Kündigung</h2>
        <p>
          Du kannst dein Konto jederzeit unter Einstellungen löschen. Mensaena kann Konten bei
          schwerwiegenden Verstößen gegen diese Bedingungen sperren oder löschen.
        </p>

        <h2>8. Änderungen</h2>
        <p>
          Mensaena behält sich vor, diese Nutzungsbedingungen anzupassen. Wesentliche Änderungen
          werden den Nutzern rechtzeitig mitgeteilt.
        </p>

        <h2>9. Kontakt</h2>
        <div className="not-prose grid grid-cols-1 sm:grid-cols-2 gap-6 my-4">
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
          E-Mail:{' '}
          <a href="mailto:info@mensaena.de">
            info@mensaena.de
          </a>
        </p>

        <p className="text-xs text-ink-400 pt-6 mt-6 border-t border-stone-200 tracking-wide uppercase">Stand: April 2026</p>
      </LegalPageShell>
    </>
  )
}
