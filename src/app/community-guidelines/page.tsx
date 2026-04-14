import type { Metadata } from 'next'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Community-Richtlinien',
  description:
    'Community-Richtlinien der Mensaena-Plattform. Respektvolles Miteinander für eine starke Nachbarschaft.',
  alternates: { canonical: `${SITE_URL}/community-guidelines` },
}

export default function CommunityGuidelinesPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Community-Richtlinien', url: `${SITE_URL}/community-guidelines` },
        ])}
      />
      <LegalPageShell
        index="§ 05"
        eyebrow="Community"
        title="Wie wir miteinander umgehen"
        intro="Mensaena lebt von gegenseitigem Respekt und Zusammenhalt. Diese Richtlinien helfen uns, eine sichere und freundliche Umgebung für alle zu schaffen."
      >
        <div className="not-prose p-5 bg-primary-50 rounded-2xl border border-primary-100 my-4">
          <p className="text-primary-800 font-medium leading-relaxed">
            Behandle andere so, wie du selbst behandelt werden möchtest. Mensaena ist ein Ort
            für echte Begegnungen — bringe deinen besten Selbst mit.
          </p>
        </div>

        <h2>1. Respektvoller Umgang</h2>
        <ul>
          <li>Behandle alle Mitglieder mit Respekt und Würde.</li>
          <li>Keine Beleidigungen, Bedrohungen oder persönlichen Angriffe.</li>
          <li>Akzeptiere unterschiedliche Meinungen und Lebensstile.</li>
          <li>Kommuniziere sachlich und konstruktiv.</li>
        </ul>

        <h2>2. Keine Diskriminierung</h2>
        <p>
          Diskriminierung aufgrund von Herkunft, Geschlecht, Religion, sexueller Orientierung,
          Behinderung oder anderer persönlicher Merkmale ist strikt untersagt.
        </p>

        <h2>3. Ehrlichkeit &amp; Vertrauen</h2>
        <ul>
          <li>Erstelle authentische Profile mit korrekten Angaben.</li>
          <li>Keine Fake-Accounts oder Identitätstäuschung.</li>
          <li>Stehe zu deinen Zusagen und Angeboten.</li>
          <li>Melde Vertrauensbrüche an die Moderation.</li>
        </ul>

        <h2>4. Inhaltsrichtlinien</h2>
        <p>Folgende Inhalte sind nicht erlaubt:</p>
        <ul>
          <li>Gewaltverherrlichende oder extremistische Inhalte</li>
          <li>Spam, Kettenbriefe oder unerwünschte Werbung</li>
          <li>Falschinformationen oder Verschwörungstheorien</li>
          <li>Urheberrechtlich geschütztes Material ohne Erlaubnis</li>
          <li>Pornografische oder ungeeignete Inhalte</li>
          <li>Persönliche Daten Dritter ohne deren Einwilligung</li>
        </ul>

        <h2>5. Krisensystem</h2>
        <p>
          Das Krisenhilfe-System ist für echte Notfälle und dringende Situationen gedacht.
          Missbrauch des Krisensystems führt zur Sperrung. Bei lebensbedrohlichen Notfällen
          wende dich immer zuerst an die <strong>112</strong>.
        </p>

        <h2>6. Datenschutz</h2>
        <ul>
          <li>Teile keine persönlichen Daten anderer Nutzer öffentlich.</li>
          <li>Respektiere die Privatsphäre-Einstellungen anderer.</li>
          <li>Keine Screenshots von privaten Nachrichten ohne Zustimmung.</li>
        </ul>

        <h2>7. Melden &amp; Moderation</h2>
        <p>
          Wenn du Verstöße gegen diese Richtlinien bemerkst, melde sie bitte über die
          Melde-Funktion oder per E-Mail an{' '}
          <a href="mailto:info@mensaena.de">info@mensaena.de</a>.
          Unser Moderations-Team prüft alle Meldungen und ergreift entsprechende Maßnahmen.
        </p>

        <h2>8. Konsequenzen</h2>
        <p>Bei Verstößen gegen diese Richtlinien kann Mensaena:</p>
        <ul>
          <li>Inhalte entfernen oder ausblenden</li>
          <li>Verwarnungen aussprechen</li>
          <li>Funktionen temporär einschränken</li>
          <li>Konten vorübergehend oder dauerhaft sperren</li>
        </ul>

        <p className="text-xs text-ink-400 pt-6 mt-6 border-t border-stone-200 tracking-wide uppercase">Stand: April 2026</p>
      </LegalPageShell>
    </>
  )
}
