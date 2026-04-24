'use client'

import { useRef, useEffect, useState } from 'react'
import type { ScoreBreakdown } from '../types'
import { SCORE_FACTORS } from '../types'
import { scoreToPercent, getScoreLabel, getScoreColor } from '@/lib/matching/match-scorer'

interface MatchScoreProps {
  score: number
  breakdown?: ScoreBreakdown
  size?: 'sm' | 'md' | 'lg'
  showBreakdown?: boolean
  animated?: boolean
}

export default function MatchScore({
  score,
  breakdown,
  size = 'md',
  showBreakdown = false,
  animated = true,
}: MatchScoreProps) {
  const percent = scoreToPercent(score)
  const label = getScoreLabel(score)
  const color = getScoreColor(score)
  const [displayPercent, setDisplayPercent] = useState(animated ? 0 : percent)
  const rafRef = useRef<number | undefined>(undefined)

  // Size configs
  const sizes = {
    sm: { ring: 40, stroke: 3, text: 'text-xs', label: 'text-[9px]' },
    md: { ring: 56, stroke: 4, text: 'text-sm', label: 'text-[10px]' },
    lg: { ring: 80, stroke: 5, text: 'text-lg', label: 'text-xs' },
  }
  const cfg = sizes[size]
  const radius = (cfg.ring - cfg.stroke) / 2
  const circumference = 2 * Math.PI * radius

  // Animate with requestAnimationFrame
  useEffect(() => {
    if (!animated) {
      setDisplayPercent(percent)
      return
    }

    const start = performance.now()
    const duration = 800

    function step(now: number) {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplayPercent(Math.round(percent * eased))

      if (progress < 1) {
        rafRef.current = requestAnimationFrame(step)
      }
    }

    rafRef.current = requestAnimationFrame(step)
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
    }
  }, [percent, animated])

  const offset = circumference - (displayPercent / 100) * circumference

  return (
    <div className="flex flex-col items-center gap-2">
      {/* SVG Circle */}
      <div className="relative" style={{ width: cfg.ring, height: cfg.ring }}>
        <svg
          width={cfg.ring}
          height={cfg.ring}
          className="-rotate-90"
          aria-label={`Match-Score: ${percent}%`}
        >
          {/* Background circle */}
          <circle
            cx={cfg.ring / 2}
            cy={cfg.ring / 2}
            r={radius}
            fill="none"
            stroke="#e5e7eb"
            strokeWidth={cfg.stroke}
          />
          {/* Score circle */}
          <circle
            cx={cfg.ring / 2}
            cy={cfg.ring / 2}
            r={radius}
            fill="none"
            stroke={color}
            strokeWidth={cfg.stroke}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            style={{ transition: animated ? 'none' : 'stroke-dashoffset 0.6s ease-out' }}
          />
        </svg>
        {/* Center text */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className={`font-bold ${cfg.text}`} style={{ color }}>
            {displayPercent}%
          </span>
        </div>
      </div>

      {/* Label */}
      <span className={`font-medium text-gray-600 ${cfg.label}`}>{label}</span>

      {/* Breakdown bars */}
      {showBreakdown && breakdown && (
        <div className="w-full space-y-1.5 mt-2">
          {SCORE_FACTORS.map((factor) => {
            const value = breakdown[factor.key] ?? 0
            const pct = Math.round((value / factor.maxPoints) * 100)
            return (
              <div key={factor.key} className="flex items-center gap-2">
                <span className="text-[10px] text-gray-500 w-20 truncate">{factor.label}</span>
                <div className="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{ width: `${pct}%`, backgroundColor: factor.color }}
                  />
                </div>
                <span className="text-[10px] text-gray-400 w-6 text-right">
                  {Math.round(value)}
                </span>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
