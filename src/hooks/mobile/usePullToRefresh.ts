'use client'

import { useRef, useState, useCallback, useEffect } from 'react'

export interface UsePullToRefreshOptions {
  /** Called when the pull exceeds the threshold and finger is lifted */
  onRefresh: () => Promise<void> | void
  /** Minimum pull (px) before triggering refresh. Default 80 */
  threshold?: number
  /** Damping factor applied to the pull distance. Default 0.5 */
  dampingFactor?: number
  /** Disable pull-to-refresh programmatically */
  disabled?: boolean
}

export interface PullToRefreshState {
  /** Current (damped) pull distance in px */
  pullDistance: number
  /** true while the user is actively pulling */
  isPulling: boolean
  /** true while the onRefresh callback is running */
  isRefreshing: boolean
  /** true when pullDistance > threshold (ready to trigger) */
  canRelease: boolean
}

/**
 * Pull-to-refresh hook.
 * Returns state + a ref to attach to the scrollable container.
 */
export function usePullToRefresh<T extends HTMLElement = HTMLDivElement>(
  opts: UsePullToRefreshOptions
) {
  const {
    onRefresh,
    threshold = 80,
    dampingFactor = 0.5,
    disabled = false,
  } = opts

  const ref = useRef<T>(null)
  const [pullDistance, setPullDistance] = useState(0)
  const [isPulling, setIsPulling] = useState(false)
  const [isRefreshing, setIsRefreshing] = useState(false)

  const startY = useRef(0)
  const tracking = useRef(false)

  const canRelease = pullDistance >= threshold

  const handleTouchStart = useCallback(
    (e: TouchEvent) => {
      if (disabled || isRefreshing) return
      const el = ref.current
      if (!el || el.scrollTop > 0) return

      startY.current = e.touches[0].clientY
      tracking.current = true
    },
    [disabled, isRefreshing]
  )

  const handleTouchMove = useCallback(
    (e: TouchEvent) => {
      if (!tracking.current || disabled || isRefreshing) return
      const el = ref.current
      if (!el || el.scrollTop > 0) {
        tracking.current = false
        return
      }

      const dy = e.touches[0].clientY - startY.current
      if (dy > 0) {
        setIsPulling(true)
        setPullDistance(Math.min(dy * dampingFactor, 120))
      }
    },
    [disabled, isRefreshing, dampingFactor]
  )

  const handleTouchEnd = useCallback(async () => {
    if (!tracking.current) return
    tracking.current = false

    if (pullDistance >= threshold && !isRefreshing) {
      setIsRefreshing(true)
      try {
        await onRefresh()
      } finally {
        setIsRefreshing(false)
      }
    }

    setIsPulling(false)
    setPullDistance(0)
  }, [pullDistance, threshold, isRefreshing, onRefresh])

  useEffect(() => {
    const el = ref.current
    if (!el) return

    el.addEventListener('touchstart', handleTouchStart, { passive: true })
    el.addEventListener('touchmove', handleTouchMove, { passive: true })
    el.addEventListener('touchend', handleTouchEnd)

    return () => {
      el.removeEventListener('touchstart', handleTouchStart)
      el.removeEventListener('touchmove', handleTouchMove)
      el.removeEventListener('touchend', handleTouchEnd)
    }
  }, [handleTouchStart, handleTouchMove, handleTouchEnd])

  const state: PullToRefreshState = {
    pullDistance,
    isPulling,
    isRefreshing,
    canRelease,
  }

  return { ref, ...state }
}

export default usePullToRefresh
