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
    { label: 'Organisationen', value: stats.total_organizations, icon: Building2, accent: '#1EAAA6' },
    { label: 'Verifiziert',    value: stats.verified_count,       icon: ShieldCheck, accent: '#10B981' },
    { label: 'Bewertungen',    value: stats.total_reviews,        icon: MessageCircle, accent: '#3B82F6' },
    { label: 'Durchschnitt',   value: stats.avg_rating > 0 ? `${stats.avg_rating} / 5` : '–', icon: Star, accent: '#F59E0B' },
  ]

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4" role="region" aria-label="Statistiken">
      {items.map((item, i) => {
        const Icon = item.icon
        return (
          <div
            key={item.label}
            className="relative bg-white rounded-xl border border-gray-100 p-3 shadow-soft hover:shadow-card transition-shadow overflow-hidden group"
            style={{ animationDelay: `${i * 80}ms` }}
          >
            <div
              className="absolute top-0 left-0 right-0 h-px opacity-60"
              style={{ background: `linear-gradient(90deg, ${item.accent}66, transparent)` }}
            />
            <div className="flex items-center gap-2">
              <div
                className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0"
                style={{ background: `${item.accent}18` }}
              >
                <Icon className="w-3.5 h-3.5" style={{ color: item.accent }} />
              </div>
              <span className="display-numeral text-lg font-bold text-gray-900 tabular-nums">{item.value}</span>
            </div>
            <p className="text-xs text-gray-500 mt-1.5 leading-snug">{item.label}</p>
          </div>
        )
      })}
    </div>
  )
}
