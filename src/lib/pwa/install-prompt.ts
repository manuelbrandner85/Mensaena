/* ═══════════════════════════════════════════════════════════════════════
   INSTALL  PROMPT  LOGIC
   Manages dismiss cooldown and visibility rules.
   ═══════════════════════════════════════════════════════════════════════ */

const DISMISS_KEY = 'mensaena-install-dismissed'
const DISMISS_PERMANENT_KEY = 'mensaena-install-never'
const DISMISS_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000 // 7 days

/**
 * Check if the install prompt should be shown.
 */
export function shouldShowInstallPrompt(): boolean {
  if (typeof window === 'undefined') return false

  // Permanently dismissed
  if (localStorage.getItem(DISMISS_PERMANENT_KEY) === 'true') return false

  // Recently dismissed
  const dismissedAt = localStorage.getItem(DISMISS_KEY)
  if (dismissedAt) {
    const elapsed = Date.now() - parseInt(dismissedAt, 10)
    if (elapsed < DISMISS_COOLDOWN_MS) return false
  }

  return true
}

/**
 * Mark the install prompt as dismissed (7-day cooldown).
 */
export function dismissInstallPrompt(): void {
  localStorage.setItem(DISMISS_KEY, String(Date.now()))
}

/**
 * Permanently dismiss the install prompt.
 */
export function permanentlyDismissInstallPrompt(): void {
  localStorage.setItem(DISMISS_PERMANENT_KEY, 'true')
}
