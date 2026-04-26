'use client'

import { Star, TrendingUp, TrendingDown, Minus, Shield } from 'lucide-react'
import { getTrustLevelInfo, getTrustLevelProgress, formatTrustScore } from '@/lib/trust-score'
import RatingStars from './RatingStars'
import { cn } from '@/lib/utils'
import type { TrustScoreData } from '@/types'

interface TrustScoreDetailProps {
  data: TrustScoreData
  className?: string
}

export default function TrustScoreDetail({ data, className }: TrustScoreDetailProps) {
  const levelInfo = getTrustLevelInfo(data.level)
  const progress = getTrustLevelProgress(data.level, data.average, data.count)

  const dist = data.distribution || {}
  const maxDist = Math.max(...Object.values(dist), 1)

  return (
    <div className={cn('bg-white rounded-2xl shadow-sm p-6 space-y-5', className)}>
      {/* Header with big score */}
      <div className="flex items-center gap-2 text-sm font-semibold text-ink-900">
        <Shield className="w-4 h-4 text-primary-600" />
        Vertrauensprofil
      </div>

      <div className="flex items-center gap-6">
        {/* Big score number */}
        <div className="flex flex-col items-center">
          <span className="text-4xl font-bold text-ink-900">{formatTrustScore(data.average)}</span>
          <RatingStars value={Math.round(data.average)} size="sm" readOnly />
          <span className="text-xs text-ink-500 mt-1">
            {data.count} Bewertung{data.count !== 1 ? 'en' : ''}
          </span>
        </div>

        {/* Distribution bars */}
        <div className="flex-1 space-y-1">
          {[5, 4, 3, 2, 1].map(star => {
            const count = dist[String(star)] ?? 0
            const pct = maxDist > 0 ? (count / maxDist) * 100 : 0
            return (
              <div key={star} className="flex items-center gap-2">
                <span className="text-xs text-ink-500 w-3 text-right">{star}</span>
                <Star className="w-3 h-3 text-amber-400 fill-amber-400 flex-shrink-0" />
                <div className="flex-1 h-2 bg-stone-100 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-amber-400 rounded-full transition-all duration-500"
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <span className="text-xs text-ink-400 w-5 text-right">{count}</span>
              </div>
            )
          })}
        </div>
      </div>

      {/* Helpful + Recommend percentages */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-green-50 rounded-xl p-3 text-center">
          <p className="text-2xl font-bold text-green-700">{data.helpful_percent ?? 0}%</p>
          <p className="text-xs text-green-600">fanden es hilfreich</p>
        </div>
        <div className="bg-blue-50 rounded-xl p-3 text-center">
          <p className="text-2xl font-bold text-blue-700">{data.recommend_percent ?? 0}%</p>
          <p className="text-xs text-blue-600">wuerden weiterempfehlen</p>
        </div>
      </div>

      {/* Trend */}
      <div className="flex items-center gap-2">
        <span className="text-sm text-ink-600">Trend:</span>
        {data.recent_trend === 'up' && (
          <span className="flex items-center gap-1 text-sm text-green-600 font-medium">
            <TrendingUp className="w-4 h-4" /> steigend
          </span>
        )}
        {data.recent_trend === 'down' && (
          <span className="flex items-center gap-1 text-sm text-red-600 font-medium">
            <TrendingDown className="w-4 h-4" /> fallend
          </span>
        )}
        {data.recent_trend === 'stable' && (
          <span className="flex items-center gap-1 text-sm text-ink-500">
            <Minus className="w-4 h-4" /> stabil
          </span>
        )}
      </div>

      {/* Level + Progress to next level */}
      <div className="border-t border-warm-100 pt-4">
        <div className="flex items-center justify-between mb-2">
          <span className={cn('inline-flex items-center gap-1 text-sm font-semibold', levelInfo.color)}>
            <span>{levelInfo.icon}</span> Level {data.level}: {levelInfo.name}
          </span>
          {progress.nextLevel && (
            <span className="text-xs text-ink-400">
              Naechstes: {progress.nextLevel.icon} {progress.nextLevel.name}
            </span>
          )}
        </div>
        <p className="text-xs text-ink-500 mb-2">{levelInfo.description}</p>

        {progress.nextLevel && (
          <div className="space-y-1.5">
            <div className="w-full h-2 bg-stone-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-primary-500 rounded-full transition-all duration-700"
                style={{ width: `${progress.progress}%` }}
              />
            </div>
            <div className="flex justify-between text-[10px] text-ink-400">
              <span>
                Bewertungen: {data.count}/{progress.nextLevel.minRatings}
              </span>
              <span>
                Durchschnitt: {formatTrustScore(data.average)}/{formatTrustScore(progress.nextLevel.minAvg)}
              </span>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
