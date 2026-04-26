'use client'

import { type ReactNode } from 'react'
import { cn } from '@/lib/design-system'

export interface SectionHeaderProps {
  title: string
  subtitle?: string
  icon?: ReactNode
  action?: ReactNode
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const sizeStyles = {
  sm: 'text-sm',
  md: 'text-lg',
  lg: 'text-xl',
} as const

export default function SectionHeader({
  title,
  subtitle,
  icon,
  action,
  size = 'md',
  className,
}: SectionHeaderProps) {
  return (
    <div className={cn('section-header', className)}>
      <div className="flex items-center gap-2">
        {icon && (
          <span className="flex-shrink-0 text-primary-600" aria-hidden="true">
            {icon}
          </span>
        )}
        <div>
          <h2 className={cn('font-bold text-ink-900', sizeStyles[size])}>
            {title}
          </h2>
          {subtitle && (
            <p className="text-xs text-ink-500 mt-0.5">{subtitle}</p>
          )}
        </div>
      </div>
      {action && <div className="flex-shrink-0">{action}</div>}
    </div>
  )
}
