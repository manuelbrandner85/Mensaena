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
      <ol className="grid grid-cols-1 md:grid-cols-3 gap-12 md:gap-16">
        {steps.map((step, i) => (
          <li key={step.num} className={`reveal reveal-delay-${i + 1} border-t border-stone-300 pt-8`}>
            <div className="font-display text-7xl md:text-8xl text-primary-500 leading-none tracking-tight">
              {step.num}
            </div>
            <h3 className="font-display text-2xl text-ink-800 mt-8 tracking-tight">
              {step.title}
            </h3>
            <p className="text-ink-500 text-[0.95rem] leading-relaxed mt-3 max-w-sm">
              {step.description}
            </p>
          </li>
        ))}
      </ol>

      <div className="reveal reveal-delay-4 mt-20 flex justify-start">
        <Link
          href="/auth?mode=register"
          className="group inline-flex items-center gap-3 bg-ink-800 hover:bg-ink-700 text-paper px-8 py-4 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
        >
          {t('howCta')}
          <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
        </Link>
      </div>
    </LandingSection>
  )
}
