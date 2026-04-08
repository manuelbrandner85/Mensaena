'use client'

import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/design-system'

const sizeStyles = {
  xs: 'p-1 rounded-md',
  sm: 'p-1.5 rounded-lg',
  md: 'p-2 rounded-xl',
  lg: 'p-3 rounded-xl',
} as const

const variantStyles = {
  ghost:   'icon-btn',
  subtle:  'text-gray-500 hover:text-gray-800 hover:bg-gray-100 transition-all',
  primary: 'text-primary-600 hover:text-primary-800 hover:bg-primary-50 transition-all',
  danger:  'text-gray-500 hover:text-red-600 hover:bg-red-50 transition-all',
} as const

export interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: ReactNode
  size?: keyof typeof sizeStyles
  variant?: keyof typeof variantStyles
  loading?: boolean
  label: string // Required for a11y
}

const IconButton = forwardRef<HTMLButtonElement, IconButtonProps>(
  ({ icon, size = 'md', variant = 'ghost', loading = false, label, disabled, className, ...rest }, ref) => {
    const isDisabled = disabled || loading

    return (
      <button
        ref={ref}
        disabled={isDisabled}
        aria-label={label}
        title={label}
        className={cn(
          variantStyles[variant],
          sizeStyles[size],
          isDisabled && 'opacity-50 pointer-events-none',
          className,
        )}
        {...rest}
      >
        {loading ? (
          <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
        ) : (
          <span aria-hidden="true">{icon}</span>
        )}
      </button>
    )
  },
)

IconButton.displayName = 'IconButton'
export default IconButton
