'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'

export default function LandingCTA() {
  const t = useTranslations('landing')

  return (
    <section
      id="cta"
      className="cinema-section relative overflow-hidden py-36 md:py-52 px-6 md:px-10 scroll-mt-24"
      aria-labelledby="cta-heading"
    >
      {/* Amber ambient orb */}
      <div
        className="absolute rounded-full pointer-events-none"
        style={{
          top: '-20%', left: '-10%', width: '65vw', height: '65vw',
          background: 'radial-gradient(circle, rgba(199,147,99,0.22) 0%, rgba(199,147,99,0.07) 40%, transparent 70%)',
          filter: 'blur(95px)',
          animation: 'breathe 22s ease-in-out infinite',
        }}
        aria-hidden="true"
      />
      <div
        className="absolute rounded-full pointer-events-none"
        style={{
          bottom: '-15%', right: '-15%', width: '55vw', height: '55vw',
          background: 'radial-gradient(circle, rgba(43,86,99,0.10) 0%, transparent 70%)',
          filter: 'blur(110px)',
          animation: 'breathe 28s ease-in-out 6s infinite',
        }}
        aria-hidden="true"
      />
      {/* Amber depth grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-25"
        style={{
          backgroundImage:
            'linear-gradient(rgba(199,147,99,0.07) 1px, transparent 1px), linear-gradient(90deg, rgba(199,147,99,0.07) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
          maskImage: 'radial-gradient(ellipse 70% 60% at 50% 50%, rgba(0,0,0,0.5) 20%, transparent 80%)',
          WebkitMaskImage: 'radial-gradient(ellipse 70% 60% at 50% 50%, rgba(0,0,0,0.5) 20%, transparent 80%)',
        }}
        aria-hidden="true"
      />

      <div className="relative z-10 max-w-5xl mx-auto">
        <div className="reveal cinema-meta-label mb-10">{t('ctaMeta')}</div>

        <h2
          id="cta-heading"
          className="reveal reveal-delay-1 max-w-4xl"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontWeight: 400,
            fontSize: 'clamp(2.75rem, 7vw, 5.75rem)',
            lineHeight: 1.02,
            letterSpacing: '-0.035em',
            color: '#ece5d6',
          }}
        >
          {t('ctaTitle')}
        </h2>

        <p
          className="reveal reveal-delay-2 mt-10 max-w-xl text-lg md:text-xl leading-relaxed"
          style={{ color: 'rgba(236,229,214,0.50)' }}
        >
          {t('ctaText')}
        </p>

        <div className="reveal reveal-delay-3 mt-14 flex flex-col sm:flex-row items-start sm:items-center gap-5">
          <Link
            href="/auth?mode=register"
            className="cta-cinema-amber group inline-flex items-center gap-3 text-mn-void px-8 py-4 rounded-full text-sm font-medium tracking-wide"
          >
            {t('ctaButton')}
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>

          <Link
            href="/auth?mode=login"
            className="cinema-meta-label cinema-meta-label--subtle hover:opacity-70 transition-opacity duration-300"
          >
            {t('ctaLogin')}
          </Link>
        </div>
      </div>
    </section>
  )
}
