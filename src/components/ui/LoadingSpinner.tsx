'use client'

import { cn } from '@/lib/design-system'

const sizeStyles = {
  sm: 'spinner-sm',
  md: 'spinner',
  lg: 'spinner-lg',
} as const

export interface LoadingSpinnerProps {
  size?: keyof typeof sizeStyles
  label?: string
  fullPage?: boolean
  className?: string
}

export default function LoadingSpinner({
  size = 'md',
  label,
  fullPage = false,
  className,
}: LoadingSpinnerProps) {
  const spinner = (
    <div
      className={cn(
        'flex flex-col items-center justify-center gap-3',
        fullPage && 'min-h-[60vh]',
        className,
      )}
      role="status"
      aria-label={label || 'Laden...'}
    >
      <div className={sizeStyles[size]} />
      {label && (
        <p className="text-sm text-gray-500 animate-pulse">{label}</p>
      )}
      <span className="sr-only">{label || 'Laden...'}</span>
    </div>
  )

  return spinner
}
