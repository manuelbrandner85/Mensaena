'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'
import DonationBadge from '@/components/landing/DonationBadge'
import { APK_DOWNLOAD_ENABLED } from '@/lib/app-download'

export default function LandingHero() {
  const t = useTranslations('landing')

  const smoothScroll = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section
      id="hero"
      className="relative min-h-dvh flex items-center bg-paper overflow-hidden"
      aria-labelledby="hero-heading"
    >
      {/* ── Cinematic atmospheric depth — layered ambient light sources ── */}
      <div className="absolute inset-0 pointer-events-none" aria-hidden="true">
        {/* Primary ambient — upper left, teal, dominant */}
        <div
          className="hero-orb-1"
          style={{
            top: '-18%',
            left: '-12%',
            width: '72vw',
            height: '72vw',
          }}
        />
        {/* Secondary ambient — upper right, trust-blue */}
        <div
          className="hero-orb-2"
          style={{
            top: '-8%',
            right: '-18%',
            width: '58vw',
            height: '58vw',
          }}
        />
        {/* Tertiary ambient — lower center, teal accent */}
        <div
          className="hero-orb-3"
          style={{
            bottom: '-12%',
            left: '22%',
            width: '46vw',
            height: '46vw',
          }}
        />
        {/* Micro accent — mid right, close depth */}
        <div
          className="absolute rounded-full pointer-events-none"
          style={{
            top: '40%',
            right: '8%',
            width: '22vw',
            height: '22vw',
            background: 'radial-gradient(circle, rgba(30,170,166,0.07) 0%, transparent 70%)',
            filter: 'blur(40px)',
            animation: 'ambientBreath2 16s ease-in-out 8s infinite',
          }}
        />
      </div>

      {/* ── Depth perspective grid ── */}
      <div
        className="absolute inset-0 depth-grid-overlay pointer-events-none"
        aria-hidden="true"
      />

      {/* ── Film grain texture ── */}
      <div className="mesh-grain absolute inset-0 pointer-events-none" aria-hidden="true" />

      {/* ── Edge vignettes for cinematic depth framing ── */}
      <div
        className="absolute inset-x-0 top-0 h-56 pointer-events-none"
        style={{ background: 'linear-gradient(to bottom, rgba(250,250,247,0.9) 0%, transparent 100%)' }}
        aria-hidden="true"
      />
      <div
        className="absolute inset-x-0 bottom-0 h-56 pointer-events-none"
        style={{ background: 'linear-gradient(to top, rgba(250,250,247,1) 0%, transparent 100%)' }}
        aria-hidden="true"
      />

      {/* ── Main content ── */}
      <div className="relative z-10 w-full max-w-7xl mx-auto px-6 md:px-10 pt-32 pb-28 md:pt-44 md:pb-36">

        {/* Meta label + donation badge */}
        <div className="reveal mb-12 flex flex-wrap items-center gap-x-5 gap-y-3">
          <span className="meta-label">{t('heroMeta')}</span>
          <DonationBadge variant="hero" />
        </div>

        {/* Main headline — cinematic display scale */}
        <h1
          id="hero-heading"
          className="reveal reveal-delay-1 display-xl max-w-[16ch] leading-[0.98]"
        >
          {t('heroHeadline')}
        </h1>

        {/* Subtext */}
        <p className="reveal reveal-delay-2 mt-10 max-w-lg text-lg md:text-xl text-ink-500 leading-relaxed">
          {t('heroText')}
        </p>

        {/* CTA buttons */}
        <div className="reveal reveal-delay-3 mt-14 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-5">
          <Link
            href="/auth?mode=register"
            className="cta-cinema-ink group inline-flex items-center gap-3 text-paper px-8 py-4 rounded-full text-sm font-medium tracking-wide"
          >
            {t('heroCtaPrimary')}
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>

          {APK_DOWNLOAD_ENABLED && (
            <button
              onClick={() => smoothScroll('app-download')}
              className="cta-cinema-teal group inline-flex items-center gap-3 text-white px-8 py-4 rounded-full text-sm font-medium tracking-wide cta-app-download"
            >
              <span aria-hidden="true">📱</span>
              App holen
              <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
            </button>
          )}

          <button
            onClick={() => smoothScroll('features')}
            className="text-sm font-medium text-ink-400 hover:text-ink-800 transition-colors duration-400 inline-flex items-center gap-2.5"
          >
            <span
              className="inline-block h-px bg-current opacity-40 transition-all duration-400 group-hover:w-10"
              style={{ width: '2rem' }}
            />
            {t('heroCtaSecondary')}
          </button>
        </div>

        {/* Hero facts — cinematic stat strip with vertical dividers */}
        <div className="reveal reveal-delay-4 mt-24 md:mt-32 grid grid-cols-1 sm:grid-cols-3 max-w-2xl border-t border-stone-200/70 pt-8">
          <HeroFact label={t('heroFactLabel1')} value={t('heroFactValue1')} />
          <HeroFact label={t('heroFactLabel2')} value={t('heroFactValue2')} />
          <HeroFact label={t('heroFactLabel3')} value={t('heroFactValue3')} last />
        </div>
      </div>

      {/* ── Cinematic scroll indicator ── */}
      <div
        className="absolute bottom-8 left-1/2 -translate-x-1/2 hidden md:flex flex-col items-center gap-2.5 text-ink-400"
        aria-hidden="true"
      >
        <span className="meta-label meta-label--subtle" style={{ fontSize: '0.62rem' }}>Scroll</span>
        <span
          className="block w-px h-12"
          style={{
            background: 'linear-gradient(to bottom, rgba(94,114,112,0.5), transparent)',
            animation: 'pulse 2.8s ease-in-out infinite',
          }}
        />
      </div>
    </section>
  )
}

function HeroFact({
  label,
  value,
  last = false,
}: {
  label: string
  value: string
  last?: boolean
}) {
  return (
    <div
      className={`hero-fact-item py-6 sm:py-0 sm:px-7 first:pl-0 last:pr-0 ${
        last ? '' : 'border-b border-stone-200/70 sm:border-b-0'
      }`}
    >
      <div className="meta-label meta-label--subtle mb-2.5">{label}</div>
      <div className="font-display text-xl md:text-2xl text-ink-800 tracking-tight">{value}</div>
    </div>
  )
}
