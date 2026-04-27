/**
 * Native OS share sheet (Web Share API).
 *
 * Mobile (iOS/Android/Capacitor): opens system share sheet with WhatsApp,
 * Telegram, SMS, Mail, etc.
 * Desktop: most browsers support navigator.share too (Chrome 89+, Edge 93+,
 * Safari). Falls back to clipboard copy.
 *
 * Returns 'shared' | 'copied' | 'cancelled' | 'unsupported'.
 */
export type ShareResult = 'shared' | 'copied' | 'cancelled' | 'unsupported'

export interface ShareData {
  title: string
  text: string
  url?: string
}

export async function nativeShare(data: ShareData): Promise<ShareResult> {
  // Web Share API path
  if (typeof navigator !== 'undefined' && 'share' in navigator) {
    try {
      await navigator.share({
        title: data.title,
        text: data.text,
        url: data.url,
      })
      return 'shared'
    } catch (err) {
      // User cancelled is not an error worth surfacing
      if (err instanceof Error && err.name === 'AbortError') return 'cancelled'
      // Fall through to clipboard fallback
    }
  }

  // Clipboard fallback
  if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
    try {
      const composite = [data.text, data.url].filter(Boolean).join('\n')
      await navigator.clipboard.writeText(composite)
      return 'copied'
    } catch {
      return 'unsupported'
    }
  }

  return 'unsupported'
}
