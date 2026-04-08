'use client'

import { ReactNode, useRef, useState, useCallback, useEffect } from 'react'
import { cn } from '@/lib/design-system'

interface SwipeAction {
  /** Label or icon */
  content: ReactNode
  /** Tailwind bg class */
  bgClass?: string
  onClick: () => void
}

interface SwipeableCardProps {
  children: ReactNode
  /** Actions revealed when swiping left */
  leftActions?: SwipeAction[]
  /** Actions revealed when swiping right */
  rightActions?: SwipeAction[]
  /** Swipe threshold before snapping open. Default 80 */
  threshold?: number
  className?: string
}

/**
 * A card that can be swiped horizontally to reveal action buttons.
 */
export default function SwipeableCard({
  children,
  leftActions = [],
  rightActions = [],
  threshold = 80,
  className,
}: SwipeableCardProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [offsetX, setOffsetX] = useState(0)
  const [snapped, setSnapped] = useState<'none' | 'left' | 'right'>('none')
  const startX = useRef(0)
  const startY = useRef(0)
  const tracking = useRef(false)
  const isHorizontal = useRef<boolean | null>(null)

  const maxLeft = leftActions.length * 72
  const maxRight = rightActions.length * 72

  const handleTouchStart = useCallback((e: TouchEvent) => {
    startX.current = e.touches[0].clientX
    startY.current = e.touches[0].clientY
    tracking.current = true
    isHorizontal.current = null
  }, [])

  const handleTouchMove = useCallback(
    (e: TouchEvent) => {
      if (!tracking.current) return
      const dx = e.touches[0].clientX - startX.current
      const dy = e.touches[0].clientY - startY.current

      // Determine primary direction on first substantial move
      if (isHorizontal.current === null) {
        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
          isHorizontal.current = Math.abs(dx) > Math.abs(dy)
        }
        return
      }

      if (!isHorizontal.current) {
        tracking.current = false
        return
      }

      e.preventDefault()

      let newOffset: number
      if (snapped === 'none') {
        newOffset = dx
      } else if (snapped === 'right') {
        newOffset = -maxRight + dx
      } else {
        newOffset = maxLeft + dx
      }

      // Clamp
      newOffset = Math.max(-maxRight, Math.min(maxLeft, newOffset))
      setOffsetX(newOffset)
    },
    [snapped, maxLeft, maxRight]
  )

  const handleTouchEnd = useCallback(() => {
    if (!tracking.current) return
    tracking.current = false

    if (offsetX > threshold && leftActions.length > 0) {
      setOffsetX(maxLeft)
      setSnapped('left')
    } else if (offsetX < -threshold && rightActions.length > 0) {
      setOffsetX(-maxRight)
      setSnapped('right')
    } else {
      setOffsetX(0)
      setSnapped('none')
    }
  }, [offsetX, threshold, leftActions.length, rightActions.length, maxLeft, maxRight])

  const close = useCallback(() => {
    setOffsetX(0)
    setSnapped('none')
  }, [])

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    el.addEventListener('touchstart', handleTouchStart, { passive: true })
    el.addEventListener('touchmove', handleTouchMove, { passive: false })
    el.addEventListener('touchend', handleTouchEnd, { passive: true })

    return () => {
      el.removeEventListener('touchstart', handleTouchStart)
      el.removeEventListener('touchmove', handleTouchMove)
      el.removeEventListener('touchend', handleTouchEnd)
    }
  }, [handleTouchStart, handleTouchMove, handleTouchEnd])

  return (
    <div
      ref={containerRef}
      className={cn('relative overflow-hidden rounded-2xl', className)}
    >
      {/* Left actions (revealed on right swipe) */}
      {leftActions.length > 0 && (
        <div className="absolute inset-y-0 left-0 flex">
          {leftActions.map((action, i) => (
            <button
              key={i}
              className={cn(
                'w-[72px] flex items-center justify-center text-white touch-target',
                action.bgClass || 'bg-primary-500'
              )}
              onClick={() => {
                action.onClick()
                close()
              }}
            >
              {action.content}
            </button>
          ))}
        </div>
      )}

      {/* Right actions (revealed on left swipe) */}
      {rightActions.length > 0 && (
        <div className="absolute inset-y-0 right-0 flex">
          {rightActions.map((action, i) => (
            <button
              key={i}
              className={cn(
                'w-[72px] flex items-center justify-center text-white touch-target',
                action.bgClass || 'bg-red-500'
              )}
              onClick={() => {
                action.onClick()
                close()
              }}
            >
              {action.content}
            </button>
          ))}
        </div>
      )}

      {/* Main content layer */}
      <div
        className="relative bg-white transition-transform duration-200 ease-out will-change-transform"
        style={{ transform: `translateX(${offsetX}px)` }}
      >
        {children}
      </div>
    </div>
  )
}
