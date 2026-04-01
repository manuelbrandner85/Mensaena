import Link from 'next/link'
import Image from 'next/image'
import { Mail, MessageCircle, Leaf } from 'lucide-react'

export const metadata = {
  title: 'Kontakt – Mensaena',
  description: 'Kontaktiere das Mensaena-Team bei Fragen, Feedback oder Problemen.',
}

export default function KontaktPage() {
  return (
    <div className="min-h-screen bg-background py-16 px-4">
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
          <div className="flex items-center gap-3 mb-6">
            <div className="w-12 h-12 bg-primary-100 rounded-xl flex items-center justify-center">
              <MessageCircle className="w-6 h-6 text-primary-600" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Kontakt</h1>
              <p className="text-sm text-gray-500">Wir freuen uns über deine Nachricht</p>
            </div>
          </div>

          <div className="space-y-6 text-sm text-gray-700">
            <div className="p-4 bg-primary-50 rounded-xl border border-primary-100">
              <div className="flex items-center gap-2 mb-2">
                <Mail className="w-4 h-4 text-primary-600" />
                <span className="font-semibold text-gray-900">E-Mail</span>
              </div>
              <a
                href="mailto:hallo@mensaena.de"
                className="text-primary-600 hover:text-primary-700 hover:underline font-medium"
              >
                hallo@mensaena.de
              </a>
              <p className="text-gray-500 text-xs mt-1">
                Wir antworten in der Regel innerhalb von 1–2 Werktagen.
              </p>
            </div>

            <div className="p-4 bg-sage-50 rounded-xl border border-sage-100">
              <div className="flex items-center gap-2 mb-2">
                <Leaf className="w-4 h-4 text-sage-600" />
                <span className="font-semibold text-gray-900">Community</span>
              </div>
              <p className="text-gray-600 text-xs leading-relaxed">
                Als registrierter Nutzer kannst du den Community-Chat nutzen, 
                um dich mit der Mensaena-Community auszutauschen.
              </p>
              <Link
                href="/login"
                className="inline-block mt-2 text-primary-600 hover:underline font-medium text-xs"
              >
                Jetzt anmelden →
              </Link>
            </div>

            <section>
              <h2 className="font-semibold text-gray-900 mb-2">Häufige Anliegen</h2>
              <ul className="space-y-2 text-gray-600">
                <li className="flex items-start gap-2">
                  <span className="w-1.5 h-1.5 bg-primary-400 rounded-full mt-1.5 flex-shrink-0" />
                  <span><strong>Technische Probleme:</strong> Bitte beschreibe das Problem und deinen Browser.</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="w-1.5 h-1.5 bg-primary-400 rounded-full mt-1.5 flex-shrink-0" />
                  <span><strong>Feedback & Ideen:</strong> Wir freuen uns über Verbesserungsvorschläge!</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="w-1.5 h-1.5 bg-primary-400 rounded-full mt-1.5 flex-shrink-0" />
                  <span><strong>Meldungen:</strong> Problematische Inhalte bitte mit Link melden.</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="w-1.5 h-1.5 bg-primary-400 rounded-full mt-1.5 flex-shrink-0" />
                  <span><strong>Datenschutz:</strong> Anfragen gem. DSGVO bitte per E-Mail.</span>
                </li>
              </ul>
            </section>
          </div>
        </div>

        <div className="text-center mt-6">
          <Link href="/" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            ← Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
