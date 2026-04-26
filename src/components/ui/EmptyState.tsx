'use client'

import { type ReactNode } from 'react'
import { Inbox } from 'lucide-react'
import { cn } from '@/lib/design-system'

export interface EmptyStateProps {
  icon?: ReactNode
  title: string
  description?: string
  action?: ReactNode
  className?: string
}

export default function EmptyState({
  icon,
  title,
  description,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center text-center py-12 px-6',
        'bg-white rounded-2xl border border-warm-100',
        className,
      )}
      role="status"
    >
      <div className="w-14 h-14 rounded-2xl bg-stone-50 flex items-center justify-center mb-4">
        {icon || <Inbox className="w-7 h-7 text-stone-400" />}
      </div>
      <h3 className="text-sm font-semibold text-ink-900 mb-1">{title}</h3>
      {description && (
        <p className="text-sm text-ink-500 max-w-xs mb-4">{description}</p>
      )}
      {action && <div className="mt-2">{action}</div>}
    </div>
  )
}
