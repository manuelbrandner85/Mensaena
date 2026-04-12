'use client'

import { useState, useRef, useCallback, useEffect } from 'react'
import { X, ChevronLeft, ChevronRight } from 'lucide-react'
import { cn } from '@/lib/design-system'

interface MobileImageViewerProps {
  images: string[]
  initialIndex?: number
  open: boolean
  onClose: () => void
  alt?: string
}

/**
 * Fullscreen image viewer with pinch-to-zoom and swipe navigation.
 * Swipe down to close.
 */
export default function MobileImageViewer({
  images,
  initialIndex = 0,
  open,
  onClose,
  alt = 'Bild',
}: MobileImageViewerProps) {
  const [currentIndex, setCurrentIndex] = useState(initialIndex)
  const [scale, setScale] = useState(1)
  const [translateY, setTranslateY] = useState(0)
  const [isDismissing, setIsDismissing] = useState(false)

  const containerRef = useRef<HTMLDivElement>(null)
  const initialDistance = useRef(0)
  const initialScale = useRef(1)
  const startY = useRef(0)
  const tracking = useRef(false)

  // Reset on open/close
  useEffect(() => {
    if (open) {
      setCurrentIndex(initialIndex)
      setScale(1)
      setTranslateY(0)
      setIsDismissing(false)
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [open, initialIndex])

  // ── Pinch to zoom ──
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX
      const dy = e.touches[0].clientY - e.touches[1].clientY
      initialDistance.current = Math.hypot(dx, dy)
      initialScale.current = scale
    } else if (e.touches.length === 1 && scale <= 1) {
      startY.current = e.touches[0].clientY
      tracking.current = true
    }
  }, [scale])

  const handleTouchMove = useCallback(
    (e: React.TouchEvent) => {
      if (e.touches.length === 2) {
        const dx = e.touches[0].clientX - e.touches[1].clientX
        const dy = e.touches[0].clientY - e.touches[1].clientY
        const dist = Math.hypot(dx, dy)
        const newScale = Math.min(5, Math.max(0.5, initialScale.current * (dist / initialDistance.current)))
        setScale(newScale)
      } else if (e.touches.length === 1 && tracking.current && scale <= 1) {
        const dy = e.touches[0].clientY - startY.current
        if (dy > 0) {
          setTranslateY(dy * 0.6)
          setIsDismissing(dy > 100)
        }
      }
    },
    [scale]
  )

  const handleTouchEnd = useCallback(() => {
    if (isDismissing) {
      onClose()
    } else {
      setTranslateY(0)
      setIsDismissing(false)
      if (scale < 1) setScale(1)
    }
    tracking.current = false
  }, [isDismissing, onClose, scale])

  // ── Navigation ──
  const prev = () => setCurrentIndex((i) => Math.max(0, i - 1))
  const next = () => setCurrentIndex((i) => Math.min(images.length - 1, i + 1))

  // Keyboard
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft') prev()
      if (e.key === 'ArrowRight') next()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open || images.length === 0) return null

  return (
    <div
      ref={containerRef}
      className="fixed inset-0 z-[100] bg-black flex items-center justify-center"
      role="dialog"
      aria-modal="true"
      aria-label="Bild-Vollansicht"
    >
      {/* Overlay opacity based on dismiss gesture */}
      <div
        className="absolute inset-0 bg-black transition-opacity duration-150"
        style={{ opacity: 1 - translateY / 400 }}
      />

      {/* Close button */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 z-10 touch-target p-3 rounded-full bg-black/40 text-white backdrop-blur-sm"
        aria-label="Schließen"
        style={{ top: 'max(1rem, env(safe-area-inset-top))' }}
      >
        <X className="w-5 h-5" />
      </button>

      {/* Image counter */}
      {images.length > 1 && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-10 px-3 py-1 rounded-full bg-black/40 text-white text-sm backdrop-blur-sm">
          {currentIndex + 1} / {images.length}
        </div>
      )}

      {/* Image */}
      <div
        className="relative z-[1] w-full h-full flex items-center justify-center touch-none select-none"
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={images[currentIndex]}
          alt={`${alt} ${currentIndex + 1}`}
          className="max-w-full max-h-full object-contain transition-transform duration-150"
          style={{
            transform: `scale(${scale}) translateY(${translateY}px)`,
          }}
          draggable={false}
        />
      </div>

      {/* Nav arrows (desktop / multi-image) */}
      {images.length > 1 && (
        <>
          <button
            onClick={prev}
            disabled={currentIndex === 0}
            className={cn(
              'absolute left-2 top-1/2 -translate-y-1/2 z-10 touch-target p-3 rounded-full bg-black/40 text-white backdrop-blur-sm transition-opacity',
              currentIndex === 0 && 'opacity-30 pointer-events-none'
            )}
            aria-label="Vorheriges Bild"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <button
            onClick={next}
            disabled={currentIndex === images.length - 1}
            className={cn(
              'absolute right-2 top-1/2 -translate-y-1/2 z-10 touch-target p-3 rounded-full bg-black/40 text-white backdrop-blur-sm transition-opacity',
              currentIndex === images.length - 1 && 'opacity-30 pointer-events-none'
            )}
            aria-label="Nächstes Bild"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </>
      )}
    </div>
  )
}
