'use client'

import { useState, useEffect } from 'react'

export interface SafeAreaInsets {
  top: number
  right: number
  bottom: number
  left: number
}

/**
 * Reads env(safe-area-inset-*) values from computed CSS vars.
 * Also injects CSS custom properties (--sai-top, --sai-right, --sai-bottom, --sai-left)
 * onto document.documentElement so they can be used anywhere.
 */
export function useSafeArea(): SafeAreaInsets {
  const [insets, setInsets] = useState<SafeAreaInsets>({
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
  })

  useEffect(() => {
    if (typeof window === 'undefined') return

    const measure = () => {
      const style = getComputedStyle(document.documentElement)
      const parse = (prop: string): number => {
        const raw = style.getPropertyValue(prop).trim()
        return parseFloat(raw) || 0
      }

      const top = parse('--sai-top')
      const right = parse('--sai-right')
      const bottom = parse('--sai-bottom')
      const left = parse('--sai-left')

      setInsets({ top, right, bottom, left })
    }

    // Allow env() values to settle
    const raf = requestAnimationFrame(() => {
      measure()
    })

    window.addEventListener('resize', measure, { passive: true })
    window.addEventListener('orientationchange', measure, { passive: true })

    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', measure)
      window.removeEventListener('orientationchange', measure)
    }
  }, [])

  return insets
}

export default useSafeArea
