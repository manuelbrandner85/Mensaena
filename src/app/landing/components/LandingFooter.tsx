'use client'

import Link from 'next/link'
import Image from 'next/image'
import SocialMediaButtons from '@/components/layout/SocialMediaButtons'

const platformLinks = [
  { href: '#features', label: 'Funktionen', scroll: true },
  { href: '#how-it-works', label: 'So funktioniert’s', scroll: true },
  { href: '#categories', label: 'Kategorien', scroll: true },
  { href: '#map', label: 'Karte', scroll: true },
]

const legalLinks = [
  { href: '/agb', label: 'AGB' },
  { href: '/nutzungsbedingungen', label: 'Nutzungsbedingungen' },
  { href: '/datenschutz', label: 'Datenschutz' },
  { href: '/impressum', label: 'Impressum' },
  { href: '/haftungsausschluss', label: 'Haftungsausschluss' },
  { href: '/community-guidelines', label: 'Community-Richtlinien' },
  { href: '/kontakt', label: 'Kontakt' },
]

const contactLinks = [
  { href: 'mailto:info@mensaena.de', label: 'info@mensaena.de' },
  { href: 'mailto:info@mensaena.de?subject=Feedback', label: 'Feedback geben' },
  { href: 'mailto:info@mensaena.de?subject=Bug-Report', label: 'Fehler melden' },
]

export default function LandingFooter() {
  const smoothScroll = (id: string) => {
    const target = id.replace('#', '')
    document.getElementById(target)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <footer className="bg-gray-900 text-gray-400 py-12 md:py-16 px-4" role="contentinfo">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Mensaena */}
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                width={140}
                height={94}
                className="h-9 w-auto object-contain brightness-0 invert"
              />
            </div>
            <p className="text-sm leading-relaxed mb-4">
              Nachbarschaftshilfe neu gedacht. Kostenlos, gemeinnützig, für alle.
            </p>
            {/* Social Media */}
            <div>
              <h4 className="text-white font-semibold text-xs uppercase tracking-wider mb-3">Folge uns</h4>
              <SocialMediaButtons variant="dark" compact />
            </div>
          </div>

          {/* Plattform */}
          <div>
            <h3 className="text-white font-semibold mb-3">Plattform</h3>
            <ul className="space-y-1">
              {platformLinks.map((link) =>
                link.scroll ? (
                  <li key={link.href}>
                    <button
                      onClick={() => smoothScroll(link.href)}
                      className="block py-1 text-sm hover:text-primary-400 transition-colors text-left min-h-[44px] flex items-center"
                    >
                      {link.label}
                    </button>
                  </li>
                ) : (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="block py-1 text-sm hover:text-primary-400 transition-colors min-h-[44px] flex items-center"
                    >
                      {link.label}
                    </Link>
                  </li>
                )
              )}
            </ul>
          </div>

          {/* Rechtliches */}
          <div>
            <h3 className="text-white font-semibold mb-3">Rechtliches</h3>
            <ul className="space-y-1">
              {legalLinks.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="block py-1 text-sm hover:text-primary-400 transition-colors min-h-[44px] flex items-center"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Kontakt */}
          <div>
            <h3 className="text-white font-semibold mb-3">Kontakt</h3>
            <ul className="space-y-1">
              {contactLinks.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="block py-1 text-sm hover:text-primary-400 transition-colors min-h-[44px] flex items-center"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Copyright */}
        <div className="border-t border-gray-800 mt-8 pt-8 flex flex-col sm:flex-row justify-between items-center gap-4">
          <p className="text-sm text-gray-500">
            &copy; {new Date().getFullYear()} Mensaena. Mit{' '}
            <span className="text-primary-400" aria-label="Herz">&#x1F49A;</span>{' '}
            für die Nachbarschaft gebaut.
          </p>
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="text-sm text-gray-500 hover:text-primary-400 transition-colors min-h-[44px] min-w-[44px] flex items-center"
            aria-label="Nach oben scrollen"
          >
            Nach oben &uarr;
          </button>
        </div>
      </div>
    </footer>
  )
}
