'use client'

import { cn } from '@/lib/utils'
import { URGENCY_CONFIG, type CrisisUrgency } from '../types'

interface Props {
  urgency: CrisisUrgency
  showLabel?: boolean
  size?: 'sm' | 'md' | 'lg'
  pulse?: boolean
}

export default function CrisisUrgencyIndicator({ urgency, showLabel = true, size = 'sm', pulse = true }: Props) {
  const cfg = URGENCY_CONFIG[urgency]
  if (!cfg) return null
  const Icon = cfg.icon

  const dotSize = size === 'lg' ? 'w-3 h-3' : size === 'md' ? 'w-2.5 h-2.5' : 'w-2 h-2'
  const iconSize = size === 'lg' ? 'w-5 h-5' : size === 'md' ? 'w-4 h-4' : 'w-3 h-3'

  return (
    <div
      className={cn(
        'inline-flex items-center gap-1.5',
        showLabel && cn('rounded-full border font-semibold', cfg.bgColor, cfg.color, cfg.borderColor,
          size === 'sm' ? 'px-2 py-0.5 text-xs' : size === 'md' ? 'px-2.5 py-1 text-sm' : 'px-3 py-1.5 text-base'
        ),
      )}
      aria-label={`Dringlichkeit: ${cfg.label}`}
    >
      <div className="relative flex items-center justify-center">
        <div className={cn('rounded-full', dotSize, cfg.pulseColor)} />
        {pulse && (urgency === 'critical' || urgency === 'high') && (
          <div className={cn('absolute rounded-full animate-ping opacity-75', dotSize, cfg.pulseColor)} />
        )}
      </div>
      {showLabel && (
        <>
          <Icon className={iconSize} />
          <span>{cfg.label}</span>
        </>
      )}
    </div>
  )
}
