import type { Metadata } from 'next'
import Link from 'next/link'
import { Mail, MapPin, Leaf } from 'lucide-react'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import SocialMediaButtons from '@/components/layout/SocialMediaButtons'
import LegalPageShell from '@/components/shared/LegalPageShell'
import ContactForm from '@/components/shared/ContactForm'

export const metadata: Metadata = {
  title: 'Kontakt',
  description:
    'Kontaktiere das Mensaena-Team bei Fragen, Feedback oder Problemen.',
  alternates: { canonical: `${SITE_URL}/kontakt` },
}

export default function KontaktPage() {
  return (
    <>
      <JsonLd
        data={generateBreadcrumbSchema([
          { name: 'Startseite', url: SITE_URL },
          { name: 'Kontakt', url: `${SITE_URL}/kontakt` },
        ])}
      />
      <LegalPageShell
        index="§ 06"
        eyebrow="Kontakt"
        title="Schreib uns."
        intro="Wir freuen uns über deine Nachricht – egal ob Frage, Feedback oder Lob."
      >
        <div className="not-prose space-y-4">
          <div className="p-5 bg-primary-50/60 rounded-2xl border border-primary-100 spotlight">
            <div className="flex items-center gap-2 mb-2">
              <Mail className="w-4 h-4 text-primary-700" />
              <span className="text-[10px] tracking-[0.14em] uppercase font-semibold text-primary-800">E-Mail</span>
            </div>
            <a
              href="mailto:info@mensaena.de"
              className="font-display text-2xl text-ink-800 hover:text-primary-700 transition-colors link-sweep"
            >
              info@mensaena.de
            </a>
            <p className="text-ink-500 text-xs mt-2 leading-relaxed">
              Wir antworten in der Regel innerhalb von 1–2 Werktagen.
            </p>
          </div>

          <div className="p-5 bg-stone-50 rounded-2xl border border-stone-200">
            <div className="flex items-center gap-2 mb-2">
              <MapPin className="w-4 h-4 text-ink-600" />
              <span className="text-[10px] tracking-[0.14em] uppercase font-semibold text-ink-700">Adresse</span>
            </div>
            <p className="text-sm text-ink-700 leading-relaxed">
              Manuel Brandner<br />
              Im Wahlsberg 10<br />
              55545 Bad Kreuznach
            </p>
          </div>

          <div className="p-5 bg-primary-50/40 rounded-2xl border border-primary-100">
            <div className="flex items-center gap-2 mb-2">
              <Leaf className="w-4 h-4 text-primary-700" />
              <span className="text-[10px] tracking-[0.14em] uppercase font-semibold text-primary-800">Community</span>
            </div>
            <p className="text-ink-600 text-xs leading-relaxed">
              Als registrierter Nutzer kannst du den Community-Chat nutzen,
              um dich mit der Mensaena-Community auszutauschen.
            </p>
            <Link
              href="/auth?mode=login"
              className="link-sweep inline-block mt-3 text-[10px] font-semibold tracking-[0.14em] uppercase text-primary-700 hover:text-primary-800"
            >
              Jetzt anmelden →
            </Link>
          </div>

          <div className="p-5 bg-stone-50 rounded-2xl border border-stone-200">
            <div className="flex items-center gap-2 mb-3">
              <span className="text-[10px] tracking-[0.14em] uppercase font-semibold text-ink-700">Social Media</span>
            </div>
            <p className="text-ink-500 text-xs mb-3 leading-relaxed">
              Folge uns für Updates, News und Community-Inhalte.
            </p>
            <SocialMediaButtons variant="light" />
          </div>
        </div>

        <h2>Formular</h2>
        <p>Alternativ erreichst du uns direkt über das Formular – wir antworten auf dieselbe E-Mail-Adresse.</p>
        <ContactForm />

        <h2>Häufige Anliegen</h2>
        <ul>
          <li><strong>Technische Probleme:</strong> Bitte beschreibe das Problem und deinen Browser.</li>
          <li><strong>Feedback &amp; Ideen:</strong> Wir freuen uns über Verbesserungsvorschläge!</li>
          <li><strong>Meldungen:</strong> Problematische Inhalte bitte mit Link melden.</li>
          <li><strong>Datenschutz:</strong> Anfragen gem. DSGVO bitte per E-Mail.</li>
        </ul>
      </LegalPageShell>
    </>
  )
}
