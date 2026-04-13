'use client'

import { Heart, FileText, Handshake, Bookmark } from 'lucide-react'
import { Card } from '@/components/ui'
import type { UserStats } from '../types'

interface StatsCardsProps {
  stats: UserStats
}

const cards = [
  { key: 'peopleHelped' as const, icon: Heart, label: 'Menschen geholfen', color: 'teal' },
  { key: 'postsCreated' as const, icon: FileText, label: 'Beiträge erstellt', color: 'blue' },
  { key: 'interactionsCompleted' as const, icon: Handshake, label: 'Interaktionen', color: 'purple' },
  { key: 'savedPostsCount' as const, icon: Bookmark, label: 'Gespeichert', color: 'amber' },
]

const colorMap: Record<string, { bg: string; text: string }> = {
  teal: { bg: 'bg-primary-50', text: 'text-primary-600' },
  blue: { bg: 'bg-blue-50', text: 'text-blue-600' },
  purple: { bg: 'bg-purple-50', text: 'text-purple-600' },
  amber: { bg: 'bg-amber-50', text: 'text-amber-600' },
}

export default function StatsCards({ stats }: StatsCardsProps) {
  const allZero = cards.every((c) => stats[c.key] === 0)

  if (allZero) {
    return (
      <Card variant="flat" padding="lg" className="text-center">
        <p className="text-2xl mb-2">🌱</p>
        <p className="text-sm font-semibold text-gray-900">Dein Abenteuer beginnt!</p>
        <p className="text-xs text-gray-500 mt-1">Erstelle einen Beitrag oder hilf jemandem, um deine Statistiken zu füllen.</p>
      </Card>
    )
  }

  return (
    <div className="grid grid-cols-2 gap-3">
      {cards.map((card) => {
        const Icon = card.icon
        const colors = colorMap[card.color]
        return (
          <Card key={card.key} variant="flat" padding="md" className="bg-gradient-to-br from-white to-primary-50/20">
            <div className={`w-8 h-8 rounded-lg ${colors.bg} flex items-center justify-center`}>
              <Icon className={`w-4 h-4 ${colors.text}`} />
            </div>
            <p className="text-2xl font-bold text-gray-900 mt-2">{stats[card.key]}</p>
            <p className="text-xs text-gray-500 mt-0.5">{card.label}</p>
          </Card>
        )
      })}
    </div>
  )
}
