import Link from 'next/link'
import { Leaf, Mail, Shield, FileText, Heart } from 'lucide-react'

const footerLinks = {
  plattform: [
    { href: '#features', label: 'Funktionen' },
    { href: '#how-it-works', label: 'So funktioniert es' },
    { href: '/register', label: 'Registrieren' },
    { href: '/login', label: 'Anmelden' },
  ],
  bereiche: [
    { href: '/dashboard/map', label: 'Interaktive Karte' },
    { href: '/dashboard/rescuer', label: 'Retter-System' },
    { href: '/dashboard/animals', label: 'Tierbereich' },
    { href: '/dashboard/housing', label: 'Wohnen & Alltag' },
    { href: '/dashboard/community', label: 'Community' },
  ],
  rechtliches: [
    { href: '/datenschutz', label: 'Datenschutz' },
    { href: '/impressum', label: 'Impressum' },
    { href: '/nutzungsbedingungen', label: 'Nutzungsbedingungen' },
    { href: '/kontakt', label: 'Kontakt' },
  ],
}

export default function PublicFooter() {
  return (
    <footer className="bg-gray-900 text-gray-300">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Main Footer */}
        <div className="py-16 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-10">
          {/* Brand */}
          <div className="lg:col-span-1">
            <Link href="/" className="flex items-center gap-2.5 mb-4">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center">
                <Leaf className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-bold text-white">Mensaena</span>
            </Link>
            <p className="text-sm text-gray-400 leading-relaxed mb-6">
              Die Gemeinwohl-Plattform. Menschen verbinden, Hilfe organisieren, 
              Ressourcen nachhaltig teilen – lokal und persönlich.
            </p>
            <div className="flex items-center gap-2 text-sm text-gray-500">
              <Heart className="w-4 h-4 text-primary-500" />
              <span>Made with care for the community</span>
            </div>
          </div>

          {/* Plattform */}
          <div>
            <h3 className="text-white font-semibold text-sm uppercase tracking-wider mb-4">
              Plattform
            </h3>
            <ul className="space-y-3">
              {footerLinks.plattform.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-gray-400 hover:text-primary-400 transition-colors"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Bereiche */}
          <div>
            <h3 className="text-white font-semibold text-sm uppercase tracking-wider mb-4">
              Bereiche
            </h3>
            <ul className="space-y-3">
              {footerLinks.bereiche.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-gray-400 hover:text-primary-400 transition-colors"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Rechtliches */}
          <div>
            <h3 className="text-white font-semibold text-sm uppercase tracking-wider mb-4">
              Rechtliches
            </h3>
            <ul className="space-y-3">
              {footerLinks.rechtliches.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-gray-400 hover:text-primary-400 transition-colors"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
            <div className="mt-6 p-3 bg-gray-800 rounded-xl">
              <div className="flex items-center gap-2 mb-1">
                <Mail className="w-4 h-4 text-primary-500" />
                <span className="text-xs font-medium text-white">Kontakt</span>
              </div>
              <a
                href="mailto:hallo@mensaena.de"
                className="text-xs text-gray-400 hover:text-primary-400 transition-colors"
              >
                hallo@mensaena.de
              </a>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="border-t border-gray-800 py-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-gray-500">
            © {new Date().getFullYear()} Mensaena. Alle Rechte vorbehalten.
          </p>
          <div className="flex items-center gap-4">
            <Link href="/datenschutz" className="text-xs text-gray-500 hover:text-gray-300 transition-colors flex items-center gap-1">
              <Shield className="w-3 h-3" /> Datenschutz
            </Link>
            <Link href="/impressum" className="text-xs text-gray-500 hover:text-gray-300 transition-colors flex items-center gap-1">
              <FileText className="w-3 h-3" /> Impressum
            </Link>
          </div>
        </div>
      </div>
    </footer>
  )
}
