import type { Metadata } from 'next'
import Link from 'next/link'
import { Heart, Users, Shield, Leaf, ArrowRight, Zap, Globe, Lock } from 'lucide-react'
import JsonLd from '@/components/JsonLd'
import { generateBreadcrumbSchema, generateOrganizationSchema } from '@/lib/structured-data'
import { SITE_URL } from '@/lib/seo'
import LegalPageShell from '@/components/shared/LegalPageShell'

export const metadata: Metadata = {
  title: 'Über uns',
  description:
    'Mensaena ist eine gemeinnützige Nachbarschaftshilfe-Plattform – werbefrei, spendenfinanziert und 100 % DSGVO-konform. Erfahre mehr über unsere Mission.',
  alternates: { canonical: `${SITE_URL}/about` },
  openGraph: {
    title: 'Über Mensaena – Nachbarschaft neu gedacht',
    description:
      'Keine Werbung. Keine Investoren. Nur Nachbarn. Erfahre, warum wir Mensaena gebaut haben.',
    url: `${SITE_URL}/about`,
    type: 'website',
  },
}

export default function AboutPage() {
  return (
    <>
      <JsonLd
        data={[
          generateOrganizationSchema(),
          generateBreadcrumbSchema([
            { name: 'Startseite', url: SITE_URL },
            { name: 'Über uns', url: `${SITE_URL}/about` },
          ]),
        ]}
      />
      <LegalPageShell
        index="§ 00"
        eyebrow="Über Mensaena"
        title="Freiheit beginnt im Bewusstsein."
        intro="Mensaena ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen in ihrer Nachbarschaft vernetzt – lokal, persönlich und ohne Werbung."
      >
        {/* Mission */}
        <h2>Unsere Mission</h2>
        <p>
          Wir glauben, dass echte Gemeinschaft und gegenseitige Hilfe die Grundlagen einer gesunden
          Gesellschaft sind. Mensaena schafft den digitalen Raum dafür – <strong>kostenlos,
          ohne Werbung und ohne Datenmissbrauch</strong>.
        </p>
        <p>
          Die Idee ist einfach: Was wäre, wenn deine Nachbarn wieder füreinander da wären? Wenn
          Herr Müller nebenan dir beim Umzug hilft, weil du letzte Woche seinen Hund spazieren
          geführt hast? Wenn die alleinerziehende Mutter im dritten Stock weiß, dass jemand
          auf ihre Kinder aufpasst, falls sie mal länger arbeiten muss?
        </p>
        <p>
          Genau das ermöglichen wir – digital, aber menschlich.
        </p>

        {/* Values */}
        <h2>Was uns antreibt</h2>
        <div className="not-prose grid gap-4 sm:grid-cols-2 my-8">
          <ValueCard
            Icon={Heart}
            color="primary"
            title="Gemeinwohl vor Profit"
            text="Mensaena hat keine Investoren, keine Werbepartner und keine bezahlten Mitarbeiter. Jede Entscheidung orientiert sich am Nutzen für die Gemeinschaft."
          />
          <ValueCard
            Icon={Lock}
            color="trust"
            title="Datenschutz first"
            text="DSGVO ist für uns kein Compliance-Thema, sondern Grundprinzip. Wir verkaufen keine Daten und tracken dich nicht über dein Profil hinaus."
          />
          <ValueCard
            Icon={Globe}
            color="primary"
            title="Kostenlos für alle"
            text="Mensaena ist und bleibt kostenlos. Wir finanzieren uns ausschließlich durch freiwillige Spenden – transparent und ohne Paywall."
          />
          <ValueCard
            Icon={Zap}
            color="trust"
            title="Offen & transparent"
            text="Wir veröffentlichen unsere Betriebskosten und zeigen, wo jede Spende hingeht. Open Source ist unser Ziel, sobald der Code stabil ist."
          />
        </div>

        {/* What we build */}
        <h2>Was wir bauen</h2>
        <p>
          Mensaena ist mehr als ein schwarzes Brett. Auf der Plattform findest du:
        </p>
        <ul>
          <li><strong>Hilfsangebote & -gesuche</strong> – von Handwerksarbeiten bis Kinderbetreuung</li>
          <li><strong>Nachbarschafts-Karte</strong> – sieh auf einen Blick, wer in deiner Nähe aktiv ist</li>
          <li><strong>Gruppen & Vereine</strong> – organisiere deine Nachbarschaftsinitiativen digital</li>
          <li><strong>Marktplatz</strong> – verschenken, tauschen, günstig abgeben</li>
          <li><strong>Zeitbank</strong> – Stunden statt Euro: gib Zeit, erhalte Zeit zurück</li>
          <li><strong>Notfall-Warnungen</strong> – regionale Unwetter- und Katastrophenschutzwarnungen</li>
        </ul>

        {/* Founder */}
        <h2>Wer steckt dahinter</h2>
        <div className="not-prose my-6 flex items-start gap-5 rounded-2xl border border-stone-200 bg-stone-50 p-6">
          <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl bg-primary-100 text-2xl font-display font-semibold text-primary-700">
            MB
          </div>
          <div>
            <div className="font-semibold text-ink-800 text-base">Manuel Brandner</div>
            <div className="text-[11px] tracking-[0.12em] uppercase text-ink-400 mt-0.5 mb-3">Gründer & Entwickler · Bad Kreuznach</div>
            <p className="text-sm text-ink-600 leading-relaxed">
              Mensaena ist ein Ein-Mann-Projekt. Ich habe es 2024 gegründet, weil ich selbst
              erleben musste, wie anonym Wohnquartiere geworden sind – und wie viel besser es sein
              könnte, wenn Nachbarn sich wieder kennen. Alles, was du auf Mensaena siehst,
              entsteht in meiner Freizeit.
            </p>
          </div>
        </div>

        {/* Financing */}
        <h2>Wie wir uns finanzieren</h2>
        <p>
          Mensaena finanziert sich <strong>ausschließlich durch freiwillige Spenden</strong>. Drei
          Euro halten die Plattform einen Monat lang am Laufen – pro 60 Nachbar:innen. Wir haben
          keine Werbung, keine Tracking-Pixel und keine Venture-Capital-Geldgeber.
        </p>
        <p>
          Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt –
          wir arbeiten daran. Spenden sind daher noch nicht steuerlich absetzbar.
        </p>

        {/* CTAs */}
        <div className="not-prose mt-10 flex flex-wrap gap-3">
          <Link
            href="/auth?mode=register"
            className="inline-flex items-center gap-2.5 rounded-full bg-ink-900 px-6 py-3 text-sm font-medium tracking-wide text-paper transition-colors hover:bg-ink-700"
          >
            Jetzt kostenlos mitmachen
            <ArrowRight className="h-4 w-4" aria-hidden="true" />
          </Link>
          <Link
            href="/spenden"
            className="inline-flex items-center gap-2.5 rounded-full border border-stone-300 px-6 py-3 text-sm font-medium tracking-wide text-ink-700 transition-colors hover:border-primary-300 hover:text-primary-700"
          >
            <Heart className="h-4 w-4 text-primary-500" aria-hidden="true" />
            Mensaena unterstützen
          </Link>
          <Link
            href="/kontakt"
            className="inline-flex items-center gap-2.5 rounded-full border border-stone-200 px-6 py-3 text-sm font-medium tracking-wide text-ink-500 transition-colors hover:border-stone-300 hover:text-ink-700"
          >
            Kontakt aufnehmen
          </Link>
        </div>
      </LegalPageShell>
    </>
  )
}

function ValueCard({
  Icon,
  color,
  title,
  text,
}: {
  Icon: React.ComponentType<{ className?: string }>
  color: 'primary' | 'trust'
  title: string
  text: string
}) {
  const bg  = color === 'primary' ? 'bg-primary-50/60 border-primary-100' : 'bg-stone-50 border-stone-200'
  const ico = color === 'primary' ? 'bg-primary-100 text-primary-600'    : 'bg-stone-100 text-ink-600'
  return (
    <div className={`rounded-2xl border p-5 ${bg}`}>
      <div className={`mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl ${ico}`}>
        <Icon className="h-5 w-5" aria-hidden="true" />
      </div>
      <div className="font-semibold text-ink-800 text-sm mb-1.5">{title}</div>
      <p className="text-[13px] text-ink-500 leading-relaxed">{text}</p>
    </div>
  )
}
