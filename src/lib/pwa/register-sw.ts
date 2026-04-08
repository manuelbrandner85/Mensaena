/* ═══════════════════════════════════════════════════════════════════════
   SERVICE  WORKER  REGISTRATION
   Registers the SW after page load and handles update detection.
   ═══════════════════════════════════════════════════════════════════════ */

let registration: ServiceWorkerRegistration | null = null

/**
 * Register the service worker after the page has loaded.
 * Returns the registration object or null if SW is not supported.
 */
export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if (typeof window === 'undefined' || !('serviceWorker' in navigator)) {
    return null
  }

  // Wait for page load to avoid competing with initial resources
  if (document.readyState !== 'complete') {
    await new Promise<void>((resolve) => {
      window.addEventListener('load', () => resolve(), { once: true })
    })
  }

  try {
    registration = await navigator.serviceWorker.register('/sw.js', {
      scope: '/',
    })

    // Update detection
    registration.addEventListener('updatefound', () => {
      const newWorker = registration?.installing
      if (!newWorker) return

      newWorker.addEventListener('statechange', () => {
        if (
          newWorker.state === 'installed' &&
          navigator.serviceWorker.controller
        ) {
          // A new SW is installed and the old one is still controlling
          window.dispatchEvent(new CustomEvent('sw-update-available'))
        }
      })
    })

    // Periodic update check every 60 minutes
    setInterval(
      () => {
        registration?.update().catch(() => {})
      },
      60 * 60 * 1000,
    )

    return registration
  } catch (err) {
    console.warn('[SW] Registration failed:', err)
    return null
  }
}

/**
 * Send a message to the active service worker.
 */
export function sendMessageToSW(message: Record<string, unknown>): void {
  navigator.serviceWorker?.controller?.postMessage(message)
}

/**
 * Get the current service worker registration.
 */
export function getRegistration(): ServiceWorkerRegistration | null {
  return registration
}
