'use client'

import { MapPin, HandHeart, Shield, MessageCircle, Heart, Zap } from 'lucide-react'
import { useTranslations } from 'next-intl'
import CinemaSection from '@/components/cinema/ui/CinemaSection'

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
    <CinemaSection
      id="features"
      index="03"
      label={t('featuresLabel')}
      title={t('featuresTitle')}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5 md:gap-6">
        {features.map((feature, i) => (
          <FeatureItem key={i} {...feature} index={i} />
        ))}
      </div>
    </CinemaSection>
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
    <article className={`reveal reveal-delay-${Math.min(index + 1, 5)}`}>
      <div className="cinema-card p-8 md:p-10 h-full flex flex-col">
        <div className="flex items-start justify-between mb-7">
          <div className="cinema-meta-label cinema-meta-label--subtle">{num}</div>
          <div className="cinema-icon-surface w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0">
            <Icon className="w-5 h-5 text-mn-amber" aria-hidden="true" />
          </div>
        </div>

        <h3
          className="leading-[1.12] tracking-tight mb-4"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontSize: 'clamp(1.25rem, 2vw, 1.65rem)',
            color: '#F5F0E8',
          }}
        >
          {title}
        </h3>

        <p className="text-[0.94rem] leading-relaxed mt-auto" style={{ color: 'rgba(245,240,232,0.50)' }}>
          {description}
        </p>
      </div>
    </article>
  )
}
