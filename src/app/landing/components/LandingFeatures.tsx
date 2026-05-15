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
      <div
        className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
        style={{
          gap: '1px',
          background: 'rgba(199,147,99,0.10)',
          border: '1px solid rgba(199,147,99,0.10)',
        }}
      >
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
    <article
      className={`reveal reveal-delay-${Math.min(index + 1, 5)} flex flex-col justify-between p-10 md:p-11 min-h-[320px] transition-colors duration-300`}
      style={{ background: 'linear-gradient(180deg, rgba(13,26,41,0.55), rgba(7,13,22,0.55))' }}
    >
      <div className="flex items-start justify-between mb-14">
        <div className="cinema-meta-label cinema-meta-label--subtle">{num}</div>
        <span
          aria-hidden="true"
          className="w-2 h-2 rounded-full"
          style={{ background: '#c79363', boxShadow: '0 0 12px rgba(199,147,99,0.5)' }}
        />
      </div>

      <div>
        <h3
          className="leading-[1.06] tracking-tight mb-4"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontSize: 'clamp(1.35rem, 2.2vw, 1.9rem)',
            color: '#ece5d6',
            fontWeight: 400,
          }}
        >
          {title}
        </h3>

        <p className="text-[0.875rem] leading-relaxed" style={{ color: 'rgba(205,196,177,0.70)', maxWidth: '34ch' }}>
          {description}
        </p>
      </div>
    </article>
  )
}
