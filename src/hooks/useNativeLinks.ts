'use client'

import { useEffect } from 'react'

/** Hosts that count as the Mensaena origin and should stay inside the WebView. */
const MENSAENA_ORIGINS = [
  'https://www.mensaena.de',
  'https://mensaena.de',
] as const

/**
 * Native-only document-level click interceptor. When the Capacitor APK is
 * running (detected via the `is-native` class), any anchor click whose
 * `href` points to an external `http(s)://` origin is intercepted and
 * routed to the system browser via `window.open(href, '_system')`.
 *
 * Internal Mensaena links and `mailto:` / `tel:` schemes are left alone so
 * Next.js routing and native intents continue to work.
 *
 * Browser builds short-circuit at the first conditional — no listeners
 * are attached.
 */
export function useNativeLinks(): void {
  useEffect(() => {
    if (typeof document === 'undefined') return
    if (!document.documentElement.classList.contains('is-native')) return

    const onClick = (event: MouseEvent): void => {
      // Ignore if a modifier is pressed — the user may want a new tab elsewhere.
      if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

      const target = event.target as Element | null
      if (!target) return
      const anchor = target.closest('a')
      if (!anchor) return

      const href = anchor.getAttribute('href')
      if (!href) return

      // mailto: / tel: → let native intents handle them
      if (href.startsWith('mailto:') || href.startsWith('tel:')) return

      if (!href.startsWith('http://') && !href.startsWith('https://')) return

      // Mensaena origin → keep inside the WebView (Next.js routing)
      if (MENSAENA_ORIGINS.some(origin => href.startsWith(origin))) return

      // Anything else: open in the system browser
      event.preventDefault()
      window.open(href, '_system')
    }

    document.addEventListener('click', onClick, true)
    return () => document.removeEventListener('click', onClick, true)
  }, [])
}
