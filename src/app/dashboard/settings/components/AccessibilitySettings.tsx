'use client'

import { useEffect } from 'react'
import { useTranslations } from 'next-intl'
import { Eye, Type, Zap, MonitorOff, Palette } from 'lucide-react'
import { useAccessibilityStore } from '@/store/useAccessibilityStore'
import { cn } from '@/lib/utils'
import { Toggle, Card } from '@/components/ui'
import ThemeToggle from '@/components/ui/ThemeToggle'

export default function AccessibilitySettings() {
  const t = useTranslations('accessibility')
  const store = useAccessibilityStore()

  useEffect(() => { store.init() }, [store.init])

  const settings = [
    { key: 'largeFont',      label: t('largeFont'),      desc: t('largeFontDesc'),      icon: Type,       toggle: store.toggleLargeFont,      active: store.largeFont },
    { key: 'highContrast',   label: t('highContrast'),   desc: t('highContrastDesc'),   icon: Eye,        toggle: store.toggleHighContrast,   active: store.highContrast },
    { key: 'simplifiedView', label: t('simplifiedView'), desc: t('simplifiedViewDesc'), icon: Zap,        toggle: store.toggleSimplifiedView, active: store.simplifiedView },
    { key: 'reducedMotion',  label: t('reducedMotion'),  desc: t('reducedMotionDesc'),  icon: MonitorOff, toggle: store.toggleReducedMotion,  active: store.reducedMotion },
  ]

  return (
    <div className="space-y-3">
      {/* Dark Mode / Farbschema */}
      <Card variant="flat">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-start gap-3">
            <div className="p-2 rounded-lg flex-shrink-0 mt-0.5 bg-stone-100 text-ink-400">
              <Palette className="w-4 h-4" />
            </div>
            <div>
              <p className="text-sm font-medium text-ink-900 dark:text-stone-100">Farbschema</p>
              <p className="text-xs text-ink-500 dark:text-stone-400 mt-0.5">Hell, Dunkel oder automatisch nach Geräte-Einstellung</p>
            </div>
          </div>
          <ThemeToggle showLabels />
        </div>
      </Card>

      {settings.map(({ key, label, desc, icon: Icon, toggle, active }) => (
        <Card
          key={key}
          variant="flat"
          className={cn(
            'transition-colors duration-150',
            active ? 'ring-2 ring-primary-500 bg-primary-50/40' : ''
          )}
        >
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-start gap-3">
              <div className={cn(
                'p-2 rounded-lg flex-shrink-0 mt-0.5',
                active ? 'bg-primary-100 text-primary-600' : 'bg-stone-100 text-ink-400'
              )}>
                <Icon className="w-4 h-4" />
              </div>
              <div>
                <p className="text-sm font-medium text-ink-900">{label}</p>
                <p className="text-xs text-ink-500 mt-0.5">{desc}</p>
              </div>
            </div>
            <Toggle checked={active} onChange={() => toggle()} size="md" />
          </div>
        </Card>
      ))}

      <p className="text-xs text-ink-400 px-1">{t('storageInfo')}</p>
    </div>
  )
}
