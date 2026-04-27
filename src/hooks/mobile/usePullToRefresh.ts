'use client'

import { useRef, useState, useCallback, useEffect } from 'react'
import { hapticSelection, hapticSuccess } from '@/lib/haptic'

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

function getScrollTop(el: HTMLElement | null): number {
  if (!el) return 0
  // If the wrapper itself scrolls, use that. Otherwise fall back to the
  // window scroll (the standard case for full-page dashboard layouts).
  if (el.scrollTop > 0) return el.scrollTop
  if (typeof window !== 'undefined') {
    return window.scrollY || document.documentElement.scrollTop || 0
  }
  return 0
}

/**
 * Pull-to-refresh hook.
 * Returns state + a ref to attach to the (visual) wrapper. The hook works
 * whether the wrapper itself is the scroll container OR the page/window
 * scrolls — it auto-detects which is at scrollTop=0.
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
  const passedThreshold = useRef(false)

  const canRelease = pullDistance >= threshold

  const handleTouchStart = useCallback(
    (e: TouchEvent) => {
      if (disabled || isRefreshing) return
      if (getScrollTop(ref.current) > 0) return

      startY.current = e.touches[0].clientY
      tracking.current = true
      passedThreshold.current = false
    },
    [disabled, isRefreshing]
  )

  const handleTouchMove = useCallback(
    (e: TouchEvent) => {
      if (!tracking.current || disabled || isRefreshing) return
      if (getScrollTop(ref.current) > 0) {
        tracking.current = false
        setIsPulling(false)
        setPullDistance(0)
        return
      }

      const dy = e.touches[0].clientY - startY.current
      if (dy > 0) {
        setIsPulling(true)
        const damped = Math.min(dy * dampingFactor, 120)
        setPullDistance(damped)

        // Soft haptic the moment we cross the threshold (once).
        if (damped >= threshold && !passedThreshold.current) {
          passedThreshold.current = true
          hapticSelection()
        } else if (damped < threshold && passedThreshold.current) {
          passedThreshold.current = false
        }
      }
    },
    [disabled, isRefreshing, dampingFactor, threshold]
  )

  const handleTouchEnd = useCallback(async () => {
    if (!tracking.current) return
    tracking.current = false

    if (pullDistance >= threshold && !isRefreshing) {
      setIsRefreshing(true)
      try {
        await onRefresh()
        hapticSuccess()
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
    el.addEventListener('touchcancel', handleTouchEnd)

    return () => {
      el.removeEventListener('touchstart', handleTouchStart)
      el.removeEventListener('touchmove', handleTouchMove)
      el.removeEventListener('touchend', handleTouchEnd)
      el.removeEventListener('touchcancel', handleTouchEnd)
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
