import type { Metadata } from 'next'
import Link from 'next/link'
import { Leaf, Heart, Users, Shield } from 'lucide-react'
import PublicHeader from '@/components/layout/PublicHeader'
import PublicFooter from '@/components/layout/PublicFooter'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema, generateOrganizationSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'

export const metadata: Metadata = {
  title: 'Über uns',
  description:
    'Erfahre mehr über Mensaena – unsere Mission für Gemeinwohl, Nachbarschaftshilfe und Nachhaltigkeit.',
  alternates: { canonical: `${SITE_URL}/about` },
}

export default function AboutPage() {
  return (
    <main className="min-h-screen">
      <JsonLd
        data={[
          generateOrganizationSchema(),
          generateBreadcrumbSchema([
            { name: 'Startseite', url: SITE_URL },
            { name: 'Über uns', url: `${SITE_URL}/about` },
          ]),
        ]}
      />
      <PublicHeader />
      <section className="pt-32 pb-20 bg-gradient-to-b from-primary-50 to-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-100 text-primary-700 rounded-full text-sm font-medium mb-6">
              <Leaf className="w-4 h-4" /> Über Mensaena
            </div>
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6">
              Freiheit beginnt im <span className="text-primary-600">Bewusstsein</span>
            </h1>
            <p className="text-xl text-gray-600 leading-relaxed max-w-2xl mx-auto">
              Mensaena ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen in ihrer Nachbarschaft 
              vernetzt – lokal, persönlich und nachhaltig.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
            <div className="card p-8">
              <div className="w-12 h-12 bg-primary-100 rounded-xl flex items-center justify-center mb-4">
                <Heart className="w-6 h-6 text-primary-600" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-3">Unsere Mission</h2>
              <p className="text-gray-600 leading-relaxed">
                Wir glauben, dass echte Gemeinschaft und gegenseitige Hilfe die Grundlagen einer 
                gesunden Gesellschaft sind. Mensaena schafft den digitalen Raum dafür – kostenlos, 
                ohne Werbung und ohne Datenmissbrauch.
              </p>
            </div>
            <div className="card p-8">
              <div className="w-12 h-12 bg-sage-100 rounded-xl flex items-center justify-center mb-4">
                <Users className="w-6 h-6 text-sage-600" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-3">Für alle</h2>
              <p className="text-gray-600 leading-relaxed">
                Mensaena richtet sich an Menschen, die aktiv ihre Nachbarschaft mitgestalten möchten – 
                ob als Helfer, als Suchende, als Tier- oder Naturliebhaber, oder als Teil der 
                lokalen Gemeinschaft.
              </p>
            </div>
            <div className="card p-8">
              <div className="w-12 h-12 bg-trust-100 rounded-xl flex items-center justify-center mb-4">
                <Shield className="w-6 h-6 text-trust-500" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-3">Unsere Werte</h2>
              <ul className="text-gray-600 space-y-2">
                <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 bg-primary-400 rounded-full" />Transparenz & Vertrauen</li>
                <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 bg-primary-400 rounded-full" />Datenschutz first</li>
                <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 bg-primary-400 rounded-full" />Kostenlos für alle</li>
                <li className="flex items-center gap-2"><span className="w-1.5 h-1.5 bg-primary-400 rounded-full" />Nachhaltig & lokal</li>
              </ul>
            </div>
            <div className="card p-8">
              <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center mb-4">
                <Leaf className="w-6 h-6 text-green-600" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-3">Kontakt</h2>
              <p className="text-gray-600 leading-relaxed mb-3">
                Hast du Fragen, Feedback oder möchtest du mitmachen?
              </p>
              <a href="mailto:hallo@mensaena.de" className="text-primary-600 font-medium hover:underline">
                hallo@mensaena.de
              </a>
            </div>
          </div>

          <div className="text-center">
            <Link href="/register" className="btn-primary text-base px-8 py-4 mr-4">
              Jetzt kostenlos mitmachen
            </Link>
            <Link href="/" className="btn-secondary text-base px-8 py-4">
              Zurück zur Startseite
            </Link>
          </div>
        </div>
      </section>
      <PublicFooter />
    </main>
  )
}
