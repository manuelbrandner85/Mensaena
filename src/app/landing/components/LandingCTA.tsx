'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'

export default function LandingCTA() {
  const t = useTranslations('landing')

  return (
    <section
      id="cta"
      className="relative bg-ink-900 text-stone-100 overflow-hidden py-36 md:py-52 px-6 md:px-10 scroll-mt-24"
      aria-labelledby="cta-heading"
    >
      {/* ── Cinematic atmospheric orbs — triple layered depth ── */}
      <div
        className="cta-orb-1"
        style={{
          top: '-20%',
          left: '-10%',
          width: '65vw',
          height: '65vw',
        }}
        aria-hidden="true"
      />
      <div
        className="cta-orb-2"
        style={{
          bottom: '-15%',
          right: '-15%',
          width: '55vw',
          height: '55vw',
        }}
        aria-hidden="true"
      />
      <div
        className="cta-orb-3"
        style={{
          top: '30%',
          left: '40%',
          width: '40vw',
          height: '40vw',
        }}
        aria-hidden="true"
      />
      {/* Micro accent orb */}
      <div
        className="absolute rounded-full pointer-events-none"
        style={{
          bottom: '10%',
          left: '15%',
          width: '18vw',
          height: '18vw',
          background: 'radial-gradient(circle, rgba(30,170,166,0.18) 0%, transparent 70%)',
          filter: 'blur(50px)',
          animation: 'ambientBreath1 14s ease-in-out 6s infinite',
        }}
        aria-hidden="true"
      />

      {/* ── Top edge light refraction ── */}
      <div
        className="absolute inset-x-0 top-0 pointer-events-none"
        aria-hidden="true"
      >
        <div
          className="h-px"
          style={{
            background: 'linear-gradient(90deg, transparent 0%, rgba(30,170,166,0.15) 20%, rgba(30,170,166,0.45) 50%, rgba(30,170,166,0.15) 80%, transparent 100%)',
          }}
        />
        <div
          className="h-32"
          style={{
            background: 'linear-gradient(to bottom, rgba(30,170,166,0.04) 0%, transparent 100%)',
          }}
        />
      </div>

      {/* ── Depth grid overlay ── */}
      <div
        className="absolute inset-0 pointer-events-none opacity-30"
        style={{
          backgroundImage:
            'linear-gradient(rgba(30,170,166,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(30,170,166,0.06) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
          maskImage:
            'radial-gradient(ellipse 70% 60% at 50% 50%, rgba(0,0,0,0.5) 20%, transparent 80%)',
          WebkitMaskImage:
            'radial-gradient(ellipse 70% 60% at 50% 50%, rgba(0,0,0,0.5) 20%, transparent 80%)',
        }}
        aria-hidden="true"
      />

      {/* ── Content ── */}
      <div className="relative z-10 max-w-5xl mx-auto">
        {/* Meta label */}
        <div className="reveal meta-label mb-10 text-primary-400">{t('ctaMeta')}</div>

        {/* Headline */}
        <h2
          id="cta-heading"
          className="reveal reveal-delay-1 display-xl !text-stone-100 max-w-4xl leading-[0.98]"
        >
          {t('ctaTitle')}
        </h2>

        {/* Sub text */}
        <p className="reveal reveal-delay-2 mt-10 max-w-xl text-lg md:text-xl text-stone-400 leading-relaxed">
          {t('ctaText')}
        </p>

        {/* CTAs */}
        <div className="reveal reveal-delay-3 mt-14 flex flex-col sm:flex-row items-start sm:items-center gap-5">
          <Link
            href="/auth?mode=register"
            className="cta-cinema-paper group inline-flex items-center gap-3 text-ink-800 px-8 py-4 rounded-full text-sm font-medium tracking-wide"
          >
            {t('ctaButton')}
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>

          <Link
            href="/auth?mode=login"
            className="meta-label text-stone-500 hover:text-primary-400 transition-colors duration-300"
          >
            {t('ctaLogin')}
          </Link>
        </div>
      </div>
    </section>
  )
}
