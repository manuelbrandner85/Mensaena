'use client'

import { ReactNode } from 'react'
import { RefreshCw } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { usePullToRefresh } from '@/hooks/mobile'

interface PullToRefreshProps {
  onRefresh: () => Promise<void> | void
  children: ReactNode
  /** Pull threshold in px. Default 80 */
  threshold?: number
  className?: string
  disabled?: boolean
}

/**
 * Wraps content with pull-to-refresh on mobile.
 * Shows a spinner indicator above the content when pulling.
 */
export default function PullToRefresh({
  onRefresh,
  children,
  threshold = 80,
  className,
  disabled = false,
}: PullToRefreshProps) {
  const { ref, pullDistance, isPulling, isRefreshing, canRelease } =
    usePullToRefresh<HTMLDivElement>({
      onRefresh,
      threshold,
      disabled,
    })

  return (
    <div ref={ref} className={cn('relative', className)}>
      {/* Pull indicator */}
      <div
        className={cn(
          'flex items-center justify-center gap-2 overflow-hidden',
          'transition-all duration-300 bg-primary-50/80',
          'md:hidden'
        )}
        style={{
          height: isPulling || isRefreshing ? Math.max(pullDistance, isRefreshing ? 48 : 0) : 0,
        }}
        aria-hidden="true"
      >
        <RefreshCw
          className={cn(
            'w-4 h-4 text-primary-600 transition-transform',
            (canRelease || isRefreshing) && 'animate-spin'
          )}
          style={{
            transform: !isRefreshing ? `rotate(${pullDistance * 3}deg)` : undefined,
          }}
        />
        <span className="text-xs text-primary-700 font-medium select-none">
          {isRefreshing
            ? 'Wird aktualisiert…'
            : canRelease
              ? 'Loslassen zum Aktualisieren'
              : 'Ziehen zum Aktualisieren…'}
        </span>
      </div>

      {children}
    </div>
  )
}
