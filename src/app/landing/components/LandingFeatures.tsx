'use client'

import { MapPin, HandHeart, Shield, MessageCircle, Heart, Zap } from 'lucide-react'
import { useTranslations } from 'next-intl'
import LandingSection from './LandingSection'

const ICONS = [MapPin, HandHeart, Shield, MessageCircle, Heart, Zap]

export default function LandingFeatures() {
  const t = useTranslations('landing')

  const features = [
    { Icon: ICONS[0], title: t('f1Title'), description: t('f1Desc') },
    { Icon: ICONS[1], title: t('f2Title'), description: t('f2Desc') },
    { Icon: ICONS[2], title: t('f3Title'), description: t('f3Desc') },
    { Icon: ICONS[3], title: t('f4Title'), description: t('f4Desc') },
    { Icon: ICONS[4], title: t('f5Title'), description: t('f5Desc') },
    { Icon: ICONS[5], title: t('f6Title'), description: t('f6Desc') },
  ]

  return (
    <LandingSection
      id="features"
      background="stone"
      index="03"
      label={t('featuresLabel')}
      title={t('featuresTitle')}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-16">
        {features.map((feature, i) => (
          <FeatureItem key={i} {...feature} index={i} />
        ))}
      </div>
    </LandingSection>
  )
}

function FeatureItem({
  Icon,
  title,
  description,
  index,
}: {
  Icon: React.ComponentType<{ className?: string }>
  title: string
  description: string
  index: number
}) {
  const num = String(index + 1).padStart(2, '0')
  return (
    <article className={`reveal reveal-delay-${Math.min(index + 1, 5)} border-t border-stone-300 pt-8`}>
      <div className="flex items-baseline justify-between mb-5">
        <div className="meta-label meta-label--subtle">{num}</div>
        <Icon className="w-5 h-5 text-primary-600" aria-hidden="true" />
      </div>
      <h3 className="font-display text-2xl md:text-3xl text-ink-800 leading-tight tracking-tight">
        {title}
      </h3>
      <p className="text-ink-500 text-[0.95rem] leading-relaxed mt-4 max-w-md">
        {description}
      </p>
    </article>
  )
}
