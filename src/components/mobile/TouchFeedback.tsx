'use client'

import { ReactNode, useState, useCallback, useRef } from 'react'
import { cn } from '@/lib/design-system'

interface TouchFeedbackProps {
  children: ReactNode
  /** Scale factor on press. Default 0.97 */
  scale?: number
  /** Opacity on press. Default 0.85 */
  opacity?: number
  /** Optional haptic vibration duration (ms). 0 = disabled. Default 10 */
  hapticMs?: number
  className?: string
  disabled?: boolean
  onClick?: () => void
  /** Element tag. Default div */
  as?: 'div' | 'button'
}

/**
 * Adds subtle scale + opacity feedback on touch-down.
 * Optionally triggers haptic vibration.
 */
export default function TouchFeedback({
  children,
  scale = 0.97,
  opacity = 0.85,
  hapticMs = 10,
  className,
  disabled = false,
  onClick,
  as: Tag = 'div',
}: TouchFeedbackProps) {
  const [pressed, setPressed] = useState(false)
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const handlePressStart = useCallback(() => {
    if (disabled) return
    setPressed(true)
    if (hapticMs > 0 && navigator.vibrate) {
      navigator.vibrate(hapticMs)
    }
  }, [disabled, hapticMs])

  const handlePressEnd = useCallback(() => {
    // Small delay so the user sees the feedback
    timer.current = setTimeout(() => setPressed(false), 80)
  }, [])

  return (
    <Tag
      className={cn(
        'transition-all duration-100 ease-out will-change-transform',
        className
      )}
      style={{
        transform: pressed ? `scale(${scale})` : 'scale(1)',
        opacity: pressed ? opacity : 1,
      }}
      onTouchStart={handlePressStart}
      onTouchEnd={handlePressEnd}
      onTouchCancel={handlePressEnd}
      onMouseDown={handlePressStart}
      onMouseUp={handlePressEnd}
      onMouseLeave={() => setPressed(false)}
      onClick={onClick}
      role={Tag === 'div' && onClick ? 'button' : undefined}
      tabIndex={Tag === 'div' && onClick ? 0 : undefined}
    >
      {children}
    </Tag>
  )
}
