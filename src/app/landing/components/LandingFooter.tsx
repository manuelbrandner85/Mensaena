'use client'

import Link from 'next/link'
import Image from 'next/image'
import { Heart } from 'lucide-react'
import { useTranslations } from 'next-intl'
import SocialMediaButtons from '@/components/layout/SocialMediaButtons'
import { APK_DOWNLOAD_ENABLED } from '@/lib/app-download'

const legalLinks = [
  { href: '/agb',                  label: 'AGB' },
  { href: '/nutzungsbedingungen',  label: 'Nutzungsbedingungen' },
  { href: '/datenschutz',          label: 'Datenschutz' },
  { href: '/impressum',            label: 'Impressum' },
  { href: '/haftungsausschluss',   label: 'Haftungsausschluss' },
  { href: '/community-guidelines', label: 'Community-Richtlinien' },
  { href: '/kontakt',              label: 'Kontakt' },
]

export default function LandingFooter() {
  const t = useTranslations('landing')

  const platformLinks = [
    { href: '#features',     label: t('navFeatures'),    scroll: true },
    { href: '#how-it-works', label: t('navHowItWorks'),  scroll: true },
    { href: '#categories',   label: t('navCategories'),  scroll: true },
    { href: '#map',          label: t('navMap'),         scroll: true },
    ...(APK_DOWNLOAD_ENABLED
      ? [{ href: '#app-download', label: 'App holen', scroll: true }]
      : []),
    { href: '/spenden',      label: 'Spenden',           scroll: false },
  ]

  const contactLinks = [
    { href: 'mailto:info@mensaena.de',                    label: 'info@mensaena.de' },
    { href: 'mailto:info@mensaena.de?subject=Feedback',   label: t('footerFeedback') },
    { href: 'mailto:info@mensaena.de?subject=Bug-Report', label: t('footerBugReport') },
  ]

  const smoothScroll = (id: string) => {
    document.getElementById(id.replace('#', ''))?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <footer className="relative bg-ink-900 text-stone-300 overflow-hidden" role="contentinfo">
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary-500/40 to-transparent" aria-hidden="true" />

      <div className="max-w-7xl mx-auto px-6 md:px-10 pt-24 md:pt-32">
        <div className="flex items-center gap-4 mb-8">
          <Image src="/mensaena-logo.png" alt="Mensaena Logo" width={96} height={64} className="h-16 w-auto object-contain opacity-95" />
          <div className="meta-label meta-label--subtle opacity-80">Mensaena</div>
        </div>
        <div
          className="font-display font-medium leading-[0.82] tracking-[-0.04em] text-stone-100 select-none whitespace-nowrap"
          style={{ fontSize: 'clamp(4.5rem, 18vw, 17rem)' }}
        >
          Mensaena<span className="text-primary-500">.</span>
        </div>
        <p className="mt-10 max-w-xl font-display text-xl md:text-2xl text-stone-300/90 leading-snug">
          {t('footerTagline')}
        </p>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-24 md:mt-32 grid grid-cols-2 md:grid-cols-4 gap-10 md:gap-16">
        <FooterColumn label={t('footerPlatform')}>
          {platformLinks.map((link) => (
            <li key={link.href}>
              {link.scroll ? (
                <button onClick={() => smoothScroll(link.href)} className="footer-link">{link.label}</button>
              ) : (
                <Link href={link.href} className="footer-link">{link.label}</Link>
              )}
            </li>
          ))}
        </FooterColumn>

        <FooterColumn label={t('footerLegal')}>
          {legalLinks.map((link) => (
            <li key={link.href}>
              <Link href={link.href} className="footer-link">{link.label}</Link>
            </li>
          ))}
        </FooterColumn>

        <FooterColumn label={t('footerContact')}>
          {contactLinks.map((link) => (
            <li key={link.href}>
              <a href={link.href} className="footer-link">{link.label}</a>
            </li>
          ))}
        </FooterColumn>

        <div>
          <div className="meta-label meta-label--subtle mb-5 opacity-80">{t('footerFollowUs')}</div>
          <SocialMediaButtons variant="dark" compact />
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-24 pt-8 border-t border-stone-800">
        <Link
          href="/spenden"
          className="group inline-flex items-center gap-2 rounded-full border border-stone-700 bg-stone-900/40 px-3.5 py-1.5 text-[11px] font-medium tracking-wide text-stone-300 transition-colors duration-300 hover:border-primary-500/40 hover:bg-stone-900 hover:text-primary-300"
        >
          <Heart className="h-3 w-3 fill-primary-500/40 text-primary-400 transition-transform duration-300 group-hover:scale-110" aria-hidden="true" />
          <span>Werbefrei dank Spender:innen — Mensaena unterstützen</span>
        </Link>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-6 pb-10 pt-6 border-t border-stone-800">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <p className="text-xs text-stone-500">
            © {new Date().getFullYear()} Mensaena · {t('footerCopyright')}
          </p>
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="meta-label meta-label--subtle hover:text-primary-400 transition-colors duration-300"
            aria-label="Nach oben scrollen"
          >
            ↑
          </button>
        </div>
      </div>
    </footer>
  )
}

function FooterColumn({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="meta-label meta-label--subtle mb-5 opacity-80">{label}</div>
      <ul className="space-y-3">{children}</ul>
    </div>
  )
}
