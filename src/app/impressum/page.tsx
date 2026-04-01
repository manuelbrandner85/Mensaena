export const runtime = 'edge'
import Link from 'next/link'
import { Leaf } from 'lucide-react'
export default function ImpressumPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
      <div className="max-w-2xl mx-auto">
        <Link href="/" className="flex items-center gap-2 mb-8">
          <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center">
            <Leaf className="w-4 h-4 text-white" />
          </div>
          <span className="font-bold text-gray-900">Mensaena</span>
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
