import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Allgemeine Geschäftsbedingungen (AGB)',
  description:
    'Allgemeine Geschäftsbedingungen der Mensaena-Plattform. Kostenlos, gemeinnützig und transparent.',
  alternates: { canonical: `${SITE_URL}/agb` },
}

export default function AGBPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'AGB', url: `${SITE_URL}/agb` },
        ])}
      />
      <LegalPageShell
        index="§ 07"
        eyebrow="AGB"
        title="Allgemeine Geschäftsbedingungen"
        intro="Klare Spielregeln für eine kostenlose, gemeinnützige und transparente Plattform."
      >
        <h2>1. Geltungsbereich</h2>
        <p>
          Diese Allgemeinen Geschäftsbedingungen gelten für die Nutzung der Mensaena-Plattform
          (mensaena.de und www.mensaena.de) und aller damit verbundenen Dienste.
          Mit der Registrierung und Nutzung akzeptierst du diese Bedingungen.
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

        <h2>4. Verhaltensregeln</h2>
        <p>Auf Mensaena ist Folgendes untersagt:</p>
        <ul>
          <li>Hassrede, Diskriminierung oder Belästigung anderer Nutzer</li>
          <li>Verbreitung von Falschinformationen oder Spam</li>
          <li>Werbung für kommerzielle Zwecke ohne ausdrückliche Erlaubnis</li>
          <li>Teilen von rechtswidrigen oder anstößigen Inhalten</li>
          <li>Missbrauch des Krisensystems für nicht dringende Anfragen</li>
        </ul>

        <h2>5. Inhalte &amp; Verantwortung</h2>
        <p>
          Nutzer sind selbst für die von ihnen erstellten Inhalte verantwortlich.
          Mensaena behält sich vor, Inhalte zu entfernen, die gegen diese Bedingungen verstoßen.
        </p>

        <h2>6. Kostenlosigkeit</h2>
        <p>
          Die Nutzung von Mensaena ist und bleibt kostenlos. Es gibt keine versteckten Gebühren,
          keine Abonnements und keine Werbung.
        </p>

        <h2>7. Haftung</h2>
        <p>
          Mensaena haftet nicht für Schäden, die durch die Nutzung der Plattform entstehen,
          es sei denn, sie wurden vorsätzlich oder grob fahrlässig verursacht.
        </p>

        <h2>8. Konto-Kündigung</h2>
        <p>
          Du kannst dein Konto jederzeit unter Einstellungen löschen. Mensaena kann Konten bei
          schwerwiegenden Verstößen sperren oder löschen.
        </p>

        <h2>9. Änderungen</h2>
        <p>
          Mensaena behält sich vor, diese AGB anzupassen. Wesentliche Änderungen
          werden den Nutzern rechtzeitig mitgeteilt.
        </p>

        <h2>10. Kontakt</h2>
        <p>
          E-Mail:{' '}
          <a href="mailto:info@mensaena.de">info@mensaena.de</a>
        </p>

        <p className="text-xs text-ink-400 pt-6 mt-6 border-t border-stone-200 tracking-wide uppercase">Stand: April 2026</p>
      </LegalPageShell>
    </>
  )
}
