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
    <footer className="relative overflow-hidden safe-area-bottom" style={{ background: '#060A14' }} role="contentinfo">
      {/* Amber top edge */}
      <div className="absolute inset-x-0 top-0 pointer-events-none" aria-hidden="true">
        <div className="h-px" style={{ background: 'linear-gradient(to right, transparent, rgba(199,147,99,0.35), transparent)' }} />
        <div className="h-40" style={{ background: 'linear-gradient(to bottom, rgba(199,147,99,0.04) 0%, transparent 100%)' }} />
      </div>
      {/* Ambient orbs */}
      <div className="absolute rounded-full pointer-events-none" style={{ top: '-5%', right: '-10%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(199,147,99,0.08) 0%, transparent 70%)', filter: 'blur(90px)' }} aria-hidden="true" />
      <div className="absolute rounded-full pointer-events-none" style={{ bottom: '15%', left: '-8%', width: '35vw', height: '35vw', background: 'radial-gradient(circle, rgba(43,86,99,0.05) 0%, transparent 70%)', filter: 'blur(80px)' }} aria-hidden="true" />

      <div className="max-w-7xl mx-auto px-6 md:px-10 pt-24 md:pt-32">
        <div className="flex items-center gap-4 mb-8">
          <Image src="/mensaena-logo.png" alt="Mensaena Logo" width={96} height={64} className="h-16 w-auto object-contain opacity-80" />
          <div className="cinema-meta-label cinema-meta-label--subtle">Mensaena</div>
        </div>
        <div
          className="select-none whitespace-nowrap leading-[0.82] tracking-[-0.04em]"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontWeight: 400,
            fontSize: 'clamp(4.5rem, 18vw, 17rem)',
            color: '#ece5d6',
          }}
        >
          Mensaena<span style={{ color: 'rgba(199,147,99,0.70)' }}>.</span>
        </div>
        <p
          className="mt-10 max-w-xl text-xl md:text-2xl leading-snug"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            color: 'rgba(236,229,214,0.75)',
          }}
        >
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
          <div className="cinema-meta-label cinema-meta-label--subtle mb-5">{t('footerFollowUs')}</div>
          <SocialMediaButtons variant="dark" compact />
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-24 pt-8" style={{ borderTop: '1px solid rgba(236,229,214,0.08)' }}>
        <Link
          href="/spenden"
          className="group inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[11px] font-medium tracking-wide transition-colors duration-300"
          style={{ border: '1px solid rgba(199,147,99,0.20)', color: 'rgba(236,229,214,0.75)', background: 'rgba(199,147,99,0.04)' }}
        >
          <Heart className="h-3 w-3 transition-transform duration-300 group-hover:scale-110" style={{ fill: 'rgba(199,147,99,0.30)', color: 'rgba(199,147,99,0.70)' }} aria-hidden="true" />
          <span>Werbefrei dank Spender:innen — Mensaena unterstützen</span>
        </Link>
      </div>

      <div className="max-w-7xl mx-auto px-6 md:px-10 mt-6 pb-10 pt-6" style={{ borderTop: '1px solid rgba(236,229,214,0.06)' }}>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <p className="text-xs" style={{ color: 'rgba(236,229,214,0.50)' }}>
            © {new Date().getFullYear()} Mensaena · {t('footerCopyright')}
          </p>
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="cinema-meta-label cinema-meta-label--subtle hover:opacity-60 transition-opacity duration-300"
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
