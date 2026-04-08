'use client'

import { useState, useEffect, useRef } from 'react'

export interface KeyboardState {
  /** true when the virtual keyboard is likely visible */
  isOpen: boolean
  /** Estimated keyboard height in px (0 when closed) */
  keyboardHeight: number
}

/**
 * Detect the virtual (on-screen) keyboard.
 *
 * Primary method: VisualViewport API (modern iOS/Android).
 * Fallback: focus/blur on input/textarea elements.
 */
export function useKeyboard(): KeyboardState {
  const [state, setState] = useState<KeyboardState>({
    isOpen: false,
    keyboardHeight: 0,
  })

  // Track the initial viewport height so we can calculate delta
  const initialHeight = useRef(0)

  useEffect(() => {
    if (typeof window === 'undefined') return

    initialHeight.current = window.innerHeight

    // ── VisualViewport approach ──
    if (window.visualViewport) {
      const vv = window.visualViewport

      const onResize = () => {
        const currentHeight = vv.height
        const diff = initialHeight.current - currentHeight

        // Threshold: keyboard is open if the difference > 150 px
        if (diff > 150) {
          setState({ isOpen: true, keyboardHeight: diff })
        } else {
          setState({ isOpen: false, keyboardHeight: 0 })
        }
      }

      vv.addEventListener('resize', onResize)
      vv.addEventListener('scroll', onResize)

      return () => {
        vv.removeEventListener('resize', onResize)
        vv.removeEventListener('scroll', onResize)
      }
    }

    // ── Fallback: focus/blur ──
    const onFocus = (e: FocusEvent) => {
      const tag = (e.target as HTMLElement)?.tagName?.toLowerCase()
      if (tag === 'input' || tag === 'textarea' || tag === 'select') {
        // Slight delay so the keyboard finishes opening
        setTimeout(() => {
          setState({
            isOpen: true,
            keyboardHeight: Math.max(0, initialHeight.current - window.innerHeight),
          })
        }, 300)
      }
    }

    const onBlur = () => {
      setTimeout(() => {
        setState({ isOpen: false, keyboardHeight: 0 })
      }, 100)
    }

    document.addEventListener('focusin', onFocus, { passive: true })
    document.addEventListener('focusout', onBlur, { passive: true })

    return () => {
      document.removeEventListener('focusin', onFocus)
      document.removeEventListener('focusout', onBlur)
    }
  }, [])

  return state
}

export default useKeyboard
