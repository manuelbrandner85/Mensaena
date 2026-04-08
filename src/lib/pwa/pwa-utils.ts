/* ═══════════════════════════════════════════════════════════════════════
   PWA  UTILITIES
   ═══════════════════════════════════════════════════════════════════════ */

/**
 * Convert a Base64-URL VAPID key to a Uint8Array for applicationServerKey.
 */
export function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

/**
 * Check if the app is running in standalone (installed PWA) mode.
 */
export function isStandalone(): boolean {
  if (typeof window === 'undefined') return false
  return (
    window.matchMedia('(display-mode: standalone)').matches ||
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (navigator as any).standalone === true ||
    document.referrer.includes('android-app://')
  )
}

/**
 * Check if the browser supports PWA installation.
 */
export function canInstallPWA(): boolean {
  if (typeof window === 'undefined') return false
  // Chromium-based browsers fire beforeinstallprompt
  // iOS Safari doesn't but supports Add to Home Screen manually
  return 'serviceWorker' in navigator
}

/**
 * Check if Push API + Notification API are available.
 */
export function isPushSupported(): boolean {
  if (typeof window === 'undefined') return false
  return (
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  )
}

/**
 * Get the current notification permission status.
 */
export function getNotificationPermission(): NotificationPermission {
  if (typeof window === 'undefined' || !('Notification' in window)) {
    return 'default'
  }
  return Notification.permission
}
