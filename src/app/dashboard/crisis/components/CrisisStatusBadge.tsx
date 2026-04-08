'use client'

import { cn } from '@/lib/utils'
import { STATUS_CONFIG, type CrisisStatus } from '../types'

interface Props {
  status: CrisisStatus
  size?: 'sm' | 'md'
}

export default function CrisisStatusBadge({ status, size = 'sm' }: Props) {
  const cfg = STATUS_CONFIG[status]
  if (!cfg) return null
  const Icon = cfg.icon

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full font-semibold border',
        cfg.bgColor, cfg.color, cfg.borderColor,
        size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1 text-sm',
      )}
      aria-label={`Status: ${cfg.label}`}
    >
      <Icon className={size === 'sm' ? 'w-3 h-3' : 'w-4 h-4'} />
      {cfg.label}
    </span>
  )
}
