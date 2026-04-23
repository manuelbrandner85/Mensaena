'use client'

import { HandHeart, HelpCircle, Wrench, Calendar, Repeat, Car, AlertTriangle } from 'lucide-react'
import { useTranslations } from 'next-intl'
import LandingSection from './LandingSection'

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
    <LandingSection
      id="categories"
      background="stone"
      index="05"
      label={t('categoriesLabel')}
      title={t('categoriesTitle')}
    >
      <div className="divide-y divide-stone-300 border-t border-b border-stone-300">
        {categories.map((cat, i) => (
          <CategoryRow key={i} {...cat} index={i} />
        ))}
      </div>
    </LandingSection>
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
    <div className={`reveal reveal-delay-${Math.min(index + 1, 5)} group flex items-center gap-6 md:gap-12 py-8 md:py-10 transition-colors duration-500 hover:bg-paper/60`}>
      <div className="meta-label meta-label--subtle w-6 shrink-0">{num}</div>
      <Icon className="w-5 h-5 text-primary-600 shrink-0 transition-transform duration-300 group-hover:scale-110" aria-hidden="true" />
      <div className="flex-1 min-w-0">
        <div className="font-display text-xl md:text-2xl text-ink-800 tracking-tight">{label}</div>
        <div className="meta-label meta-label--subtle mt-1 truncate">{example}</div>
      </div>
    </div>
  )
}
