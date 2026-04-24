'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Menu, X, ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'
import LanguageSwitcher from '@/components/shared/LanguageSwitcher'

export default function LandingNavbar() {
  const t = useTranslations('landing')
  const [scrolled, setScrolled] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  const navLinks = [
    { id: 'features',     label: t('navFeatures') },
    { id: 'how-it-works', label: t('navHowItWorks') },
    { id: 'categories',   label: t('navCategories') },
    { id: 'map',          label: t('navMap') },
  ]

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40)
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
      className={`fixed top-0 w-full z-50 transition-all duration-500 ${
        scrolled ? 'bg-paper/80 backdrop-blur-md border-b border-stone-200' : 'bg-transparent'
      }`}
      role="banner"
    >
      <nav
        className="max-w-7xl mx-auto px-6 md:px-10 h-20 flex items-center justify-between"
        aria-label="Hauptnavigation"
      >
        <button
          onClick={scrollToTop}
          className="group flex items-center gap-3 focus:outline-none"
          aria-label="Nach oben scrollen"
        >
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={72}
            height={48}
            priority
            className="h-12 md:h-14 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
          />
          <span className="flex items-baseline">
            <span className="font-display text-2xl md:text-[1.7rem] font-medium tracking-tight text-ink-800 group-hover:text-primary-700 transition-colors duration-300">
              Mensaena
            </span>
            <span className="text-primary-500 font-display text-2xl md:text-[1.7rem] leading-none">.</span>
          </span>
        </button>

        <div className="hidden md:flex items-center gap-10 absolute left-1/2 -translate-x-1/2">
          {navLinks.map((link) => (
            <button
              key={link.id}
              onClick={() => smoothScroll(link.id)}
              className="meta-label meta-label--subtle hover:text-primary-700 transition-colors duration-300"
            >
              {link.label}
            </button>
          ))}
        </div>

        <div className="hidden md:flex items-center gap-4">
          <LanguageSwitcher />
          <button
            onClick={() => smoothScroll('app-download')}
            className="meta-label meta-label--subtle hover:text-primary-700 transition-colors duration-300 inline-flex items-center gap-1.5 cta-app-download"
            aria-label="Zur App-Download-Sektion scrollen"
          >
            <span aria-hidden="true">📱</span>
            App holen
          </button>
          <Link
            href="/auth?mode=login"
            className="meta-label meta-label--subtle hover:text-primary-700 transition-colors duration-300"
          >
            {t('navLogin')}
          </Link>
          <Link
            href="/auth?mode=register"
            className="group inline-flex items-center gap-2 bg-ink-800 hover:bg-ink-700 text-paper px-5 py-2.5 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
          >
            {t('navStart')}
            <ArrowRight className="w-3.5 h-3.5 transition-transform duration-300 group-hover:translate-x-0.5" />
          </Link>
        </div>

        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="md:hidden w-11 h-11 -mr-2 flex items-center justify-center rounded-full hover:bg-stone-100 transition-colors"
          aria-label={mobileOpen ? t('navMenuClose') : t('navMenuOpen')}
          aria-expanded={mobileOpen}
          aria-controls="mobile-menu"
        >
          {mobileOpen
            ? <X className="w-5 h-5 text-ink-800" aria-hidden="true" />
            : <Menu className="w-5 h-5 text-ink-800" aria-hidden="true" />
          }
        </button>
      </nav>

      {mobileOpen && (
        <div
          id="mobile-menu"
          className="md:hidden fixed inset-0 top-20 bg-paper z-40 animate-fade-in overflow-y-auto"
          role="dialog"
          aria-label="Mobile Navigation"
        >
          <div className="px-6 py-12 space-y-8">
            <div className="meta-label meta-label--subtle">Navigation</div>
            <div className="space-y-5">
              {navLinks.map((link) => (
                <button
                  key={link.id}
                  onClick={() => smoothScroll(link.id)}
                  className="block w-full text-left font-display text-3xl text-ink-800 hover:text-primary-700 transition-colors"
                >
                  {link.label}
                </button>
              ))}
            </div>
            <div className="pt-6 flex items-center gap-3">
              <LanguageSwitcher />
            </div>
            <div className="pt-4 border-t border-stone-200 space-y-4">
              <button
                onClick={() => {
                  setMobileOpen(false)
                  setTimeout(() => smoothScroll('app-download'), 100)
                }}
                className="block w-full text-center py-4 rounded-full bg-primary-600 text-white text-sm font-medium tracking-wide cta-app-download"
              >
                📱 App holen
              </button>
              <Link
                href="/auth?mode=login"
                onClick={() => setMobileOpen(false)}
                className="block w-full text-center py-4 rounded-full border border-ink-800 text-ink-800 text-sm font-medium tracking-wide"
              >
                {t('navLogin')}
              </Link>
              <Link
                href="/auth?mode=register"
                onClick={() => setMobileOpen(false)}
                className="block w-full text-center py-4 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide"
              >
                {t('heroCtaPrimary')} →
              </Link>
            </div>
          </div>
        </div>
      )}
    </header>
  )
}
