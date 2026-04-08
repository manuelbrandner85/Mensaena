'use client'

import { cn } from '@/lib/utils'
import { CRISIS_CATEGORY_CONFIG, type CrisisCategory } from '../types'

interface Props {
  category: CrisisCategory
  size?: 'sm' | 'md'
  showIcon?: boolean
}

export default function CrisisCategoryBadge({ category, size = 'sm', showIcon = true }: Props) {
  const cfg = CRISIS_CATEGORY_CONFIG[category]
  if (!cfg) return null
  const Icon = cfg.icon

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full font-medium border',
        cfg.bgColor, cfg.color, cfg.borderColor,
        size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1 text-sm',
      )}
      aria-label={`Kategorie: ${cfg.label}`}
    >
      {showIcon && <Icon className={size === 'sm' ? 'w-3 h-3' : 'w-4 h-4'} />}
      <span>{cfg.emoji}</span>
      {cfg.label}
    </span>
  )
}
