'use client'

import { forwardRef, type HTMLAttributes, type ReactNode } from 'react'
import { cn } from '@/lib/design-system'

// ── Variants ────────────────────────────────────────────────
const variantStyles = {
  default: 'card',
  hover:   'card-hover',
  accent:  'card-accent',
  stat:    'stat-card',
  flat:    'bg-white rounded-2xl border border-warm-100 overflow-hidden',
  glass:   'glass',
} as const

// ── Props ───────────────────────────────────────────────────
export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: keyof typeof variantStyles
  padding?: 'none' | 'sm' | 'md' | 'lg'
  header?: ReactNode
  footer?: ReactNode
}

const paddingStyles = {
  none: '',
  sm:   'p-3',
  md:   'p-4',
  lg:   'p-6',
} as const

// ── Component ───────────────────────────────────────────────
const Card = forwardRef<HTMLDivElement, CardProps>(
  ({ variant = 'default', padding = 'md', header, footer, children, className, ...rest }, ref) => {
    return (
      <div
        ref={ref}
        className={cn(variantStyles[variant], paddingStyles[padding], className)}
        {...rest}
      >
        {header && (
          <div className="pb-3 mb-3 border-b border-warm-100">{header}</div>
        )}
        {children}
        {footer && (
          <div className="pt-3 mt-3 border-t border-warm-100">{footer}</div>
        )}
      </div>
    )
  },
)

Card.displayName = 'Card'
export default Card
