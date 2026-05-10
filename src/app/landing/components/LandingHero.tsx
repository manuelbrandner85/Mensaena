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
      className="relative min-h-dvh flex items-center overflow-hidden"
      aria-labelledby="hero-heading"
    >
      {/* ── Cinematic spotlight bloom — large warm amber behind headline ── */}
      <div
        className="absolute pointer-events-none rounded-full"
        aria-hidden="true"
        style={{
          top: '15%',
          left: '5%',
          width: '70vw',
          height: '70vw',
          maxWidth: '900px',
          maxHeight: '900px',
          background:
            'radial-gradient(circle, rgba(245,158,11,0.18) 0%, rgba(245,158,11,0.08) 30%, transparent 65%)',
          filter: 'blur(60px)',
          animation: 'ambientBreath1 32s ease-in-out infinite',
          zIndex: 0,
        }}
      />
      {/* ── Cool teal counter-balance bloom (lower-right) ── */}
      <div
        className="absolute pointer-events-none rounded-full"
        aria-hidden="true"
        style={{
          bottom: '-15%',
          right: '-5%',
          width: '60vw',
          height: '60vw',
          maxWidth: '800px',
          maxHeight: '800px',
          background:
            'radial-gradient(circle, rgba(125,211,252,0.12) 0%, rgba(125,211,252,0.04) 35%, transparent 70%)',
          filter: 'blur(80px)',
          animation: 'ambientBreath2 38s ease-in-out 6s infinite',
          zIndex: 0,
        }}
      />
      {/* Depth grid overlay — amber tint */}
      <div
        className="absolute inset-0 pointer-events-none opacity-25"
        aria-hidden="true"
        style={{
          backgroundImage:
            'linear-gradient(rgba(245,158,11,0.08) 1px, transparent 1px), linear-gradient(90deg, rgba(245,158,11,0.08) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
          maskImage:
            'radial-gradient(ellipse 75% 65% at 30% 42%, rgba(0,0,0,0.6) 15%, rgba(0,0,0,0.18) 55%, transparent 100%)',
          WebkitMaskImage:
            'radial-gradient(ellipse 75% 65% at 30% 42%, rgba(0,0,0,0.6) 15%, rgba(0,0,0,0.18) 55%, transparent 100%)',
        }}
      />
      {/* ── Floating firefly particles ── */}
      <div className="absolute inset-0 pointer-events-none z-0 overflow-hidden" aria-hidden="true">
        {[
          { top: '22%', left: '12%', delay: '0s',  size: 3 },
          { top: '35%', left: '78%', delay: '2s',  size: 2 },
          { top: '58%', left: '24%', delay: '4s',  size: 4 },
          { top: '72%', left: '62%', delay: '1s',  size: 2 },
          { top: '45%', left: '88%', delay: '3.5s', size: 3 },
          { top: '18%', left: '52%', delay: '5s',  size: 2 },
        ].map((f, i) => (
          <div
            key={i}
            className="absolute rounded-full"
            style={{
              top: f.top,
              left: f.left,
              width: f.size,
              height: f.size,
              background: '#FBBF24',
              boxShadow: `0 0 ${f.size * 4}px rgba(251,191,36,0.85), 0 0 ${f.size * 8}px rgba(251,191,36,0.40)`,
              animation: `firefly 8s ease-in-out ${f.delay} infinite`,
            }}
          />
        ))}
      </div>

      {/* Bottom edge fade into next section */}
      <div
        className="absolute inset-x-0 bottom-0 h-40 pointer-events-none"
        style={{ background: 'linear-gradient(to top, #0A0F1C, transparent)' }}
        aria-hidden="true"
      />

      {/* ── Main content ── */}
      <div className="relative z-10 w-full max-w-7xl mx-auto px-6 md:px-10 pt-32 pb-28 md:pt-44 md:pb-36">

        {/* Meta label + donation badge */}
        <div className="reveal mb-12 flex flex-wrap items-center gap-x-5 gap-y-3">
          <span className="cinema-meta-label">{t('heroMeta')}</span>
          <DonationBadge variant="hero" />
        </div>

        {/* Main headline */}
        <h1
          id="hero-heading"
          className="reveal reveal-delay-1 max-w-[16ch] leading-[0.98]"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontWeight: 400,
            fontSize: 'clamp(2.75rem, 7vw, 5.75rem)',
            lineHeight: 1.02,
            letterSpacing: '-0.035em',
            color: '#F5F0E8',
          }}
        >
          {t('heroHeadline')}
        </h1>

        {/* Subtext */}
        <p className="reveal reveal-delay-2 mt-10 max-w-lg text-lg md:text-xl leading-relaxed"
          style={{ color: 'rgba(245,240,232,0.82)' }}>
          {t('heroText')}
        </p>

        {/* CTA buttons */}
        <div className="reveal reveal-delay-3 mt-14 flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-5">
          <Link
            href="/auth?mode=register"
            className="cta-cinema-amber group inline-flex items-center gap-3 text-mn-void px-8 py-4 rounded-full text-sm font-medium tracking-wide focus:outline-none focus-visible:ring-2 focus-visible:ring-mn-amber focus-visible:ring-offset-2 focus-visible:ring-offset-mn-void"
          >
            {t('heroCtaPrimary')}
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>

          {APK_DOWNLOAD_ENABLED && (
            <button
              onClick={() => smoothScroll('app-download')}
              className="cta-cinema-ghost group inline-flex items-center gap-3 px-8 py-4 rounded-full text-sm font-medium tracking-wide focus:outline-none focus-visible:ring-2 focus-visible:ring-mn-amber focus-visible:ring-offset-2 focus-visible:ring-offset-mn-void"
            >
              <span aria-hidden="true">📱</span>
              App holen
              <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
            </button>
          )}

          <button
            onClick={() => smoothScroll('features')}
            className="text-sm font-medium transition-colors duration-400 inline-flex items-center gap-2.5 hover:text-mn-amber focus:outline-none focus-visible:text-mn-amber rounded"
            style={{ color: 'rgba(245,240,232,0.65)' }}
          >
            <span
              className="inline-block h-px bg-current opacity-40"
              style={{ width: '2rem' }}
            />
            {t('heroCtaSecondary')}
          </button>
        </div>

        {/* Hero stats strip */}
        <div className="reveal reveal-delay-4 mt-24 md:mt-32 grid grid-cols-1 sm:grid-cols-3 max-w-2xl border-t pt-8"
          style={{ borderColor: 'rgba(245,158,11,0.15)' }}>
          <HeroFact label={t('heroFactLabel1')} value={t('heroFactValue1')} />
          <HeroFact label={t('heroFactLabel2')} value={t('heroFactValue2')} />
          <HeroFact label={t('heroFactLabel3')} value={t('heroFactValue3')} last />
        </div>
      </div>

      {/* Cinematic scroll indicator */}
      <div
        className="absolute bottom-8 left-1/2 -translate-x-1/2 hidden md:flex flex-col items-center gap-2.5"
        aria-hidden="true"
        style={{ color: 'rgba(245,240,232,0.50)' }}
      >
        <span
          className="font-mono text-[0.62rem] tracking-[0.22em] uppercase"
        >Scroll</span>
        <span
          className="block w-px h-12"
          style={{
            background: 'linear-gradient(to bottom, rgba(245,158,11,0.45), transparent)',
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
    <div className={`cinema-hero-fact-item py-6 sm:py-0 sm:px-7 first:pl-0 last:pr-0 ${last ? '' : 'border-b sm:border-b-0'}`}
      style={{ borderColor: 'rgba(245,158,11,0.12)' }}
    >
      <div className="cinema-meta-label cinema-meta-label--subtle mb-2.5">{label}</div>
      <div
        style={{
          fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
          fontSize: 'clamp(1.25rem, 2vw, 1.5rem)',
          color: '#F5F0E8',
          letterSpacing: '-0.02em',
        }}
      >{value}</div>
    </div>
  )
}
