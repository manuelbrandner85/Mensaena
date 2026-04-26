'use client'

import { Star, Shield, TrendingUp, TrendingDown, Minus } from 'lucide-react'
import toast from 'react-hot-toast'
import { Card } from '@/components/ui'
import type { TrustScore } from '../types'

interface TrustScoreCardProps {
  trustScore: TrustScore
}

export default function TrustScoreCard({ trustScore }: TrustScoreCardProps) {
  const { average, totalRatings, trend } = trustScore

  return (
    <Card variant="flat" padding="md">
      <div className="flex items-center gap-2 text-sm font-semibold text-ink-900">
        <Shield className="w-4 h-4 text-primary-600" />
        Dein Vertrauen
      </div>

      {totalRatings === 0 ? (
        <div className="mt-3">
          <p className="text-xs text-ink-500">
            Noch keine Bewertungen. Hilf deinen Nachbarn und sammle Vertrauenspunkte!
          </p>
          <button
            onClick={() => toast('Hilf deinen Nachbarn – nach jeder Interaktion können sie dich bewerten. So baust du Vertrauen auf! ⭐', { icon: 'ℹ️', duration: 5000 })}
            className="text-xs text-primary-600 hover:text-primary-700 font-medium mt-2 transition-colors"
          >
            Wie funktioniert das?
          </button>
        </div>
      ) : (
        <div className="mt-3">
          <div className="flex items-center gap-3">
            {/* Big number */}
            <span className="text-3xl font-bold text-ink-900">
              {average.toFixed(1)}
            </span>

            {/* Stars */}
            <div className="flex items-center gap-0.5">
              {[1, 2, 3, 4, 5].map((i) => (
                <Star
                  key={i}
                  className={`w-4 h-4 ${
                    i <= Math.round(average)
                      ? 'text-amber-400 fill-amber-400'
                      : 'text-stone-300'
                  }`}
                />
              ))}
            </div>
          </div>

          <p className="text-xs text-ink-500 mt-1">
            basierend auf {totalRatings} Bewertung{totalRatings !== 1 ? 'en' : ''}
          </p>

          {/* Trend */}
          <div className="flex items-center gap-1 mt-2">
            {trend === 'up' && (
              <>
                <TrendingUp className="w-3.5 h-3.5 text-primary-500" />
                <span className="text-xs text-primary-600 font-medium">steigend</span>
              </>
            )}
            {trend === 'down' && (
              <>
                <TrendingDown className="w-3.5 h-3.5 text-red-500" />
                <span className="text-xs text-red-600 font-medium">fallend</span>
              </>
            )}
            {trend === 'stable' && (
              <>
                <Minus className="w-3.5 h-3.5 text-ink-400" />
                <span className="text-xs text-ink-500">stabil</span>
              </>
            )}
          </div>
        </div>
      )}
    </Card>
  )
}
