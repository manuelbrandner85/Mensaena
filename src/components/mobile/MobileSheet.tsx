'use client'

import { ReactNode, useRef, useState, useCallback, useEffect } from 'react'
import { X } from 'lucide-react'
import { cn } from '@/lib/design-system'

interface MobileSheetProps {
  open: boolean
  onClose: () => void
  children: ReactNode
  title?: string
  /** Snap points as % of viewport height. Default [50, 90] */
  snapPoints?: number[]
  /** Allow closing by dragging down. Default true */
  dragToClose?: boolean
  className?: string
}

/**
 * Bottom-sheet component with drag handle, snap-points, and safe-area padding.
 */
export default function MobileSheet({
  open,
  onClose,
  children,
  title,
  snapPoints = [50, 90],
  dragToClose = true,
  className,
}: MobileSheetProps) {
  const sheetRef = useRef<HTMLDivElement>(null)
  const [snapIndex, setSnapIndex] = useState(0)
  const [dragOffset, setDragOffset] = useState(0)
  const [isDragging, setIsDragging] = useState(false)
  const startY = useRef(0)
  const startOffset = useRef(0)

  // Reset on open
  useEffect(() => {
    if (open) {
      setSnapIndex(0)
      setDragOffset(0)
    }
  }, [open])

  // Prevent body scroll when sheet is open
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden'
      return () => {
        document.body.style.overflow = ''
      }
    }
  }, [open])

  const currentSnap = snapPoints[snapIndex] ?? snapPoints[0]
  const sheetHeight = `${currentSnap}vh`

  const handleTouchStart = useCallback(
    (e: React.TouchEvent) => {
      startY.current = e.touches[0].clientY
      startOffset.current = dragOffset
      setIsDragging(true)
    },
    [dragOffset]
  )

  const handleTouchMove = useCallback(
    (e: React.TouchEvent) => {
      if (!isDragging) return
      const dy = e.touches[0].clientY - startY.current
      // Only allow drag downward from handle, or both directions
      setDragOffset(Math.max(0, startOffset.current + dy))
    },
    [isDragging]
  )

  const handleTouchEnd = useCallback(() => {
    setIsDragging(false)

    const vh = window.innerHeight
    const closePx = (currentSnap / 100) * vh * 0.3 // 30% = dismiss threshold

    if (dragToClose && dragOffset > closePx) {
      onClose()
      setDragOffset(0)
      return
    }

    // Snap up/down based on drag direction
    if (dragOffset > 40 && snapIndex > 0) {
      setSnapIndex(snapIndex - 1)
    } else if (dragOffset < -40 && snapIndex < snapPoints.length - 1) {
      setSnapIndex(snapIndex + 1)
    }

    setDragOffset(0)
  }, [dragOffset, dragToClose, snapIndex, snapPoints.length, currentSnap, onClose])

  if (!open) return null

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm transition-opacity duration-300"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Sheet */}
      <div
        ref={sheetRef}
        className={cn(
          'fixed bottom-0 left-0 right-0 z-50',
          'bg-white rounded-t-3xl shadow-xl',
          'flex flex-col',
          !isDragging && 'transition-all duration-300 ease-out',
          className
        )}
        style={{
          height: sheetHeight,
          transform: `translateY(${dragOffset}px)`,
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
        role="dialog"
        aria-modal="true"
        aria-label={title || 'Bottom sheet'}
      >
        {/* Drag handle */}
        <div
          className="flex-shrink-0 pt-3 pb-2 px-4 cursor-grab active:cursor-grabbing touch-none"
          onTouchStart={handleTouchStart}
          onTouchMove={handleTouchMove}
          onTouchEnd={handleTouchEnd}
        >
          <div className="w-10 h-1.5 bg-gray-300 rounded-full mx-auto" />
        </div>

        {/* Header */}
        {title && (
          <div className="flex-shrink-0 flex items-center justify-between px-5 pb-3 border-b border-gray-100">
            <h2 className="text-lg font-bold text-gray-900">{title}</h2>
            <button
              onClick={onClose}
              className="touch-target p-2 rounded-xl text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
              aria-label="Schließen"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-y-auto overscroll-contain px-5 py-4">
          {children}
        </div>
      </div>
    </>
  )
}
