import { useRef, useCallback } from 'react'

interface SwipeHandlers {
  onTouchStart: (e: React.TouchEvent) => void
  onTouchMove: (e: React.TouchEvent) => void
  onTouchEnd: () => void
}

interface SwipeOptions {
  onSwipeLeft?: () => void
  onSwipeRight?: () => void
  threshold?: number
}

export function useSwipe({ onSwipeLeft, onSwipeRight, threshold = 80 }: SwipeOptions): SwipeHandlers {
  const startX = useRef(0)
  const startY = useRef(0)
  const deltaX = useRef(0)

  const onTouchStart = useCallback((e: React.TouchEvent) => {
    startX.current = e.touches[0].clientX
    startY.current = e.touches[0].clientY
    deltaX.current = 0
  }, [])

  const onTouchMove = useCallback((e: React.TouchEvent) => {
    deltaX.current = e.touches[0].clientX - startX.current
  }, [])

  const onTouchEnd = useCallback(() => {
    if (Math.abs(deltaX.current) < threshold) return
    if (deltaX.current > 0) {
      onSwipeRight?.()
    } else {
      onSwipeLeft?.()
    }
    deltaX.current = 0
  }, [onSwipeLeft, onSwipeRight, threshold])

  return { onTouchStart, onTouchMove, onTouchEnd }
}
