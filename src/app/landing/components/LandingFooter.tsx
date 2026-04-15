'use client'

import Link from 'next/link'
import Image from 'next/image'
import SocialMediaButtons from '@/components/layout/SocialMediaButtons'

const platformLinks = [
  { href: '#features',     label: 'Funktionen',     scroll: true },
  { href: '#how-it-works', label: 'So funktionierts', scroll: true },
  { href: '#categories',   label: 'Kategorien',     scroll: true },
  { href: '#map',          label: 'Karte',          scroll: true },
]

const legalLinks = [
  { href: '/agb',                   label: 'AGB' },
  { href: '/nutzungsbedingungen',   label: 'Nutzungsbedingungen' },
  { href: '/datenschutz',           label: 'Datenschutz' },
  { href: '/impressum',             label: 'Impressum' },
  { href: '/haftungsausschluss',    label: 'Haftungsausschluss' },
  { href: '/community-guidelines',  label: 'Community-Richtlinien' },
  { href: '/kontakt',               label: 'Kontakt' },
]

const contactLinks = [
  { href: 'mailto:info@mensaena.de',                    label: 'info@mensaena.de' },
  { href: 'mailto:info@mensaena.de?subject=Feedback',   label: 'Feedback geben' },
  { href: 'mailto:info@mensaena.de?subject=Bug-Report', label: 'Fehler melden' },
]

/**
 * LandingFooter — statement section.
 *
 * A full-width editorial footer that treats the wordmark as the hero
 * of the closing page: oversized Fraunces serif, deep ink background,
 * mono meta labels, single horizontal divider.
 */
export default function LandingFooter() {
  const smoothScroll = (id: string) => {
    const target = id.replace('#', '')
    document.getElementById(target)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <footer
      className="relative bg-ink-900 text-stone-300 overflow-hidden"
      role="contentinfo"
    >
      {/* Soft top highlight */}
      <div
        className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary-500/40 to-transparent"
        aria-hidden="true"
      />

      {/* Oversized wordmark */}
      <div className="max-w-7xl mx-auto px-6 md:px-10 pt-24 md:pt-32">
        <div className="flex items-center gap-4 mb-8">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={96}
            height={64}
            className="h-16 w-auto object-contain opacity-95"
          />
          <div className="meta-label meta-label--subtle opacity-80">Mensaena</div>
        </div>
        <div
          className="font-display font-medium leading-[0.82] tracking-[-0.04em] text-stone-100 select-none whitespace-nowrap"
          style={{ fontSize: 'clamp(4.5rem, 18vw, 17rem)' }}
        >
          Mensaena<span className="text-primary-500">.</span>
        </div>
        <p className="mt-10 max-w-xl font-display text-xl md:text-2xl text-stone-300/90 leading-snug">
          Nachbarschaftshilfe, neu gedacht. Kostenlos, gemeinnützig, von der
          Gemeinschaft getragen.
        </p>
      </div>

      {/* Link grid */}
      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-24 md:mt-32 grid grid-cols-2 md:grid-cols-4 gap-10 md:gap-16">
        <FooterColumn label="Plattform">
          {platformLinks.map((link) => (
            <li key={link.href}>
              {link.scroll ? (
                <button
                  onClick={() => smoothScroll(link.href)}
                  className="footer-link"
                >
                  {link.label}
                </button>
              ) : (
                <Link href={link.href} className="footer-link">
                  {link.label}
                </Link>
              )}
            </li>
          ))}
        </FooterColumn>

        <FooterColumn label="Rechtliches">
          {legalLinks.map((link) => (
            <li key={link.href}>
              <Link href={link.href} className="footer-link">
                {link.label}
              </Link>
            </li>
          ))}
        </FooterColumn>

        <FooterColumn label="Kontakt">
          {contactLinks.map((link) => (
            <li key={link.href}>
              <a href={link.href} className="footer-link">
                {link.label}
              </a>
            </li>
          ))}
        </FooterColumn>

        <div>
          <div className="meta-label meta-label--subtle mb-5 opacity-80">Folge uns</div>
          <SocialMediaButtons variant="dark" compact />
        </div>
      </div>

      {/* Bottom bar */}
      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-24 pb-10 pt-8 border-t border-stone-800">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <p className="text-xs text-stone-500">
            © {new Date().getFullYear()} Mensaena · Mit Sorgfalt der Gemeinschaft.
          </p>
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="meta-label meta-label--subtle hover:text-primary-400 transition-colors duration-300"
            aria-label="Nach oben scrollen"
          >
            Zurück nach oben ↑
          </button>
        </div>
      </div>
    </footer>
  )
}

function FooterColumn({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="meta-label meta-label--subtle mb-5 opacity-80">{label}</div>
      <ul className="space-y-3">{children}</ul>
    </div>
  )
}
