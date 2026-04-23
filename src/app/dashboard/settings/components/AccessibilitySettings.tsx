'use client'

import { useEffect } from 'react'
import { useTranslations } from 'next-intl'
import { Type, Contrast, Layout, Zap } from 'lucide-react'
import { useAccessibilityStore } from '@/store/useAccessibilityStore'
import { cn } from '@/lib/utils'

interface ToggleRowProps {
  icon: React.ReactNode
  label: string
  description: string
  active: boolean
  onToggle: () => void
}

function ToggleRow({ icon, label, description, active, onToggle }: ToggleRowProps) {
  return (
    <div className="flex items-center justify-between py-4 border-b border-gray-100 last:border-0">
      <div className="flex items-start gap-3">
        <div className={cn('mt-0.5 p-2 rounded-lg', active ? 'bg-primary-100 text-primary-600' : 'bg-gray-100 text-gray-400')}>
          {icon}
        </div>
        <div>
          <p className="text-sm font-medium text-gray-900">{label}</p>
          <p className="text-xs text-gray-500 mt-0.5">{description}</p>
        </div>
      </div>
      <button
        role="switch"
        aria-checked={active}
        onClick={onToggle}
        className={cn(
          'relative inline-flex h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500',
          active ? 'bg-primary-500' : 'bg-gray-200'
        )}
      >
        <span
          className={cn(
            'inline-block h-5 w-5 rounded-full bg-white shadow-sm transform transition-transform duration-200',
            active ? 'translate-x-5' : 'translate-x-0'
          )}
        />
      </button>
    </div>
  )
}

export default function AccessibilitySettings() {
  const t = useTranslations('accessibility')
  const {
    largeFont,
    highContrast,
    simplifiedView,
    reducedMotion,
    init,
    toggleLargeFont,
    toggleHighContrast,
    toggleSimplifiedView,
    toggleReducedMotion,
  } = useAccessibilityStore()

  useEffect(() => { init() }, [init])

  return (
    <div className="space-y-5">
      <div className="bg-white rounded-2xl shadow-soft border border-gray-100 p-6">
        <div className="mb-5">
          <h2 className="text-base font-semibold text-gray-900">{t('title')}</h2>
          <p className="text-sm text-gray-500 mt-1">{t('description')}</p>
        </div>

        <div>
          <ToggleRow
            icon={<Type className="w-4 h-4" />}
            label={t('largeFont')}
            description={t('largeFontDesc')}
            active={largeFont}
            onToggle={toggleLargeFont}
          />
          <ToggleRow
            icon={<Contrast className="w-4 h-4" />}
            label={t('highContrast')}
            description={t('highContrastDesc')}
            active={highContrast}
            onToggle={toggleHighContrast}
          />
          <ToggleRow
            icon={<Layout className="w-4 h-4" />}
            label={t('simplifiedView')}
            description={t('simplifiedViewDesc')}
            active={simplifiedView}
            onToggle={toggleSimplifiedView}
          />
          <ToggleRow
            icon={<Zap className="w-4 h-4" />}
            label={t('reducedMotion')}
            description={t('reducedMotionDesc')}
            active={reducedMotion}
            onToggle={toggleReducedMotion}
          />
        </div>
      </div>

      <p className="text-xs text-gray-400 px-1">
        {t('storageInfo')}
      </p>
    </div>
  )
}
