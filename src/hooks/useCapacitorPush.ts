'use client'

import { useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useAuthStore } from '@/store/useAuthStore'

/**
 * Registriert die Capacitor-APK für FCM-Push-Notifications und speichert
 * das FCM-Token in der Supabase-Tabelle `fcm_tokens`.
 *
 * Läuft NUR in der nativen Capacitor-App, nicht im Browser/PWA. Im Browser
 * übernimmt die bestehende Web-Push-Infrastruktur (usePushNotifications
 * Hook + VAPID) das Gleiche.
 *
 * Flow:
 *   1. User öffnet die App (user ist eingeloggt)
 *   2. Dieser Hook requestPermissions()
 *   3. register() → Firebase liefert FCM-Token via 'registration' event
 *   4. Wir speichern das Token in fcm_tokens
 *   5. Bei neuen Notifications (DB-Trigger) schickt send-push Edge Function
 *      via FCM HTTP v1 API an dieses Token
 *   6. Android zeigt die Notification an – auch wenn die App geschlossen ist
 *   7. Klick auf Notification: pushNotificationActionPerformed event feuert
 *      mit optionalem `url`-Payload → Router-Navigate
 */
export function useCapacitorPush() {
  const router = useRouter()
  const { user } = useAuthStore()
  const registeredRef = useRef(false)

  useEffect(() => {
    if (!user || registeredRef.current) return
    let cleanup: (() => void) | undefined
    let cancelled = false

    ;(async () => {
      try {
        const { Capacitor } = await import('@capacitor/core')
        if (!Capacitor.isNativePlatform()) return
        if (cancelled) return

        const { PushNotifications } = await import('@capacitor/push-notifications')

        // Android 13+: fragt nach POST_NOTIFICATIONS Permission
        const perm = await PushNotifications.requestPermissions()
        if (perm.receive !== 'granted') return
        if (cancelled) return

        // Registrierungs-Listeners BEVOR register() aufrufen, sonst Race Condition
        const tokenListener = await PushNotifications.addListener(
          'registration',
          async (tok) => {
            if (cancelled) return
            await saveFcmToken(tok.value, Capacitor.getPlatform() as 'android' | 'ios')
            registeredRef.current = true
          },
        )

        const errorListener = await PushNotifications.addListener(
          'registrationError',
          (err) => {
            // Kein console.log in Production – in Dev-Tools trotzdem sichtbar via Capacitor
            console.warn('[useCapacitorPush] registration error:', err)
          },
        )

        // Push-Notification empfangen WÄHREND die App im Vordergrund ist
        // (Android zeigt in dem Fall KEIN System-Popup – wir zeigen stattdessen
        // einen In-App-Toast via react-hot-toast, um den User zu informieren).
        const receivedListener = await PushNotifications.addListener(
          'pushNotificationReceived',
          async (notification) => {
            if (cancelled) return
            try {
              const { default: toast } = await import('react-hot-toast')
              toast(
                notification.title
                  ? `${notification.title}\n${notification.body ?? ''}`
                  : (notification.body ?? 'Neue Nachricht'),
                { duration: 4500, icon: '🔔' },
              )
            } catch {
              // toast lib nicht verfügbar – still ignore
            }
          },
        )

        // Tap auf Notification (aus dem Notification-Tray oder Lockscreen) →
        // App öffnen & zur passenden URL navigieren.
        const actionListener = await PushNotifications.addListener(
          'pushNotificationActionPerformed',
          (action) => {
            if (cancelled) return
            const url =
              (action.notification?.data as Record<string, unknown> | undefined)?.url
            if (typeof url === 'string' && url.startsWith('/')) {
              router.push(url)
            }
          },
        )

        cleanup = () => {
          tokenListener.remove().catch(() => {})
          errorListener.remove().catch(() => {})
          receivedListener.remove().catch(() => {})
          actionListener.remove().catch(() => {})
        }

        // Triggert das 'registration' event (oder 'registrationError')
        await PushNotifications.register()
      } catch {
        // @capacitor/push-notifications nicht verfügbar (Web-Build) – ignore
      }
    })()

    return () => {
      cancelled = true
      cleanup?.()
    }
  }, [user, router])
}

async function saveFcmToken(token: string, platform: 'android' | 'ios') {
  if (!token) return
  const supabase = createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return

  // upsert: gleicher user + token bleibt eine row, last_used wird aktualisiert
  await supabase
    .from('fcm_tokens')
    .upsert(
      {
        user_id: user.id,
        token,
        platform,
        active: true,
        last_used: new Date().toISOString(),
      },
      { onConflict: 'user_id,token', ignoreDuplicates: false },
    )
}
