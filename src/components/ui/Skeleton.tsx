'use client'

import { cn } from '@/lib/design-system'

// ── Variants ────────────────────────────────────────────────
const variantStyles = {
  text:   'skeleton-text',
  title:  'skeleton-title',
  sm:     'skeleton-sm',
  round:  'skeleton-round',
  card:   'skeleton-card',
  rect:   'skeleton',
} as const

// ── Props ───────────────────────────────────────────────────
export interface SkeletonProps {
  variant?: keyof typeof variantStyles
  width?: string
  height?: string
  className?: string
  count?: number
}

// ── Component ───────────────────────────────────────────────
export default function Skeleton({
  variant = 'rect',
  width,
  height,
  className,
  count = 1,
}: SkeletonProps) {
  const style = {
    ...(width ? { width } : {}),
    ...(height ? { height } : {}),
  }

  if (count > 1) {
    return (
      <div className="space-y-2" role="status" aria-label="Laden...">
        {Array.from({ length: count }).map((_, i) => (
          <div
            key={i}
            className={cn(variantStyles[variant], className)}
            style={style}
            aria-hidden="true"
          />
        ))}
        <span className="sr-only">Laden...</span>
      </div>
    )
  }

  return (
    <div
      className={cn(variantStyles[variant], className)}
      style={style}
      role="status"
      aria-label="Laden..."
    >
      <span className="sr-only">Laden...</span>
    </div>
  )
}
