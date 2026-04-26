import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Datenschutzerklärung',
  description:
    'Datenschutzerklärung der Mensaena-Plattform. Erfahre, wie wir deine Daten schützen – DSGVO-konform und transparent.',
  alternates: { canonical: `${SITE_URL}/datenschutz` },
}

export default function DatenschutzPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Datenschutz', url: `${SITE_URL}/datenschutz` },
        ])}
      />
      <LegalPageShell
        index="§ 02"
        eyebrow="Datenschutz"
        title="Datenschutzerklärung"
        intro="DSGVO-konform und transparent. So gehen wir mit deinen Daten um."
      >
        <h2>1. Verantwortliche</h2>
        <p>
          <strong>Uwe Vetter</strong><br />
          Via d&apos;Ascoli 25, I-93021 Aragona (AG), Italien
        </p>
        <p>
          <strong>Manuel Brandner</strong><br />
          Im Wahlsberg 10, 55545 Bad Kreuznach, Deutschland
        </p>
        <p>
          E-Mail:{' '}
          <a href="mailto:info@mensaena.de">info@mensaena.de</a>
        </p>

        <h2>2. Datenerhebung</h2>
        <p>Wir erheben nur die Daten, die für die Bereitstellung unserer Dienste notwendig sind: E-Mail, Name, Standort (optional), Beiträge und Nachrichten.</p>

        <h2>3. Supabase</h2>
        <p>Authentifizierung und Datenspeicherung erfolgen über Supabase (EU-Server). Daten werden verschlüsselt übertragen und gespeichert.</p>

        <h2>4. Cookies &amp; lokale Speicherung</h2>
        <p>
          Mensaena verwendet ausschließlich <strong>technisch notwendige Cookies und localStorage-Einträge</strong>.
          Es gibt keine Werbe-, Analyse- oder Tracking-Cookies.
        </p>
        <ul>
          <li>
            <strong>Sitzungs-Cookie (Supabase Auth)</strong> — wird gesetzt, sobald du dich anmeldest.
            Enthält ausschließlich dein verschlüsseltes Auth-Token. Wird beim Abmelden gelöscht.
          </li>
          <li>
            <strong>Cookie-Einwilligung</strong> (<code>mensaena_cookie_consent</code>) — localStorage.
            Speichert deine Entscheidung im Cookie-Banner (Schlüssel + Zeitstempel). Kein Server-Transfer.
          </li>
          <li>
            <strong>Spenden-Badge</strong> (<code>mensaena_donation_badge_dismissed</code>) — localStorage.
            Merkt, ob du den Spenden-Hinweis für 7 Tage geschlossen hast. Kein Server-Transfer.
          </li>
        </ul>
        <p>Du kannst alle localStorage-Einträge jederzeit im Browser löschen (Entwickler-Tools → Application → Local Storage).</p>

        <h2>5. Cloudflare</h2>
        <p>Wir nutzen Cloudflare für CDN, Sicherheit und Performance. Cloudflare kann temporäre Verbindungsdaten verarbeiten.</p>

        <h2>6. Deine Rechte</h2>
        <p>
          Du hast das Recht auf Auskunft, Berichtigung, Löschung und Einschränkung der Verarbeitung deiner Daten.
          Kontakt:{' '}
          <a href="mailto:info@mensaena.de">info@mensaena.de</a>
        </p>

        <p className="text-xs text-ink-400 pt-6 mt-6 border-t border-stone-200 tracking-wide uppercase">Stand: April 2026</p>
      </LegalPageShell>
    </>
  )
}
