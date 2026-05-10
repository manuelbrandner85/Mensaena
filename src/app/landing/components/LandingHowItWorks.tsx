'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'
import CinemaSection from '@/components/cinema/ui/CinemaSection'

export default function LandingHowItWorks() {
  const t = useTranslations('landing')

  const steps = [
    { num: '01', title: t('step1Title'), description: t('step1Desc') },
    { num: '02', title: t('step2Title'), description: t('step2Desc') },
    { num: '03', title: t('step3Title'), description: t('step3Desc') },
  ]

  return (
    <CinemaSection
      id="how-it-works"
      index="04"
      label={t('howLabel')}
      title={t('howTitle')}
    >
      <ol className="grid grid-cols-1 md:grid-cols-3 gap-5 md:gap-6">
        {steps.map((step, i) => (
          <li key={step.num} className={`reveal reveal-delay-${i + 1}`}>
            <div className="cinema-card p-8 md:p-10 h-full flex flex-col">
              <div className="cinema-numeral-glow mb-6">
                <span
                  style={{
                    fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
                    fontSize: 'clamp(5.5rem, 10vw, 6.5rem)',
                    lineHeight: 1,
                    letterSpacing: '-0.04em',
                    color: 'rgba(245,158,11,0.65)',
                    display: 'block',
                  }}
                >
                  {step.num}
                </span>
              </div>

              <h3
                className="tracking-tight leading-[1.12] mb-3"
                style={{
                  fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
                  fontSize: 'clamp(1.25rem, 2vw, 1.6rem)',
                  color: '#F5F0E8',
                }}
              >
                {step.title}
              </h3>

              <p className="text-[0.94rem] leading-relaxed mt-auto" style={{ color: 'rgba(245,240,232,0.50)' }}>
                {step.description}
              </p>
            </div>
          </li>
        ))}
      </ol>

      <div className="reveal reveal-delay-4 mt-12 flex justify-start">
        <Link
          href="/auth?mode=register"
          className="cta-cinema-amber group inline-flex items-center gap-3 text-mn-void px-8 py-4 rounded-full text-sm font-medium tracking-wide"
        >
          {t('howCta')}
          <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
        </Link>
      </div>
    </CinemaSection>
  )
}
