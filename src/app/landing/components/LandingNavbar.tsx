'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { Menu, X, Home } from 'lucide-react'

const navLinks = [
  { id: 'features', label: 'Funktionen' },
  { id: 'how-it-works', label: 'So funktioniert\u2019s' },
  { id: 'categories', label: 'Kategorien' },
  { id: 'map', label: 'Karte' },
]

export default function LandingNavbar() {
  const [scrolled, setScrolled] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 50)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  useEffect(() => {
    document.body.style.overflow = mobileOpen ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [mobileOpen])

  const smoothScroll = useCallback((id: string) => {
    setMobileOpen(false)
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  const scrollToTop = useCallback(() => {
    setMobileOpen(false)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  return (
    <header
      className={`fixed top-0 w-full z-50 transition-all duration-200 ${
        scrolled
          ? 'bg-white/95 backdrop-blur-sm shadow-sm border-b border-warm-200'
          : 'bg-transparent'
      }`}
      role="banner"
    >
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between" aria-label="Hauptnavigation">
        {/* Logo */}
        <button
          onClick={scrollToTop}
          className="flex items-center gap-2 group min-h-[44px] min-w-[44px]"
          aria-label="Nach oben scrollen"
        >
          <Home className="w-5 h-5 text-primary-500" aria-hidden="true" />
          <span className="text-xl font-bold text-gray-900">
            Mensa<span className="text-primary-500">ena</span>
          </span>
        </button>

        {/* Desktop nav links */}
        <div className="hidden md:flex items-center gap-1">
          {navLinks.map((link) => (
            <button
              key={link.id}
              onClick={() => smoothScroll(link.id)}
              className="px-3 py-2 text-sm font-medium text-gray-600 hover:text-primary-700 hover:bg-primary-50 rounded-lg transition-colors min-h-[44px]"
            >
              {link.label}
            </button>
          ))}
        </div>

        {/* Desktop CTA */}
        <div className="hidden md:flex items-center gap-3">
          <Link
            href="/auth?mode=login"
            className="btn-secondary text-sm px-4 py-2 min-h-[44px] inline-flex items-center"
          >
            Anmelden
          </Link>
          <Link
            href="/auth?mode=register"
            className="btn-primary text-sm px-5 py-2.5 min-h-[44px] inline-flex items-center"
          >
            Kostenlos starten
          </Link>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="md:hidden min-w-[44px] min-h-[44px] flex items-center justify-center rounded-xl hover:bg-warm-100 transition-colors"
          aria-label={mobileOpen ? 'Menü schließen' : 'Menü öffnen'}
          aria-expanded={mobileOpen}
          aria-controls="mobile-menu"
        >
          {mobileOpen ? (
            <X className="w-5 h-5" aria-hidden="true" />
          ) : (
            <Menu className="w-5 h-5" aria-hidden="true" />
          )}
        </button>
      </nav>

      {/* Mobile fullscreen overlay */}
      {mobileOpen && (
        <div
          id="mobile-menu"
          className="md:hidden fixed inset-0 top-16 bg-white z-40 animate-fade-up overflow-y-auto"
          role="dialog"
          aria-label="Mobile Navigation"
        >
          <div className="px-6 py-8 space-y-2">
            {navLinks.map((link) => (
              <button
                key={link.id}
                onClick={() => smoothScroll(link.id)}
                className="block w-full text-left px-4 py-3.5 text-base font-medium text-gray-700 hover:bg-primary-50 hover:text-primary-700 rounded-xl transition-colors min-h-[44px]"
              >
                {link.label}
              </button>
            ))}
            <div className="pt-6 space-y-3 border-t border-warm-200 mt-4">
              <Link
                href="/auth?mode=login"
                onClick={() => setMobileOpen(false)}
                className="btn-secondary w-full justify-center py-3.5 text-base min-h-[44px]"
              >
                Anmelden
              </Link>
              <Link
                href="/auth?mode=register"
                onClick={() => setMobileOpen(false)}
                className="btn-primary w-full justify-center py-3.5 text-base min-h-[44px]"
              >
                Kostenlos starten
              </Link>
            </div>
          </div>
        </div>
      )}
    </header>
  )
}
