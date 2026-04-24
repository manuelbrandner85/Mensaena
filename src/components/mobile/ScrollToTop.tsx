'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { ArrowUp } from 'lucide-react'
import { cn } from '@/lib/design-system'

interface ScrollToTopProps {
  /** Scroll distance (px) before the button appears. Default 400 */
  threshold?: number
  className?: string
}

/**
 * Floating button that scrolls the page to the top.
 * Positioned responsively: larger on mobile, offset from bottom nav.
 */
export default function ScrollToTop({ threshold = 400, className }: ScrollToTopProps) {
  const [visible, setVisible] = useState(false)
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const handleScroll = useCallback(() => {
    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      setVisible(window.scrollY > threshold)
    }, 100) // debounce 100ms
  }, [threshold])

  useEffect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => {
      window.removeEventListener('scroll', handleScroll)
      if (timer.current) clearTimeout(timer.current)
    }
  }, [handleScroll])

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <button
      onClick={scrollToTop}
      className={cn(
        'fixed z-30 rounded-full bg-white shadow-lg border border-gray-200',
        'text-primary-600 hover:bg-primary-50 active:scale-90',
        'transition-all duration-300 ease-out will-change-transform',
        // Size: larger on mobile
        'w-12 h-12 md:w-10 md:h-10',
        // Position: sits above the bot button (bot is at bottom-20 mobile+tablet, bottom-6 desktop)
        'right-4 bottom-36 md:right-6 lg:bottom-24',
        visible
          ? 'opacity-100 translate-y-0 pointer-events-auto'
          : 'opacity-0 translate-y-4 pointer-events-none',
        className
      )}
      style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
      aria-label="Nach oben scrollen"
    >
      <ArrowUp className="w-5 h-5 mx-auto" />
    </button>
  )
}
