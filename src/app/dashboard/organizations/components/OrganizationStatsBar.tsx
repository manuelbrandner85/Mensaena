'use client'

import { Building2, ShieldCheck, Star, MessageCircle } from 'lucide-react'
import type { OrganizationStats } from '../types'

interface Props {
  stats: OrganizationStats | null
  loading: boolean
}

export default function OrganizationStatsBar({ stats, loading }: Props) {
  if (loading || !stats) {
    return (
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="bg-white rounded-xl border border-gray-100 p-3 animate-pulse">
            <div className="h-6 bg-gray-100 rounded w-8 mb-1" />
            <div className="h-3 bg-gray-50 rounded w-16" />
          </div>
        ))}
      </div>
    )
  }

  const items = [
    { label: 'Organisationen', value: stats.total_organizations, icon: Building2, color: 'text-primary-600' },
    { label: 'Verifiziert', value: stats.verified_count, icon: ShieldCheck, color: 'text-green-600' },
    { label: 'Bewertungen', value: stats.total_reviews, icon: MessageCircle, color: 'text-blue-600' },
    { label: 'Durchschnitt', value: stats.avg_rating > 0 ? `${stats.avg_rating} / 5` : '–', icon: Star, color: 'text-yellow-500' },
  ]

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4" role="region" aria-label="Statistiken">
      {items.map(item => (
        <div key={item.label} className="bg-white rounded-xl border border-gray-100 p-3">
          <div className="flex items-center gap-2">
            <item.icon className={`w-4 h-4 ${item.color}`} />
            <span className="text-lg font-bold text-gray-900">{item.value}</span>
          </div>
          <p className="text-xs text-gray-500 mt-0.5">{item.label}</p>
        </div>
      ))}
    </div>
  )
}
