'use client'

import { cn } from '@/lib/utils'
import { STATUS_CONFIG, type InteractionStatus } from '../types'

interface Props {
  status: InteractionStatus
  size?: 'sm' | 'md'
}

export default function InteractionStatusBadge({ status, size = 'md' }: Props) {
  const cfg = STATUS_CONFIG[status] ?? STATUS_CONFIG.requested
  const Icon = cfg.icon

  return (
    <span className={cn(
      'inline-flex items-center gap-1 rounded-full font-medium whitespace-nowrap',
      cfg.color,
      size === 'sm' ? 'text-xs px-2 py-0.5' : 'text-sm px-3 py-1',
    )}>
      <Icon className={size === 'sm' ? 'w-3 h-3' : 'w-4 h-4'} />
      {cfg.label}
    </span>
  )
}
