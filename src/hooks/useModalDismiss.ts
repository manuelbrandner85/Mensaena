'use client'

import { useEffect, useRef } from 'react'

/**
 * Wires multiple "back to where I was" gestures to a single close handler:
 *   - ESC key (desktop)
 *   - Browser back button + Android hardware back button (via history popstate)
 *
 * On mount: pushes a sentinel history entry. On dismiss via back button:
 * popstate fires, we call onClose. On dismiss via ESC / X / backdrop:
 * we go back manually so the sentinel doesn't pile up in history.
 *
 * Pass `enabled: false` (e.g. while a nested modal is open) to skip — the
 * inner modal handles its own dismiss first.
 */
export function useModalDismiss(onClose: () => void, enabled: boolean = true) {
  const onCloseRef = useRef(onClose)
  onCloseRef.current = onClose

  useEffect(() => {
    if (!enabled) return
    if (typeof window === 'undefined') return

    // Push a sentinel state so the next back-press fires popstate
    // instead of leaving the app/page.
    window.history.pushState({ __mensaenaModal: true }, '')

    let dismissedByBack = false

    const onPop = () => {
      dismissedByBack = true
      onCloseRef.current()
    }

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation()
        // Going back will trigger popstate which will close us
        window.history.back()
      }
    }

    window.addEventListener('popstate', onPop)
    document.addEventListener('keydown', onKey)

    return () => {
      window.removeEventListener('popstate', onPop)
      document.removeEventListener('keydown', onKey)
      // If unmounting via X / backdrop / parent state change (NOT back button),
      // pop the sentinel so the user's history is clean.
      if (!dismissedByBack) {
        try {
          if (window.history.state?.__mensaenaModal) {
            window.history.back()
          }
        } catch { /* noop */ }
      }
    }
  }, [enabled])
}
