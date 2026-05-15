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

        {/* Team */}
        <h2>Wer steckt dahinter</h2>
        <div className="not-prose my-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex items-start gap-5 rounded-2xl p-6" style={{ background: 'rgba(22,32,53,0.80)', border: '1px solid rgba(199,147,99,0.15)' }}>
            <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl text-2xl font-semibold" style={{ fontFamily: 'var(--font-cinema), serif', background: 'rgba(199,147,99,0.15)', border: '1px solid rgba(199,147,99,0.25)', color: '#c79363' }}>
              MB
            </div>
            <div>
              <div className="font-semibold text-base" style={{ color: '#ece5d6' }}>Manuel Brandner</div>
              <div className="text-[11px] tracking-[0.12em] uppercase mt-0.5 mb-3" style={{ color: '#64748B' }}>Gründer & Entwickler · Bad Kreuznach</div>
              <p className="text-sm leading-relaxed" style={{ color: '#94A3B8' }}>
                Mensaena ist ein Herzensprojekt – gegründet 2024, weil Nachbarschaften wieder
                lebendiger werden sollten. Alles, was du auf Mensaena siehst, entsteht in meiner Freizeit.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-5 rounded-2xl p-6" style={{ background: 'rgba(22,32,53,0.80)', border: '1px solid rgba(43,86,99,0.30)' }}>
            <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl text-2xl font-semibold" style={{ fontFamily: 'var(--font-cinema), serif', background: 'rgba(43,86,99,0.25)', border: '1px solid rgba(43,86,99,0.40)', color: '#7ab8c4' }}>
              UV
            </div>
            <div>
              <div className="font-semibold text-base" style={{ color: '#ece5d6' }}>Uwe Vetter</div>
              <div className="text-[11px] tracking-[0.12em] uppercase mt-0.5 mb-3" style={{ color: '#64748B' }}>Mitgründer · Aragona, Italien</div>
              <p className="text-sm leading-relaxed" style={{ color: '#94A3B8' }}>
                Uwe bringt Erfahrung in Community-Building und ist mitverantwortlich für die
                rechtliche und organisatorische Seite von Mensaena.
              </p>
            </div>
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
            className="inline-flex items-center gap-2.5 rounded-full px-6 py-3 text-sm font-medium tracking-wide transition-all hover:opacity-90"
            style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)', color: '#0a1420' }}
          >
            Jetzt kostenlos mitmachen
            <ArrowRight className="h-4 w-4" aria-hidden="true" />
          </Link>
          <Link
            href="/spenden"
            className="inline-flex items-center gap-2.5 rounded-full px-6 py-3 text-sm font-medium tracking-wide transition-all hover:opacity-80"
            style={{ background: 'rgba(22,32,53,0.70)', border: '1px solid rgba(199,147,99,0.28)', color: '#c79363' }}
          >
            <Heart className="h-4 w-4" style={{ color: '#c79363' }} aria-hidden="true" />
            Mensaena unterstützen
          </Link>
          <Link
            href="/kontakt"
            className="inline-flex items-center gap-2.5 rounded-full px-6 py-3 text-sm font-medium tracking-wide transition-all hover:opacity-80"
            style={{ background: 'rgba(22,32,53,0.50)', border: '1px solid rgba(255,255,255,0.08)', color: '#94A3B8' }}
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
  const icoStyle = color === 'primary'
    ? { background: 'rgba(199,147,99,0.12)', border: '1px solid rgba(199,147,99,0.22)', color: '#c79363' }
    : { background: 'rgba(43,86,99,0.20)', border: '1px solid rgba(43,86,99,0.35)', color: '#7ab8c4' }
  return (
    <div className="p-5 rounded-2xl" style={{ background: 'rgba(22,32,53,0.75)', border: '1px solid rgba(255,255,255,0.05)' }}>
      <div className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl" style={icoStyle}>
        <Icon className="h-5 w-5" aria-hidden="true" />
      </div>
      <div className="font-semibold text-sm mb-1.5" style={{ color: '#ece5d6' }}>{title}</div>
      <p className="text-[13px] leading-relaxed" style={{ color: '#94A3B8' }}>{text}</p>
    </div>
  )
}
