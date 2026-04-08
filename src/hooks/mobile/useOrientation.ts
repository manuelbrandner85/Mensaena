'use client'

import { useState, useEffect } from 'react'

export type OrientationType = 'portrait' | 'landscape'

export interface OrientationState {
  type: OrientationType
  angle: number
}

/**
 * Listens to orientation changes via screen.orientation or
 * the legacy `orientationchange` event.
 * Useful for adjusting modals, maps (invalidateSize), safe-area, keyboard heights.
 */
export function useOrientation(): OrientationState {
  const [state, setState] = useState<OrientationState>(() => getOrientation())

  useEffect(() => {
    const update = () => setState(getOrientation())

    if (screen.orientation) {
      screen.orientation.addEventListener('change', update)
    }
    window.addEventListener('orientationchange', update)
    window.addEventListener('resize', update)

    return () => {
      if (screen.orientation) {
        screen.orientation.removeEventListener('change', update)
      }
      window.removeEventListener('orientationchange', update)
      window.removeEventListener('resize', update)
    }
  }, [])

  return state
}

function getOrientation(): OrientationState {
  if (typeof window === 'undefined') {
    return { type: 'portrait', angle: 0 }
  }

  const angle = screen.orientation?.angle ?? (window.orientation as number) ?? 0
  const type: OrientationType = Math.abs(angle) === 90 || Math.abs(angle) === 270
    ? 'landscape'
    : 'portrait'

  return { type, angle }
}

export default useOrientation
