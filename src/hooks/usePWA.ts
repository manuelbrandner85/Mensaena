'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { useOnlineStatus } from './useOnlineStatus'
import { isStandalone } from '@/lib/pwa/pwa-utils'
import { registerServiceWorker, sendMessageToSW } from '@/lib/pwa/register-sw'

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

/**
 * Central PWA hook providing install, update, and online state.
 *
 * Returns:
 *  - isInstalled       : app is running standalone / installed
 *  - canInstall        : beforeinstallprompt was captured (Chromium)
 *  - isUpdateAvailable : a new SW is installed & waiting
 *  - isOnline          : navigator.onLine status
 *  - promptInstall()   : trigger the browser install prompt
 *  - applyUpdate()     : activate the waiting SW (reload)
 *  - clearCache()      : wipe all SW caches
 */
export function usePWA() {
  const { isOnline } = useOnlineStatus()

  const [isInstalled, setIsInstalled] = useState(false)
  const [canInstall, setCanInstall] = useState(false)
  const [isUpdateAvailable, setIsUpdateAvailable] = useState(false)

  const deferredPromptRef = useRef<BeforeInstallPromptEvent | null>(null)

  // ── Register SW & listen for events ─────────────────────────────
  useEffect(() => {
    // Check standalone mode
    setIsInstalled(isStandalone())

    // Register service worker
    registerServiceWorker()

    // Listen for the browser's install prompt
    const handleBeforeInstall = (e: Event) => {
      e.preventDefault()
      deferredPromptRef.current = e as BeforeInstallPromptEvent
      setCanInstall(true)
    }

    // Listen for app being installed
    const handleAppInstalled = () => {
      setIsInstalled(true)
      setCanInstall(false)
      deferredPromptRef.current = null
    }

    // Listen for SW update
    const handleSWUpdate = () => {
      setIsUpdateAvailable(true)
    }

    // Listen for display-mode changes (e.g. user installs mid-session)
    const mediaQuery = window.matchMedia('(display-mode: standalone)')
    const handleDisplayChange = (e: MediaQueryListEvent) => {
      setIsInstalled(e.matches)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstall)
    window.addEventListener('appinstalled', handleAppInstalled)
    window.addEventListener('sw-update-available', handleSWUpdate)
    mediaQuery.addEventListener('change', handleDisplayChange)

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall)
      window.removeEventListener('appinstalled', handleAppInstalled)
      window.removeEventListener('sw-update-available', handleSWUpdate)
      mediaQuery.removeEventListener('change', handleDisplayChange)
    }
  }, [])

  // ── Actions ────────────────────────────────────────────────────
  const promptInstall = useCallback(async (): Promise<boolean> => {
    const prompt = deferredPromptRef.current
    if (!prompt) return false
    try {
      await prompt.prompt()
      const { outcome } = await prompt.userChoice
      deferredPromptRef.current = null
      setCanInstall(false)
      return outcome === 'accepted'
    } catch {
      return false
    }
  }, [])

  const applyUpdate = useCallback(() => {
    sendMessageToSW({ type: 'SKIP_WAITING' })
    // Reload after a tiny delay so the new SW can take over
    setTimeout(() => {
      window.location.reload()
    }, 300)
  }, [])

  const clearCache = useCallback(() => {
    sendMessageToSW({ type: 'CLEAR_CACHE' })
  }, [])

  return {
    isInstalled,
    canInstall,
    isUpdateAvailable,
    isOnline,
    promptInstall,
    applyUpdate,
    clearCache,
  }
}
