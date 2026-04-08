import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'

export const metadata: Metadata = {
  title: 'Datenschutzerklärung',
  description:
    'Datenschutzerklärung der Mensaena-Plattform. Erfahre, wie wir deine Daten schützen – DSGVO-konform und transparent.',
  alternates: { canonical: `${SITE_URL}/datenschutz` },
}

export default function DatenschutzPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Datenschutz', url: `${SITE_URL}/datenschutz` },
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
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Datenschutzerklärung</h1>
          <div className="space-y-4 text-sm text-gray-700">
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">1. Verantwortlicher</h2>
              <p>Mensaena, hallo@mensaena.de – Datenschutzbeauftragter kontaktierbar unter dieser Adresse.</p>
            </section>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">2. Datenerhebung</h2>
              <p>Wir erheben nur die Daten, die für die Bereitstellung unserer Dienste notwendig sind: E-Mail, Name, Standort (optional), Beiträge und Nachrichten.</p>
            </section>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">3. Supabase</h2>
              <p>Authentifizierung und Datenspeicherung erfolgen über Supabase (EU-Server). Daten werden verschlüsselt übertragen und gespeichert.</p>
            </section>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">4. Cloudflare</h2>
              <p>Wir nutzen Cloudflare für CDN, Sicherheit und Performance. Cloudflare kann temporäre Verbindungsdaten verarbeiten.</p>
            </section>
            <section>
              <h2 className="font-semibold text-gray-900 mb-2">5. Deine Rechte</h2>
              <p>Du hast das Recht auf Auskunft, Berichtigung, Löschung und Einschränkung der Verarbeitung deiner Daten. Kontakt: hallo@mensaena.de</p>
            </section>
            <p className="text-xs text-gray-500 pt-4 border-t border-warm-200">Dies ist ein Platzhalter. Bitte durch eine rechtsgeprüfte Datenschutzerklärung ersetzen.</p>
          </div>
        </div>
        <Link href="/" className="block text-center mt-6 text-sm text-gray-500 hover:text-gray-700">← Zurück zur Startseite</Link>
      </div>
    </div>
  )
}
