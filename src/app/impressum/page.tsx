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
            width={140}
            height={94}
            className="h-10 w-auto object-contain"
          />
        </Link>
        <div className="card p-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">Impressum</h1>
          <div className="prose prose-sm text-gray-700 space-y-4">
            <p><strong>Angaben gemäß § 5 TMG</strong></p>
            <p>Mensaena – die Gemeinwohl Plattform<br />Musterstraße 1<br />12345 Musterstadt</p>
            <p><strong>Kontakt</strong><br />E-Mail: hallo@mensaena.de</p>
            <p><strong>Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV</strong><br />Mensaena Team</p>
            <p className="text-xs text-gray-500">Dies ist ein Platzhalter-Impressum. Bitte durch echte Angaben ersetzen.</p>
          </div>
        </div>
        <Link href="/" className="block text-center mt-6 text-sm text-gray-500 hover:text-gray-700">← Zurück zur Startseite</Link>
      </div>
    </div>
  )
}
