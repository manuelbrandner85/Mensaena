'use client'

import { useMemo, useRef } from 'react'

/**
 * Stable interface returned by {@link useHaptic}. Each method is a no-op
 * when running outside the Capacitor APK (i.e. in the browser) or when
 * `@capacitor/haptics` happens to throw at runtime.
 */
export interface HapticActions {
  /** Soft, lightweight tap — e.g. tab switch, badge change, reaction. */
  light: () => void
  /** Medium tap — e.g. submit, primary CTA. */
  medium: () => void
  /** Heavy thump — e.g. starting a call, destructive action. */
  heavy: () => void
  /** Notification: success — e.g. message sent. */
  success: () => void
  /** Notification: warning — e.g. delete confirmation. */
  warning: () => void
  /** Notification: error — e.g. failed action. */
  error: () => void
  /** Selection click — e.g. picker / segmented control. */
  selection: () => void
}

/**
 * React hook that exposes a small set of haptic-feedback helpers backed by
 * `@capacitor/haptics`. All methods short-circuit when the page is NOT
 * running inside the Capacitor APK (detected via the `is-native` class on
 * `<html>` set by NativeBridge.tsx), so calling them on the web is safe and
 * has no overhead other than a class lookup.
 *
 * The Capacitor module is dynamically imported the first time a method is
 * called — this keeps the web bundle slim.
 */
export function useHaptic(): HapticActions {
  const isNativeRef = useRef<boolean | null>(null)

  return useMemo<HapticActions>(() => {
    /** Lazily resolved boolean — cached across calls. */
    const isNative = (): boolean => {
      if (isNativeRef.current !== null) return isNativeRef.current
      if (typeof document === 'undefined') {
        isNativeRef.current = false
        return false
      }
      isNativeRef.current = document.documentElement.classList.contains('is-native')
      return isNativeRef.current
    }

    /** Triggers Capacitor `Haptics.impact(...)` with the given style name. */
    const impact = async (style: 'Light' | 'Medium' | 'Heavy'): Promise<void> => {
      if (!isNative()) return
      try {
        const { Haptics, ImpactStyle } = await import('@capacitor/haptics')
        await Haptics.impact({ style: ImpactStyle[style] })
      } catch {
        /* haptics not available on this device */
      }
    }

    /** Triggers Capacitor `Haptics.notification(...)` with the given type. */
    const notify = async (type: 'Success' | 'Warning' | 'Error'): Promise<void> => {
      if (!isNative()) return
      try {
        const { Haptics, NotificationType } = await import('@capacitor/haptics')
        await Haptics.notification({ type: NotificationType[type] })
      } catch {
        /* haptics not available on this device */
      }
    }

    /** Picker-style selection feedback (start → changed → end). */
    const selectionTick = async (): Promise<void> => {
      if (!isNative()) return
      try {
        const { Haptics } = await import('@capacitor/haptics')
        await Haptics.selectionStart()
        await Haptics.selectionChanged()
        await Haptics.selectionEnd()
      } catch {
        /* haptics not available on this device */
      }
    }

    return {
      light:     () => { void impact('Light') },
      medium:    () => { void impact('Medium') },
      heavy:     () => { void impact('Heavy') },
      success:   () => { void notify('Success') },
      warning:   () => { void notify('Warning') },
      error:     () => { void notify('Error') },
      selection: () => { void selectionTick() },
    }
  }, [])
}
