'use client'

import { useState, useEffect, useCallback, useRef } from 'react'

export interface MobileInfo {
  /** true when viewport ≤ 767 px */
  isMobile: boolean
  /** true when viewport 768–1023 px */
  isTablet: boolean
  /** true when viewport ≥ 1024 px */
  isDesktop: boolean
  /** true if primary input supports coarse pointer (finger) */
  isTouchDevice: boolean
  /** Current inner height (accounts for mobile browser chrome) */
  viewportHeight: number
  /** true when device is rotated to landscape */
  isLandscape: boolean
  /** Detected via UA or navigator.platform */
  isIOS: boolean
  /** Detected via UA */
  isAndroid: boolean
  /** true when running as a standalone PWA */
  isPWA: boolean
}

const MOBILE_BP = 767
const TABLET_BP = 1023
const DEBOUNCE_MS = 100

/**
 * Comprehensive device-detection hook.
 * Debounces resize events at 100 ms.
 */
export function useMobile(): MobileInfo {
  const [info, setInfo] = useState<MobileInfo>(() => getDeviceInfo())
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const handleResize = useCallback(() => {
    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      setInfo(getDeviceInfo())
    }, DEBOUNCE_MS)
  }, [])

  useEffect(() => {
    window.addEventListener('resize', handleResize, { passive: true })
    window.addEventListener('orientationchange', handleResize, { passive: true })

    // Initial measure once DOM is ready
    setInfo(getDeviceInfo())

    return () => {
      window.removeEventListener('resize', handleResize)
      window.removeEventListener('orientationchange', handleResize)
      if (timer.current) clearTimeout(timer.current)
    }
  }, [handleResize])

  return info
}

function getDeviceInfo(): MobileInfo {
  if (typeof window === 'undefined') {
    return {
      isMobile: false,
      isTablet: false,
      isDesktop: true,
      isTouchDevice: false,
      viewportHeight: 800,
      isLandscape: false,
      isIOS: false,
      isAndroid: false,
      isPWA: false,
    }
  }

  const w = window.innerWidth
  const h = window.innerHeight
  const ua = navigator.userAgent || ''

  const isTouchDevice =
    'ontouchstart' in window ||
    navigator.maxTouchPoints > 0 ||
    window.matchMedia('(pointer: coarse)').matches

  const isIOS =
    /iPad|iPhone|iPod/.test(ua) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)

  const isAndroid = /Android/i.test(ua)

  const isPWA =
    window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as unknown as { standalone?: boolean }).standalone === true

  return {
    isMobile: w <= MOBILE_BP,
    isTablet: w > MOBILE_BP && w <= TABLET_BP,
    isDesktop: w > TABLET_BP,
    isTouchDevice,
    viewportHeight: h,
    isLandscape: w > h,
    isIOS,
    isAndroid,
    isPWA,
  }
}

export default useMobile
