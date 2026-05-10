'use client'

import { Siren, Users, CheckCircle2, Clock, TrendingUp, AlertTriangle } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { CrisisStats } from '../types'

interface Props {
  stats: CrisisStats | null
  loading: boolean
}

export default function CrisisDashboard({ stats, loading }: Props) {
  if (loading) {
    return (
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[0, 1, 2, 3].map(i => (
          <div key={i} className="h-24 rounded-2xl animate-pulse bg-mn-elevated border border-white/5" />
        ))}
      </div>
    )
  }

  if (!stats) return null

  const cards = [
    {
      label: 'Aktive Krisen',
      value: stats.active_count,
      icon: Siren,
      bg: 'bg-mn-surface',
      border: 'border-mn-herzrot/20',
      text: 'text-mn-herzrot',
      iconBg: 'bg-mn-elevated',
      pulse: stats.active_count > 0,
    },
    {
      label: 'Aktive Helfer',
      value: stats.total_active_helpers,
      icon: Users,
      bg: 'bg-mn-amber/5',
      border: 'border-mn-amber/20',
      text: 'text-mn-amber',
      iconBg: 'bg-mn-amber/10',
    },
    {
      label: 'Gelöst (30 Tage)',
      value: stats.resolved_last_30_days,
      icon: CheckCircle2,
      bg: 'bg-mn-surface',
      border: 'border-white/5',
      text: 'text-mn-leben',
      iconBg: 'bg-mn-elevated',
    },
    {
      label: 'Ø Lösungszeit',
      value: `${stats.avg_resolution_hours}h`,
      icon: Clock,
      bg: 'bg-mn-surface',
      border: 'border-white/5',
      text: 'text-mn-teal-soft',
      iconBg: 'bg-mn-elevated',
    },
  ]

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
      {cards.map((card, i) => {
        const Icon = card.icon
        return (
          <div
            key={i}
            className={cn(
              'rounded-2xl border p-4 transition-all hover:shadow-sm',
              card.bg, card.border,
            )}
          >
            <div className="flex items-center gap-2 mb-2">
              <div className={cn('w-8 h-8 rounded-xl flex items-center justify-center', card.iconBg)}>
                <Icon className={cn('w-4 h-4', card.text)} />
              </div>
              {card.pulse && (
                <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              )}
            </div>
            <p className={cn('text-2xl font-black', card.text)}>{card.value}</p>
            <p className="text-xs text-mn-mute mt-0.5">{card.label}</p>
          </div>
        )
      })}
    </div>
  )
}
