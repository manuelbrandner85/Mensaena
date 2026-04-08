'use client'

import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/design-system'

// ── Variants ────────────────────────────────────────────────
const variantStyles = {
  primary:   'btn-primary',
  secondary: 'btn-secondary',
  outline:   'btn-outline',
  ghost:     'btn-ghost',
  danger:    'btn-danger',
} as const

const sizeStyles = {
  xs: 'px-2.5 py-1 text-xs gap-1',
  sm: 'px-4 py-2 text-sm gap-1.5',
  md: 'px-6 py-3 text-sm gap-2',
  lg: 'px-8 py-4 text-base gap-2',
} as const

// ── Props ───────────────────────────────────────────────────
export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: keyof typeof variantStyles
  size?: keyof typeof sizeStyles
  loading?: boolean
  icon?: ReactNode
  iconRight?: ReactNode
  fullWidth?: boolean
}

// ── Component ───────────────────────────────────────────────
const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = 'primary',
      size = 'md',
      loading = false,
      icon,
      iconRight,
      fullWidth = false,
      disabled,
      children,
      className,
      ...rest
    },
    ref,
  ) => {
    const isDisabled = disabled || loading

    return (
      <button
        ref={ref}
        disabled={isDisabled}
        className={cn(
          variantStyles[variant],
          sizeStyles[size],
          fullWidth && 'w-full',
          isDisabled && 'opacity-50 pointer-events-none',
          className,
        )}
        aria-busy={loading || undefined}
        {...rest}
      >
        {loading ? (
          <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
        ) : icon ? (
          <span className="flex-shrink-0" aria-hidden="true">{icon}</span>
        ) : null}
        {children}
        {iconRight && !loading && (
          <span className="flex-shrink-0" aria-hidden="true">{iconRight}</span>
        )}
      </button>
    )
  },
)

Button.displayName = 'Button'
export default Button
