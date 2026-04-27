/**
 * Haptic feedback helpers.
 *
 * In the Capacitor APK we use the @capacitor/haptics plugin, which
 * triggers Android's HapticFeedbackConstants for a clean tap (not
 * the rough vibration motor buzz that navigator.vibrate produces).
 *
 * On the open web we fall back to the Web Vibration API.
 * On unsupported devices these are silent no-ops.
 */

function isCapacitorNative(): boolean {
  if (typeof window === 'undefined') return false
  const cap = (window as unknown as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor
  return cap?.isNativePlatform?.() ?? false
}

async function nativeImpact(style: 'Light' | 'Medium' | 'Heavy') {
  try {
    const { Haptics, ImpactStyle } = await import('@capacitor/haptics')
    await Haptics.impact({ style: ImpactStyle[style] })
  } catch {
    // plugin not bundled or runtime mismatch – ignore
  }
}

async function nativeNotification(type: 'Success' | 'Warning' | 'Error') {
  try {
    const { Haptics, NotificationType } = await import('@capacitor/haptics')
    await Haptics.notification({ type: NotificationType[type] })
  } catch {
    // ignore
  }
}

async function nativeSelection() {
  try {
    const { Haptics } = await import('@capacitor/haptics')
    await Haptics.selectionStart()
    await Haptics.selectionChanged()
    await Haptics.selectionEnd()
  } catch {
    // ignore
  }
}

function webVibrate(durationOrPattern: number | number[]): void {
  try {
    if (typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate(durationOrPattern)
    }
  } catch {
    // ignore
  }
}

/**
 * Soft selection-style tap. Use on every primary tap (button click,
 * tab switch, toggle). Almost imperceptible but makes the UI feel native.
 */
export function hapticSelection(): void {
  if (isCapacitorNative()) {
    void nativeSelection()
    return
  }
  webVibrate(5)
}

/**
 * Standard tap feedback. Use for confirming actions.
 */
export function hapticFeedback(durationMs = 10): void {
  if (isCapacitorNative()) {
    void nativeImpact('Light')
    return
  }
  webVibrate(durationMs)
}

/**
 * Success pattern (two short pulses on web, native success on Capacitor).
 */
export function hapticSuccess(): void {
  if (isCapacitorNative()) {
    void nativeNotification('Success')
    return
  }
  webVibrate([10, 50, 10])
}

/**
 * Error pattern (one long pulse on web, native error on Capacitor).
 */
export function hapticError(): void {
  if (isCapacitorNative()) {
    void nativeNotification('Error')
    return
  }
  webVibrate(40)
}

/**
 * Warning pattern – use for soft confirmations (e.g. delete request).
 */
export function hapticWarning(): void {
  if (isCapacitorNative()) {
    void nativeNotification('Warning')
    return
  }
  webVibrate([20, 40, 20])
}

/**
 * Heavier impact for high-importance actions (e.g. emergency / crisis).
 */
export function hapticImpact(strength: 'light' | 'medium' | 'heavy' = 'medium'): void {
  if (isCapacitorNative()) {
    void nativeImpact(strength === 'light' ? 'Light' : strength === 'heavy' ? 'Heavy' : 'Medium')
    return
  }
  webVibrate(strength === 'light' ? 8 : strength === 'heavy' ? 30 : 15)
}
