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
        'card-depth flex flex-col items-center justify-center text-center py-14 px-6',
        className,
      )}
      role="status"
    >
      <div className="icon-surface w-14 h-14 rounded-2xl flex items-center justify-center mb-5">
        {icon || <Inbox className="w-7 h-7 text-mn-bronze" />}
      </div>
      <h3 className="text-sm font-semibold text-mn-ink mb-1">{title}</h3>
      {description && (
        <p className="text-sm text-mn-mute max-w-xs mb-4">{description}</p>
      )}
      {action && <div className="mt-2">{action}</div>}
    </div>
  )
}
