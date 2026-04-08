'use client'

import { useRef, useCallback } from 'react'

/**
 * Prevents accidental double-tap by disabling a callback for `delay` ms after it fires.
 * Returns a wrapped callback that ignores repeat invocations.
 */
export function useDoubleTapGuard<T extends (...args: unknown[]) => void>(
  callback: T,
  delay = 500
): T {
  const lastCall = useRef(0)

  const guarded = useCallback(
    (...args: unknown[]) => {
      const now = Date.now()
      if (now - lastCall.current < delay) return
      lastCall.current = now
      callback(...args)
    },
    [callback, delay]
  ) as T

  return guarded
}

export default useDoubleTapGuard
