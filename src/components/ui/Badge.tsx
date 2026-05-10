'use client'

import { type HTMLAttributes, type ReactNode } from 'react'
import { cn } from '@/lib/design-system'

// ── Variants ────────────────────────────────────────────────
const variantStyles = {
  green:  'badge-green',
  blue:   'badge-blue',
  red:    'badge-red',
  orange: 'badge-orange',
  gray:   'badge-gray',
  purple: 'badge-purple',
  primary:'badge bg-mn-amber/10 text-primary-800',
  success:'badge bg-mn-elevated text-mn-leben',
  warning:'badge bg-amber-100 text-amber-700',
  danger: 'badge bg-mn-elevated text-mn-herzrot',
  info:   'badge bg-mn-elevated text-mn-teal-soft',
} as const

const sizeStyles = {
  sm: 'px-1.5 py-0.5 text-xs',
  md: 'px-2.5 py-0.5 text-xs',
  lg: 'px-3 py-1 text-sm',
} as const

// ── Props ───────────────────────────────────────────────────
export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: keyof typeof variantStyles
  size?: keyof typeof sizeStyles
  icon?: ReactNode
  dot?: boolean
  animated?: boolean
}

// ── Component ───────────────────────────────────────────────
export default function Badge({
  variant = 'primary',
  size = 'md',
  icon,
  dot = false,
  animated = false,
  children,
  className,
  ...rest
}: BadgeProps) {
  return (
    <span
      className={cn(
        variantStyles[variant],
        sizeStyles[size],
        animated && 'badge-unread',
        className,
      )}
      {...rest}
    >
      {dot && (
        <span
          className={cn(
            'w-1.5 h-1.5 rounded-full flex-shrink-0',
            variant === 'red' || variant === 'danger' ? 'bg-red-500' :
            variant === 'green' || variant === 'success' ? 'bg-green-500' :
            variant === 'orange' || variant === 'warning' ? 'bg-amber-500' :
            'bg-current',
          )}
        />
      )}
      {icon && <span className="flex-shrink-0" aria-hidden="true">{icon}</span>}
      {children}
    </span>
  )
}
