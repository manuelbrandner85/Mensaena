'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import toast from 'react-hot-toast'
import { isPushSupported, getNotificationPermission } from '@/lib/pwa/pwa-utils'
import {
  subscribeToPush,
  unsubscribeFromPush,
  getExistingSubscription,
  saveSubscriptionToServer,
  removeSubscriptionFromServer,
} from '@/lib/pwa/push-manager'

const VAPID_PUBLIC_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || ''

/**
 * Hook to manage push notification state and actions.
 *
 * Returns:
 *  - permission   : current Notification permission
 *  - isSubscribed : user has an active push subscription
 *  - loading      : async operation in progress
 *  - requestPermission() : ask browser for permission
 *  - subscribe(userId)   : subscribe and store on server
 *  - unsubscribe(userId) : unsubscribe and remove from server
 */
export function usePushNotifications() {
  const [permission, setPermission] = useState<NotificationPermission>('default')
  const [isSubscribed, setIsSubscribed] = useState(false)
  const [loading, setLoading] = useState(false)
  const swRef = useRef<ServiceWorkerRegistration | null>(null)

  // ── Init: get current state ─────────────────────────────────────
  useEffect(() => {
    if (typeof window === 'undefined') return
    setPermission(getNotificationPermission())

    if (!isPushSupported()) return

    // FIX-121: cancelled-Flag verhindert setState nach Unmount
    let cancelled = false

    // Register SW reference
    navigator.serviceWorker.ready.then((reg) => {
      if (cancelled) return
      swRef.current = reg
    })

    // Check existing subscription
    getExistingSubscription().then((sub) => {
      if (cancelled) return
      setIsSubscribed(!!sub)
    })

    return () => { cancelled = true }
  }, [])

  // ── Request permission ──────────────────────────────────────────
  const requestPermission = useCallback(async (): Promise<boolean> => {
    if (!('Notification' in window)) {
      toast.error('Push-Benachrichtigungen werden von diesem Browser nicht unterstützt')
      return false
    }
    if (Notification.permission === 'granted') {
      setPermission('granted')
      return true
    }
    if (Notification.permission === 'denied') {
      setPermission('denied')
      toast.error(
        'Push-Benachrichtigungen sind blockiert. Bitte in den Browser-Einstellungen aktivieren.',
      )
      return false
    }
    const result = await Notification.requestPermission()
    setPermission(result)
    return result === 'granted'
  }, [])

  // ── Subscribe ──────────────────────────────────────────────────
  const subscribe = useCallback(
    async (userId?: string) => {
      if (!userId) return
      setLoading(true)
      try {
        const granted = await requestPermission()
        if (!granted) return

        const subData = await subscribeToPush()
        if (subData) {
          await saveSubscriptionToServer(userId, subData)
          setIsSubscribed(true)
          toast.success('Push-Benachrichtigungen aktiviert!')
        } else if (!VAPID_PUBLIC_KEY) {
          // No VAPID key – can still use local notifications
          setIsSubscribed(false)
          toast.success('Benachrichtigungen aktiviert!')
        }
      } catch (err) {
        console.warn('[usePushNotifications] subscribe failed:', err)
        if (Notification.permission === 'granted') {
          toast.success('Benachrichtigungen aktiviert!')
        }
      } finally {
        setLoading(false)
      }
    },
    [requestPermission],
  )

  // ── Unsubscribe ────────────────────────────────────────────────
  const unsubscribe = useCallback(async () => {
    setLoading(true)
    try {
      const existing = await getExistingSubscription()
      if (existing) {
        await removeSubscriptionFromServer(existing.endpoint)
      }
      await unsubscribeFromPush()
      setIsSubscribed(false)
      toast.success('Push-Benachrichtigungen deaktiviert')
    } catch (err) {
      console.warn('[usePushNotifications] unsubscribe failed:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  // ── Show local notification ────────────────────────────────────
  const showLocalNotification = useCallback(
    (title: string, body: string, url?: string) => {
      if (Notification.permission !== 'granted') return
      const reg = swRef.current
      if (reg) {
        reg
          .showNotification(title, {
            body,
            icon: '/icons/icon-192x192.png',
            badge: '/icons/icon-72x72.png',
            data: { url: url || '/dashboard' },
          })
          .catch(() => {})
      } else {
        new Notification(title, { body, icon: '/icons/icon-192x192.png' })
      }
    },
    [],
  )

  return {
    permission,
    isSubscribed,
    loading,
    requestPermission,
    subscribe,
    unsubscribe,
    showLocalNotification,
  }
}
