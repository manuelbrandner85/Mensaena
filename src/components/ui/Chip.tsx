'use client'

import { X } from 'lucide-react'
import { cn } from '@/lib/design-system'
import type { ReactNode } from 'react'

export interface ChipProps {
  children: ReactNode
  variant?: 'default' | 'active' | 'outline'
  size?: 'sm' | 'md'
  icon?: ReactNode
  onRemove?: () => void
  onClick?: () => void
  className?: string
}

const variantStyles = {
  default: 'tag',
  active:  'tag-active',
  outline: 'tag border-stone-200 bg-white text-ink-700',
} as const

const sizeStyles = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-xs',
} as const

export default function Chip({
  children,
  variant = 'default',
  size = 'md',
  icon,
  onRemove,
  onClick,
  className,
}: ChipProps) {
  const Tag = onClick ? 'button' : 'span'

  return (
    <Tag
      onClick={onClick}
      className={cn(
        variantStyles[variant],
        sizeStyles[size],
        onClick && 'cursor-pointer',
        className,
      )}
    >
      {icon && <span className="flex-shrink-0" aria-hidden="true">{icon}</span>}
      {children}
      {onRemove && (
        <button
          onClick={(e) => {
            e.stopPropagation()
            onRemove()
          }}
          className="flex-shrink-0 ml-0.5 hover:text-red-500 transition-colors"
          aria-label="Entfernen"
        >
          <X className="w-3 h-3" />
        </button>
      )}
    </Tag>
  )
}
