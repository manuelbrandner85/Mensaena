'use client'

import { MapPin, Users } from 'lucide-react'
import Card from '@/components/ui/Card'
import { cn } from '@/lib/utils'

interface LocalChallengeCardProps {
  city: string
  postalCode: string
  neighborCount: number
  challengeGoal?: number
}

export default function LocalChallengeCard({
  city,
  postalCode,
  neighborCount,
  challengeGoal = 5,
}: LocalChallengeCardProps) {
  if (!postalCode) return null

  const progress = Math.min((neighborCount / challengeGoal) * 100, 100)
  const reached = neighborCount >= challengeGoal
  const remaining = Math.max(challengeGoal - neighborCount, 0)

  return (
    <Card variant="default">
      <div className="flex items-start gap-3 mb-4">
        <div className="w-9 h-9 rounded-xl bg-primary-50 border border-primary-200 flex items-center justify-center flex-shrink-0">
          <MapPin className="w-4 h-4 text-primary-600" />
        </div>
        <div className="min-w-0">
          <p className="text-sm font-semibold text-ink-800">
            Straßen-Challenge · {postalCode} {city}
          </p>
          <p className="text-xs text-ink-500 mt-0.5">
            {reached
              ? `🎉 Ziel erreicht! ${neighborCount} Nachbarn aus deinem Gebiet sind bereits dabei.`
              : `${neighborCount} von ${challengeGoal} Nachbarn aus deinem Gebiet sind dabei – noch ${remaining} fehlen!`}
          </p>
        </div>
        {reached && (
          <div className="flex-shrink-0 text-sm font-bold text-primary-600 bg-primary-50 border border-primary-200 rounded-lg px-2.5 py-1">
            ✓ Geschafft
          </div>
        )}
      </div>

      {/* Progress bar */}
      <div className="w-full bg-stone-100 rounded-full h-2.5 overflow-hidden mb-3">
        <div
          className={cn(
            'h-2.5 rounded-full transition-all duration-700',
            reached
              ? 'bg-gradient-to-r from-primary-400 to-primary-600'
              : 'bg-gradient-to-r from-primary-300 to-primary-500',
          )}
          style={{ width: `${progress}%` }}
        />
      </div>

      <div className="flex items-center justify-between text-xs text-ink-500">
        <span className="flex items-center gap-1">
          <Users className="w-3.5 h-3.5" />
          {neighborCount} Nachbarn bereits registriert
        </span>
        <span>Ziel: {challengeGoal}</span>
      </div>

      {reached && (
        <div className="mt-3 px-3 py-2 rounded-lg bg-primary-50 border border-primary-200 text-xs text-primary-700 font-medium">
          🏘️ Dein Gebiet hat ein starkes Netzwerk! Lade weitere Nachbarn ein um die Gemeinschaft zu stärken.
        </div>
      )}
    </Card>
  )
}
