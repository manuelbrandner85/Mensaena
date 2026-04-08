'use client'

import { useState, useCallback } from 'react'
import { Star } from 'lucide-react'
import { cn } from '@/lib/utils'

interface RatingStarsProps {
  value: number
  onChange?: (value: number) => void
  size?: 'sm' | 'md' | 'lg'
  showLabel?: boolean
  showCount?: boolean
  count?: number
  readOnly?: boolean
  halfStars?: boolean
}

const SIZE_MAP = {
  sm: 'w-3.5 h-3.5',
  md: 'w-5 h-5',
  lg: 'w-7 h-7',
}

const LABELS = ['', 'Schlecht', 'Geht so', 'Okay', 'Gut', 'Ausgezeichnet']

export default function RatingStars({
  value,
  onChange,
  size = 'md',
  showLabel = false,
  showCount = false,
  count,
  readOnly = false,
  halfStars = false,
}: RatingStarsProps) {
  const [hoverValue, setHoverValue] = useState(0)
  const interactive = !readOnly && !!onChange

  const handleClick = useCallback((star: number) => {
    if (!interactive) return
    onChange?.(star)
  }, [interactive, onChange])

  const handleMouseMove = useCallback((star: number, e: React.MouseEvent) => {
    if (!interactive) return
    if (halfStars) {
      const rect = e.currentTarget.getBoundingClientRect()
      const isLeft = e.clientX - rect.left < rect.width / 2
      setHoverValue(isLeft ? star - 0.5 : star)
    } else {
      setHoverValue(star)
    }
  }, [interactive, halfStars])

  const displayValue = hoverValue > 0 ? hoverValue : value
  const displayLabel = LABELS[Math.round(hoverValue > 0 ? hoverValue : value)] || ''

  return (
    <div className="flex items-center gap-1.5">
      <div
        className="flex items-center gap-0.5"
        onMouseLeave={() => setHoverValue(0)}
      >
        {[1, 2, 3, 4, 5].map((star) => {
          const isFull = displayValue >= star
          const isHalf = halfStars && !isFull && displayValue >= star - 0.5

          return (
            <button
              key={star}
              type="button"
              onClick={() => handleClick(star)}
              onMouseMove={(e) => handleMouseMove(star, e)}
              disabled={!interactive}
              className={cn(
                'relative transition-transform',
                interactive && 'cursor-pointer hover:scale-110 active:scale-95',
                !interactive && 'cursor-default',
              )}
              aria-label={`${star} Stern${star !== 1 ? 'e' : ''}`}
            >
              {/* Background star */}
              <Star className={cn(SIZE_MAP[size], 'text-gray-200')} />

              {/* Filled star */}
              {(isFull || isHalf) && (
                <Star
                  className={cn(
                    SIZE_MAP[size],
                    'absolute inset-0 text-amber-400 fill-amber-400',
                  )}
                  style={isHalf ? { clipPath: 'inset(0 50% 0 0)' } : undefined}
                />
              )}
            </button>
          )
        })}
      </div>

      {showLabel && displayLabel && (
        <span className="text-sm font-medium text-gray-600 ml-1">{displayLabel}</span>
      )}

      {showCount && count !== undefined && (
        <span className="text-xs text-gray-400 ml-1">({count})</span>
      )}
    </div>
  )
}
