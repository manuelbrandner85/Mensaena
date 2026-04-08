'use client'

import { Sparkles, Check, Users, Clock } from 'lucide-react'
import { cn } from '@/lib/design-system'
import type { MatchNotificationType } from '../types'

interface MatchNotificationCardProps {
  type: MatchNotificationType
  title: string
  message: string
  time: string
  onAction?: () => void
}

const typeConfig: Record<MatchNotificationType, {
  icon: typeof Sparkles
  color: string
  bg: string
}> = {
  new_match: {
    icon: Sparkles,
    color: 'text-indigo-600',
    bg: 'bg-indigo-50',
  },
  match_partner_accepted: {
    icon: Check,
    color: 'text-amber-600',
    bg: 'bg-amber-50',
  },
  match_both_accepted: {
    icon: Users,
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
  },
  match_expiring: {
    icon: Clock,
    color: 'text-red-600',
    bg: 'bg-red-50',
  },
}

export default function MatchNotificationCard({
  type,
  title,
  message,
  time,
  onAction,
}: MatchNotificationCardProps) {
  const cfg = typeConfig[type]
  const Icon = cfg.icon

  return (
    <button
      onClick={onAction}
      className={cn(
        'w-full text-left p-3 rounded-xl border transition-all',
        'hover:shadow-sm hover:border-gray-200',
        'bg-white border-gray-100',
      )}
    >
      <div className="flex items-start gap-3">
        <div className={cn('w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0', cfg.bg)}>
          <Icon className={cn('w-4 h-4', cfg.color)} />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-900 truncate">{title}</p>
          <p className="text-xs text-gray-500 line-clamp-2">{message}</p>
          <p className="text-[10px] text-gray-400 mt-1">{time}</p>
        </div>
      </div>
    </button>
  )
}
