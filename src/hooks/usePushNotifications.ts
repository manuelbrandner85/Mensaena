'use client'

import { useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

// VAPID public key – for production replace with real key pair
// Generate with: npx web-push generate-vapid-keys
const VAPID_PUBLIC_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || ''

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

export function usePushNotifications(userId?: string) {
  const swRef = useRef<ServiceWorkerRegistration | null>(null)

  // Register service worker
  useEffect(() => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return
    navigator.serviceWorker
      .register('/sw.js', { scope: '/' })
      .then((reg) => {
        swRef.current = reg
      })
      .catch((err) => console.warn('SW registration failed:', err))
  }, [])

  const requestPermission = useCallback(async (): Promise<boolean> => {
    if (!('Notification' in window)) {
      toast.error('Push-Benachrichtigungen werden von diesem Browser nicht unterstützt')
      return false
    }
    if (Notification.permission === 'granted') return true
    if (Notification.permission === 'denied') {
      toast.error('Push-Benachrichtigungen sind blockiert. Bitte in den Browser-Einstellungen aktivieren.')
      return false
    }
    const permission = await Notification.requestPermission()
    return permission === 'granted'
  }, [])

  const subscribe = useCallback(async () => {
    if (!userId) return
    const granted = await requestPermission()
    if (!granted) return

    try {
      const reg = swRef.current || (await navigator.serviceWorker.ready)
      let sub = await reg.pushManager.getSubscription()
      if (!sub && VAPID_PUBLIC_KEY) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
        })
      }
      if (sub) {
        // Store subscription in Supabase for server-side push
        const supabase = createClient()
        await supabase.from('push_subscriptions').upsert({
          user_id: userId,
          endpoint: sub.endpoint,
          p256dh: btoa(String.fromCharCode(...new Uint8Array(sub.getKey('p256dh')!))),
          auth: btoa(String.fromCharCode(...new Uint8Array(sub.getKey('auth')!))),
          updated_at: new Date().toISOString(),
        }, { onConflict: 'user_id' }).catch(() => {}) // ignore if table doesn't exist yet
        toast.success('Push-Benachrichtigungen aktiviert! 🔔')
      } else {
        // Fallback: just use browser Notification API directly
        toast.success('Benachrichtigungen aktiviert! 🔔')
      }
    } catch (err) {
      console.warn('Push subscription failed:', err)
      // Still show granted state
      if (Notification.permission === 'granted') {
        toast.success('Benachrichtigungen aktiviert! 🔔')
      }
    }
  }, [userId, requestPermission])

  // Show a local notification (works even without push server)
  const showLocalNotification = useCallback(
    (title: string, body: string, url?: string) => {
      if (Notification.permission !== 'granted') return
      const reg = swRef.current
      if (reg) {
        reg.showNotification(title, {
          body,
          icon: '/mensaena-logo.png',
          badge: '/favicon.ico',
          data: { url: url || '/dashboard' },
        }).catch(() => {})
      } else {
        new Notification(title, { body, icon: '/mensaena-logo.png' })
      }
    },
    []
  )

  return {
    permission: typeof window !== 'undefined' && 'Notification' in window
      ? Notification.permission
      : 'default',
    subscribe,
    showLocalNotification,
    requestPermission,
  }
}
