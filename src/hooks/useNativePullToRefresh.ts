'use client'

import { useEffect } from 'react'

/**
 * Native pull-to-refresh hook for the Capacitor APK.
 *
 * Listens to touchstart/move/end on the window. Activation conditions:
 *  - <html> must carry the `is-native` class (set by NativeBridge.tsx)
 *  - the page must be at the absolute top (window.scrollY === 0) when the
 *    touch starts
 *  - the touch target (and ancestors) must NOT carry data-no-pull-refresh="true"
 *  - the touch target must NOT live inside a non-body scroll container with
 *    overflow-y: auto | scroll
 *
 * When the user pulls down by more than 80px a fixed indicator (teal pill
 * with a spinning Loader2 icon) appears. On release at >80px the page is
 * reloaded via `window.location.reload()`.
 *
 * Browser (non-native) builds short-circuit on the first conditional and
 * never attach listeners.
 */
export function useNativePullToRefresh(): void {
  useEffect(() => {
    if (typeof document === 'undefined') return
    if (!document.documentElement.classList.contains('is-native')) return

    const TRIGGER_DISTANCE = 80
    const MAX_DISTANCE = 160

    let startY = 0
    let activeTouch = false
    let indicator: HTMLDivElement | null = null

    /** Walks up the DOM from `el` looking for an ancestor that disables P2R. */
    const isInsideNoPullElement = (el: Element | null): boolean => {
      let cur: Element | null = el
      while (cur && cur !== document.body) {
        if (cur.getAttribute('data-no-pull-refresh') === 'true') return true
        cur = cur.parentElement
      }
      return false
    }

    /** Returns true when an ancestor is itself a vertical scroll container. */
    const isInsideScrollContainer = (el: Element | null): boolean => {
      let cur: Element | null = el
      while (cur && cur !== document.body && cur !== document.documentElement) {
        const style = window.getComputedStyle(cur)
        const oy = style.overflowY
        if ((oy === 'auto' || oy === 'scroll') && cur.scrollHeight > cur.clientHeight) {
          return true
        }
        cur = cur.parentElement
      }
      return false
    }

    /** Lazily creates / removes the floating refresh indicator. */
    const ensureIndicator = (): HTMLDivElement => {
      if (indicator) return indicator
      const el = document.createElement('div')
      el.setAttribute('aria-hidden', 'true')
      el.style.cssText = [
        'position:fixed',
        'top:16px',
        'left:50%',
        'transform:translateX(-50%) translateY(-60px)',
        'width:40px',
        'height:40px',
        'border-radius:9999px',
        'background:rgba(30,170,166,0.9)',
        'box-shadow:0 8px 24px rgba(20,113,112,0.35)',
        'display:flex',
        'align-items:center',
        'justify-content:center',
        'z-index:99999',
        'transition:transform 120ms ease-out, opacity 120ms ease-out',
        'opacity:0',
        'pointer-events:none',
      ].join(';')
      // Inline SVG (Loader2 from lucide) — avoids new imports inside the listener.
      el.innerHTML =
        '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" ' +
        'fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" ' +
        'stroke-linejoin="round" style="animation:spin 1s linear infinite">' +
        '<path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>'
      document.body.appendChild(el)
      indicator = el
      return el
    }

    const removeIndicator = (): void => {
      if (!indicator) return
      indicator.remove()
      indicator = null
    }

    const onTouchStart = (e: TouchEvent): void => {
      if (window.scrollY > 0) return
      const touch = e.touches[0]
      if (!touch) return
      const target = touch.target as Element | null
      if (isInsideNoPullElement(target)) return
      if (isInsideScrollContainer(target)) return
      startY = touch.clientY
      activeTouch = true
    }

    const onTouchMove = (e: TouchEvent): void => {
      if (!activeTouch) return
      const touch = e.touches[0]
      if (!touch) return
      const dy = touch.clientY - startY
      if (dy <= 0) return
      const clamped = Math.min(dy, MAX_DISTANCE)
      const el = ensureIndicator()
      const reached = clamped > TRIGGER_DISTANCE
      el.style.opacity = reached ? '1' : String(clamped / TRIGGER_DISTANCE)
      el.style.transform = `translateX(-50%) translateY(${reached ? 0 : clamped - 60}px)`
    }

    const onTouchEnd = (e: TouchEvent): void => {
      if (!activeTouch) return
      activeTouch = false
      const touch = e.changedTouches[0]
      const dy = touch ? touch.clientY - startY : 0
      if (dy > TRIGGER_DISTANCE) {
        // Keep indicator on screen until reload kicks in
        const el = ensureIndicator()
        el.style.opacity = '1'
        el.style.transform = 'translateX(-50%) translateY(0)'
        window.location.reload()
        return
      }
      removeIndicator()
    }

    window.addEventListener('touchstart', onTouchStart, { passive: true })
    window.addEventListener('touchmove', onTouchMove, { passive: true })
    window.addEventListener('touchend', onTouchEnd, { passive: true })
    window.addEventListener('touchcancel', onTouchEnd, { passive: true })

    return () => {
      window.removeEventListener('touchstart', onTouchStart)
      window.removeEventListener('touchmove', onTouchMove)
      window.removeEventListener('touchend', onTouchEnd)
      window.removeEventListener('touchcancel', onTouchEnd)
      removeIndicator()
    }
  }, [])
}
