'use client'

import { cn } from '@/lib/design-system'
import type { MatchFilter, MatchCounts } from '../types'
import { MATCH_STATUS_LABELS } from '../types'

interface MatchFiltersProps {
  active: MatchFilter
  counts: MatchCounts
  onChange: (filter: MatchFilter) => void
}

interface FilterTab {
  value: MatchFilter
  label: string
  count?: number
}

export default function MatchFilters({ active, counts, onChange }: MatchFiltersProps) {
  const tabs: FilterTab[] = [
    { value: 'all', label: 'Alle', count: counts.suggested + counts.pending + counts.accepted },
    { value: 'suggested', label: MATCH_STATUS_LABELS.suggested, count: counts.suggested },
    { value: 'pending', label: MATCH_STATUS_LABELS.pending, count: counts.pending },
    { value: 'accepted', label: MATCH_STATUS_LABELS.accepted, count: counts.accepted },
    { value: 'completed', label: MATCH_STATUS_LABELS.completed, count: counts.completed },
  ]

  return (
    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide -mx-1 px-1">
      {tabs.map((tab) => (
        <button
          key={tab.value}
          onClick={() => onChange(tab.value)}
          className={cn(
            'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all flex-shrink-0',
            active === tab.value
              ? 'bg-indigo-100 text-indigo-700 shadow-sm'
              : 'bg-gray-50 text-gray-600 hover:bg-gray-100',
          )}
        >
          {tab.label}
          {tab.count != null && tab.count > 0 && (
            <span
              className={cn(
                'inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full text-[11px] font-semibold',
                active === tab.value
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-200 text-gray-600',
              )}
            >
              {tab.count}
            </span>
          )}
        </button>
      ))}
    </div>
  )
}
