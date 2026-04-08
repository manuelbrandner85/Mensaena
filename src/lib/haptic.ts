/**
 * Trigger a short haptic vibration if supported.
 * Falls back silently on unsupported devices.
 */
export function hapticFeedback(durationMs = 10): void {
  try {
    if (typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate(durationMs)
    }
  } catch {
    // Silently ignore – no haptic support
  }
}

/**
 * Trigger a success-pattern haptic (two short pulses).
 */
export function hapticSuccess(): void {
  try {
    if (typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate([10, 50, 10])
    }
  } catch {
    // Silently ignore
  }
}

/**
 * Trigger an error-pattern haptic (one longer pulse).
 */
export function hapticError(): void {
  try {
    if (typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate(40)
    }
  } catch {
    // Silently ignore
  }
}
