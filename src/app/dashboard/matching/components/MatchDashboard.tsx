'use client'

import {
  Sparkles, Clock, CheckCircle2, Trophy,
} from 'lucide-react'
import { cn } from '@/lib/design-system'
import type { MatchCounts } from '../types'

interface MatchDashboardProps {
  counts: MatchCounts
  loading?: boolean
}

const cards = [
  {
    key: 'suggested' as const,
    label: 'Vorschlaege',
    icon: Sparkles,
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    border: 'border-blue-100',
  },
  {
    key: 'pending' as const,
    label: 'Wartend',
    icon: Clock,
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-100',
  },
  {
    key: 'accepted' as const,
    label: 'Akzeptiert',
    icon: CheckCircle2,
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
    border: 'border-emerald-100',
  },
  {
    key: 'completed' as const,
    label: 'Abgeschlossen',
    icon: Trophy,
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    border: 'border-purple-100',
  },
]

export default function MatchDashboard({ counts, loading }: MatchDashboardProps) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
      {cards.map((card) => {
        const Icon = card.icon
        const value = counts[card.key]

        return (
          <div
            key={card.key}
            className={cn(
              'rounded-xl border p-3 sm:p-4 transition-all',
              loading ? 'animate-pulse' : '',
              card.bg,
              card.border,
            )}
          >
            <div className="flex items-center gap-2 mb-1">
              <Icon className={cn('w-4 h-4', card.color)} />
              <span className="text-xs font-medium text-gray-600">{card.label}</span>
            </div>
            <p className={cn('text-2xl font-bold', card.color)}>
              {loading ? '-' : value}
            </p>
          </div>
        )
      })}
    </div>
  )
}
