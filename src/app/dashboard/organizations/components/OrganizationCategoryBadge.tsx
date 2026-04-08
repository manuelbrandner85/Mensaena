'use client'

import { cn } from '@/lib/utils'
import { getCategoryConfig } from '../types'

interface Props {
  category: string
  size?: 'sm' | 'md'
}

export default function OrganizationCategoryBadge({ category, size = 'sm' }: Props) {
  const config = getCategoryConfig(category)
  const Icon = config.icon

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full font-medium',
        config.bg, config.color,
        size === 'sm' ? 'text-xs px-2 py-0.5' : 'text-sm px-3 py-1'
      )}
      aria-label={`Kategorie: ${config.label}`}
    >
      <Icon className={cn(size === 'sm' ? 'w-3 h-3' : 'w-4 h-4')} />
      {config.label}
    </span>
  )
}
