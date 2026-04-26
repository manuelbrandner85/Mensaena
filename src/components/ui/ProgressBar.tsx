'use client'

import { cn } from '@/lib/design-system'

const sizeStyles = {
  sm: 'h-1.5',
  md: 'h-2',
  lg: 'h-3',
} as const

const colorStyles = {
  primary: 'bg-primary-500',
  success: 'bg-green-500',
  warning: 'bg-amber-500',
  danger:  'bg-red-500',
  info:    'bg-blue-500',
} as const

export interface ProgressBarProps {
  value: number  // 0-100
  max?: number
  size?: keyof typeof sizeStyles
  color?: keyof typeof colorStyles
  label?: string
  showPercent?: boolean
  animated?: boolean
  className?: string
}

export default function ProgressBar({
  value,
  max = 100,
  size = 'md',
  color = 'primary',
  label,
  showPercent = false,
  animated = true,
  className,
}: ProgressBarProps) {
  const percent = Math.min(Math.max((value / max) * 100, 0), 100)

  return (
    <div className={cn('w-full', className)}>
      {(label || showPercent) && (
        <div className="flex items-center justify-between mb-1.5">
          {label && <span className="text-sm font-medium text-ink-700">{label}</span>}
          {showPercent && (
            <span className="text-sm font-bold text-ink-900">{Math.round(percent)}%</span>
          )}
        </div>
      )}
      <div
        className={cn('rounded-full bg-stone-100 overflow-hidden', sizeStyles[size])}
        role="progressbar"
        aria-valuenow={percent}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label}
      >
        <div
          className={cn(
            'h-full rounded-full transition-all duration-500',
            colorStyles[color],
            animated && 'animate-progress-fill',
          )}
          style={{ width: `${percent}%`, '--progress-width': `${percent}%` } as React.CSSProperties}
        />
      </div>
    </div>
  )
}
