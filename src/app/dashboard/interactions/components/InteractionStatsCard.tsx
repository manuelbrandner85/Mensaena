'use client'

import { HandHeart, HelpCircle, CheckCircle2, Loader, XCircle, AlertTriangle } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { InteractionStats } from '../types'

interface Props {
  stats: InteractionStats | null
  loading: boolean
}

const STAT_ITEMS = [
  { key: 'total_as_helper' as const, label: 'Als Helfer', icon: HandHeart, color: 'text-primary-600 bg-primary-50' },
  { key: 'total_as_helped' as const, label: 'Als Hilfesuchender', icon: HelpCircle, color: 'text-blue-600 bg-blue-50' },
  { key: 'completed' as const, label: 'Abgeschlossen', icon: CheckCircle2, color: 'text-green-600 bg-green-50' },
  { key: 'active' as const, label: 'Aktiv', icon: Loader, color: 'text-amber-600 bg-amber-50' },
]

export default function InteractionStatsCard({ stats, loading }: Props) {
  if (loading || !stats) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 animate-pulse">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="bg-white rounded-xl p-4 border border-gray-100">
            <div className="h-4 w-16 bg-gray-200 rounded mb-2" />
            <div className="h-7 w-10 bg-gray-200 rounded" />
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      {STAT_ITEMS.map(item => {
        const Icon = item.icon
        const value = stats[item.key] ?? 0
        return (
          <div key={item.key} className="bg-white rounded-xl p-4 border border-gray-100 shadow-sm">
            <div className="flex items-center gap-2 mb-1">
              <div className={cn('w-7 h-7 rounded-lg flex items-center justify-center', item.color)}>
                <Icon className="w-4 h-4" />
              </div>
            </div>
            <p className="text-2xl font-bold text-gray-900">{value}</p>
            <p className="text-xs text-gray-500 mt-0.5">{item.label}</p>
          </div>
        )
      })}
    </div>
  )
}
