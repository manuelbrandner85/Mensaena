'use client'

import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'
import LandingSection from './LandingSection'

export default function LandingHowItWorks() {
  const t = useTranslations('landing')

  const steps = [
    { num: '01', title: t('step1Title'), description: t('step1Desc') },
    { num: '02', title: t('step2Title'), description: t('step2Desc') },
    { num: '03', title: t('step3Title'), description: t('step3Desc') },
  ]

  return (
    <LandingSection
      id="how-it-works"
      background="paper"
      index="04"
      label={t('howLabel')}
      title={t('howTitle')}
    >
      <ol className="grid grid-cols-1 md:grid-cols-3 gap-5 md:gap-6">
        {steps.map((step, i) => (
          <li key={step.num} className={`reveal reveal-delay-${i + 1}`}>
            <div className="card-depth p-8 md:p-10 h-full flex flex-col">
              {/* Large cinematic step number */}
              <div className="numeral-glow mb-6">
                <span
                  className="font-display text-[5.5rem] md:text-[6.5rem] text-primary-500 leading-none tracking-[-0.04em]"
                  style={{
                    textShadow: '0 0 48px rgba(30,170,166,0.22)',
                  }}
                >
                  {step.num}
                </span>
              </div>

              {/* Step title */}
              <h3 className="font-display text-2xl md:text-[1.6rem] text-ink-800 tracking-tight leading-[1.12] mb-3">
                {step.title}
              </h3>

              {/* Step description */}
              <p className="text-ink-500 text-[0.94rem] leading-relaxed mt-auto">
                {step.description}
              </p>
            </div>
          </li>
        ))}
      </ol>

      <div className="reveal reveal-delay-4 mt-12 flex justify-start">
        <Link
          href="/auth?mode=register"
          className="cta-cinema-ink group inline-flex items-center gap-3 text-paper px-8 py-4 rounded-full text-sm font-medium tracking-wide"
        >
          {t('howCta')}
          <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
        </Link>
      </div>
    </LandingSection>
  )
}
