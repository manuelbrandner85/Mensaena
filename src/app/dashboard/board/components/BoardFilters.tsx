'use client'

import { cn } from '@/lib/utils'
import type { BoardCategory } from '../hooks/useBoard'
import { CATEGORY_LABELS, CATEGORY_ICONS } from '../hooks/useBoard'

interface BoardFiltersProps {
  value: BoardCategory | 'all'
  onChange: (cat: BoardCategory | 'all') => void
}

const CATEGORIES: (BoardCategory | 'all')[] = [
  'all',
  'general',
  'gesucht',
  'biete',
  'event',
  'info',
  'warnung',
  'verloren',
  'fundbuero',
]

export default function BoardFilters({ value, onChange }: BoardFiltersProps) {
  return (
    <div className="flex flex-wrap gap-2">
      {CATEGORIES.map((cat) => {
        const isActive = value === cat
        const label = cat === 'all' ? 'Alle' : CATEGORY_LABELS[cat]
        const icon = cat === 'all' ? '🏷️' : CATEGORY_ICONS[cat]
        return (
          <button
            key={cat}
            type="button"
            onClick={() => onChange(cat)}
            className={cn(
              'inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm font-medium transition-all',
              isActive
                ? 'bg-mn-bronze text-white shadow-sm'
                : 'bg-mn-elevated text-mn-ink-soft border border-white/5 hover:bg-mn-surface hover:border-white/8',
            )}
          >
            <span>{icon}</span>
            <span>{label}</span>
          </button>
        )
      })}
    </div>
  )
}
