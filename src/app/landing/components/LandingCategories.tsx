'use client'

import { HandHeart, HelpCircle, Wrench, Calendar, Repeat, Car, AlertTriangle } from 'lucide-react'
import { useTranslations } from 'next-intl'
import CinemaSection from '@/components/cinema/ui/CinemaSection'

const ICONS = [HandHeart, HelpCircle, Wrench, Calendar, Repeat, Car, AlertTriangle]

export default function LandingCategories() {
  const t = useTranslations('landing')

  const categories = [
    { Icon: ICONS[0], label: t('cat1Label'), example: t('cat1Example') },
    { Icon: ICONS[1], label: t('cat2Label'), example: t('cat2Example') },
    { Icon: ICONS[2], label: t('cat3Label'), example: t('cat3Example') },
    { Icon: ICONS[3], label: t('cat4Label'), example: t('cat4Example') },
    { Icon: ICONS[4], label: t('cat5Label'), example: t('cat5Example') },
    { Icon: ICONS[5], label: t('cat6Label'), example: t('cat6Example') },
    { Icon: ICONS[6], label: t('cat7Label'), example: t('cat7Example') },
  ]

  return (
    <CinemaSection
      id="categories"
      index="05"
      label={t('categoriesLabel')}
      title={t('categoriesTitle')}
    >
      <div
        className="divide-y"
        style={{
          borderTop: '1px solid rgba(199,147,99,0.15)',
          borderBottom: '1px solid rgba(199,147,99,0.15)',
        }}
      >
        {categories.map((cat, i) => (
          <CategoryRow key={i} {...cat} index={i} />
        ))}
      </div>
    </CinemaSection>
  )
}

function CategoryRow({
  Icon,
  label,
  example,
  index,
}: {
  Icon: React.ComponentType<{ className?: string }>
  label: string
  example: string
  index: number
}) {
  const num = String(index + 1).padStart(2, '0')
  return (
    <div
      className={`reveal reveal-delay-${Math.min(index + 1, 5)} cinema-category-row group flex items-center gap-6 md:gap-12 py-9 md:py-11 pl-4`}
      style={{ borderColor: 'rgba(199,147,99,0.10)' }}
    >
      <div className="cinema-meta-label cinema-meta-label--subtle w-6 shrink-0">{num}</div>
      <div className="cinema-icon-surface w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-transform duration-300 group-hover:scale-110">
        <Icon className="w-4 h-4 text-mn-bronze" aria-hidden="true" />
      </div>
      <div className="flex-1 min-w-0">
        <div
          className="tracking-tight transition-colors duration-300"
          style={{
            fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
            fontSize: 'clamp(1.1rem, 2vw, 1.5rem)',
            color: '#ece5d6',
          }}
        >
          {label}
        </div>
        <div className="cinema-meta-label cinema-meta-label--subtle mt-1.5 truncate">{example}</div>
      </div>
      <div className="mr-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300" aria-hidden="true">
        <span style={{ color: 'rgba(199,147,99,0.65)', fontSize: '1.1rem' }}>→</span>
      </div>
    </div>
  )
}
