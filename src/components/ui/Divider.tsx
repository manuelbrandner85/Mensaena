'use client'

import { cn } from '@/lib/design-system'

export interface DividerProps {
  label?: string
  orientation?: 'horizontal' | 'vertical'
  spacing?: 'sm' | 'md' | 'lg'
  className?: string
}

const spacingStyles = {
  sm: 'my-3',
  md: 'my-6',
  lg: 'my-8',
} as const

export default function Divider({
  label,
  orientation = 'horizontal',
  spacing = 'md',
  className,
}: DividerProps) {
  if (orientation === 'vertical') {
    return (
      <div
        className={cn('w-px bg-warm-200 self-stretch mx-3', className)}
        role="separator"
        aria-orientation="vertical"
      />
    )
  }

  if (label) {
    return (
      <div
        className={cn('flex items-center gap-3', spacingStyles[spacing], className)}
        role="separator"
      >
        <div className="flex-1 border-t border-warm-200" />
        <span className="text-xs font-medium text-gray-400 flex-shrink-0">{label}</span>
        <div className="flex-1 border-t border-warm-200" />
      </div>
    )
  }

  return (
    <hr
      className={cn('divider', spacingStyles[spacing], className)}
      role="separator"
    />
  )
}
