'use client'

import { Star } from 'lucide-react'
import { getTrustLevel, getTrustLevelInfo, formatTrustScore } from '@/lib/trust-score'
import { cn } from '@/lib/utils'

interface TrustScoreBadgeProps {
  score: number
  count?: number
  size?: 'sm' | 'md'
  showTooltip?: boolean
  className?: string
}

export default function TrustScoreBadge({
  score,
  count = 0,
  size = 'sm',
  showTooltip = true,
  className,
}: TrustScoreBadgeProps) {
  // score is 0-100 in profiles, convert to 0-5
  const avgOnFive = count > 0 ? score / 20 : 0
  const level = getTrustLevel(avgOnFive, count)
  const info = getTrustLevelInfo(level)

  if (count === 0 && score === 0) return null

  const isSm = size === 'sm'

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full border font-medium',
        info.bgColor, info.borderColor, info.color,
        isSm ? 'text-[10px] px-1.5 py-0.5' : 'text-xs px-2 py-0.5',
        className,
      )}
      title={showTooltip ? `${info.icon} ${info.name} – ${formatTrustScore(avgOnFive)}/5 (${count} Bewertungen)` : undefined}
    >
      <Star className={cn(isSm ? 'w-2.5 h-2.5' : 'w-3 h-3', 'fill-current')} />
      <span>{formatTrustScore(avgOnFive)}</span>
      {count > 0 && !isSm && <span className="opacity-60">({count})</span>}
    </span>
  )
}
