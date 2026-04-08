'use client'

import { useRef, useCallback, useEffect } from 'react'

export type SwipeDirection = 'left' | 'right' | 'up' | 'down'

export interface UseSwipeOptions {
  /** Minimum distance (px) before a swipe is recognised. Default 50 */
  threshold?: number
  /** Called when a qualifying swipe ends */
  onSwipe?: (dir: SwipeDirection) => void
  /** Specific direction callbacks */
  onSwipeLeft?: () => void
  onSwipeRight?: () => void
  onSwipeUp?: () => void
  onSwipeDown?: () => void
  /** If true, prevent vertical scroll when a horizontal swipe is detected */
  preventScrollOnHorizontal?: boolean
}

/**
 * Touch-swipe detection hook.
 * Returns a ref to attach to the swipeable element.
 */
export function useSwipe<T extends HTMLElement = HTMLDivElement>(
  opts: UseSwipeOptions = {}
) {
  const {
    threshold = 50,
    onSwipe,
    onSwipeLeft,
    onSwipeRight,
    onSwipeUp,
    onSwipeDown,
    preventScrollOnHorizontal = false,
  } = opts

  const ref = useRef<T>(null)
  const startX = useRef(0)
  const startY = useRef(0)
  const tracking = useRef(false)

  const handleTouchStart = useCallback((e: TouchEvent) => {
    startX.current = e.touches[0].clientX
    startY.current = e.touches[0].clientY
    tracking.current = true
  }, [])

  const handleTouchMove = useCallback(
    (e: TouchEvent) => {
      if (!tracking.current || !preventScrollOnHorizontal) return
      const dx = Math.abs(e.touches[0].clientX - startX.current)
      const dy = Math.abs(e.touches[0].clientY - startY.current)
      // If horizontal gesture dominates, prevent scroll
      if (dx > dy && dx > 10) {
        e.preventDefault()
      }
    },
    [preventScrollOnHorizontal]
  )

  const handleTouchEnd = useCallback(
    (e: TouchEvent) => {
      if (!tracking.current) return
      tracking.current = false

      const endX = e.changedTouches[0].clientX
      const endY = e.changedTouches[0].clientY
      const dx = endX - startX.current
      const dy = endY - startY.current

      const absDx = Math.abs(dx)
      const absDy = Math.abs(dy)

      if (Math.max(absDx, absDy) < threshold) return

      let dir: SwipeDirection
      if (absDx > absDy) {
        dir = dx > 0 ? 'right' : 'left'
      } else {
        dir = dy > 0 ? 'down' : 'up'
      }

      onSwipe?.(dir)
      if (dir === 'left') onSwipeLeft?.()
      if (dir === 'right') onSwipeRight?.()
      if (dir === 'up') onSwipeUp?.()
      if (dir === 'down') onSwipeDown?.()
    },
    [threshold, onSwipe, onSwipeLeft, onSwipeRight, onSwipeUp, onSwipeDown]
  )

  useEffect(() => {
    const el = ref.current
    if (!el) return

    el.addEventListener('touchstart', handleTouchStart, { passive: true })
    el.addEventListener('touchmove', handleTouchMove, { passive: !preventScrollOnHorizontal })
    el.addEventListener('touchend', handleTouchEnd, { passive: true })

    return () => {
      el.removeEventListener('touchstart', handleTouchStart)
      el.removeEventListener('touchmove', handleTouchMove)
      el.removeEventListener('touchend', handleTouchEnd)
    }
  }, [handleTouchStart, handleTouchMove, handleTouchEnd, preventScrollOnHorizontal])

  return ref
}

export default useSwipe
