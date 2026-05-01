'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { useAuthStore } from '@/store/useAuthStore'

export type FcmStatus =
  | 'idle'
  | 'unsupported'      // läuft nicht in Capacitor (Web-Browser)
  | 'requesting'       // fragt Permission
  | 'permission_denied'
  | 'registering'      // Firebase register() läuft
  | 'registration_error'
  | 'token_saved'      // alles OK, Token in DB
  | 'token_save_error'

interface FcmState {
  status: FcmStatus
  token?: string
  error?: string
  updatedAt: string
}

const LS_KEY = 'mensaena_fcm_status'

function writeStatus(status: FcmStatus, extra: Partial<FcmState> = {}) {
  if (typeof window === 'undefined') return
  const state: FcmState = {
    status,
    updatedAt: new Date().toISOString(),
    ...extra,
  }
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(state))
    window.dispatchEvent(new CustomEvent('mensaena:fcm-status', { detail: state }))
  } catch {
    /* storage disabled */
  }
}

export function readFcmStatus(): FcmState | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(LS_KEY)
    return raw ? (JSON.parse(raw) as FcmState) : null
  } catch {
    return null
  }
}

/**
 * Registriert die Capacitor-APK für FCM-Push-Notifications und speichert
 * das FCM-Token in der Supabase-Tabelle `fcm_tokens`.
 *
 * Läuft NUR in der nativen Capacitor-App, nicht im Browser/PWA. Im Browser
 * übernimmt usePushNotifications (VAPID-Web-Push).
 *
 * Bei Fehlern wird ein Toast angezeigt + der Zustand in localStorage
 * geschrieben, damit das Debug-Panel in den Einstellungen ihn anzeigen kann.
 */
export function useCapacitorPush() {
  const router = useRouter()
  const { user } = useAuthStore()
  const registeredRef = useRef(false)
  const lastUserIdRef = useRef<string | null>(null)
  const [status, setStatus] = useState<FcmStatus>('idle')

  // ── Phase 1: Permission-Dialog sofort beim App-Start (kein Login nötig) ─
  // requestPermissions() zeigt den Android-System-Dialog so früh wie möglich.
  // Ist Permission bereits erteilt/abgelehnt, kehrt der Aufruf sofort zurück.
  useEffect(() => {
    let cancelled = false
    ;(async () => {
      let Capacitor: typeof import('@capacitor/core').Capacitor | undefined
      try { ;({ Capacitor } = await import('@capacitor/core')) } catch { return }
      if (!Capacitor.isNativePlatform()) return

      let PushNotifications: typeof import('@capacitor/push-notifications').PushNotifications
      try { ;({ PushNotifications } = await import('@capacitor/push-notifications')) } catch { return }

      if (cancelled) return
      try { await PushNotifications.requestPermissions() } catch { /* silent */ }

      // Android 8+: Notification-Channel anlegen bevor register() aufgerufen wird.
      // send-push Edge Function sendet channel_id: 'mensaena_default' – stimmt der
      // Channel nicht überein, schweigt Android 8+ die Benachrichtigung ab.
      try {
        await PushNotifications.createChannel({
          id: 'mensaena_default',
          name: 'Mensaena',
          description: 'Benachrichtigungen für Mensaena',
          importance: 5,   // IMPORTANCE_HIGH
          visibility: 1,   // VISIBILITY_PUBLIC
          sound: 'default',
          vibration: true,
          lights: true,
          lightColor: '#FF1EAAA6',
        })
      } catch { /* Channel-API nicht verfügbar (iOS / älteres Android) */ }

      // Eigener "calls" Channel für eingehende Anrufe – höchste Importance,
      // Lockscreen-sichtbar, eigener Klingelton (ringtone.mp3 muss in res/raw/ liegen).
      try {
        await PushNotifications.createChannel({
          id: 'mensaena_calls',
          name: 'Anrufe',
          description: 'Eingehende 1-zu-1 Sprach-/Video-Anrufe',
          importance: 5,   // IMPORTANCE_HIGH (max für FCM ohne Full-Screen-Intent)
          visibility: 1,   // VISIBILITY_PUBLIC
          sound: 'ringtone',
          vibration: true,
          lights: true,
          lightColor: '#FF1EAAA6',
        })
      } catch { /* Channel-API nicht verfügbar (iOS / älteres Android) */ }
    })()
    return () => { cancelled = true }
  }, []) // einmalig beim Mount – vor dem Login

  // ── Phase 2: FCM-Registrierung + Token-Speicherung nach Login ───────────
  useEffect(() => {
    if (!user) return
    // User-Wechsel? → registeredRef zurücksetzen damit der neue User
    // ebenfalls einen FCM-Token in der DB bekommt.
    if (lastUserIdRef.current !== user.id) {
      registeredRef.current = false
      lastUserIdRef.current = user.id
    }
    if (registeredRef.current) return
    let cleanup: (() => void) | undefined
    let cancelled = false

    const setState = (s: FcmStatus, extra: Partial<FcmState> = {}) => {
      if (cancelled) return
      setStatus(s)
      writeStatus(s, extra)
    }

    ;(async () => {
      let Capacitor: typeof import('@capacitor/core').Capacitor | undefined
      try {
        ;({ Capacitor } = await import('@capacitor/core'))
      } catch {
        setState('unsupported', { error: 'Capacitor nicht verfügbar' })
        return
      }
      if (!Capacitor.isNativePlatform()) {
        setState('unsupported', { error: 'Kein nativer Platform (Browser/PWA)' })
        return
      }
      if (cancelled) return

      let PushNotifications: typeof import('@capacitor/push-notifications').PushNotifications
      try {
        ;({ PushNotifications } = await import('@capacitor/push-notifications'))
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err)
        setState('registration_error', { error: 'Plugin-Import: ' + msg })
        toast.error('Push-Plugin konnte nicht geladen werden')
        return
      }

      // ── Permission prüfen (Phase 1 hat bereits angefragt) ──
      setState('requesting')
      let perm: Awaited<ReturnType<typeof PushNotifications.checkPermissions>>
      try {
        perm = await PushNotifications.checkPermissions()
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err)
        setState('registration_error', { error: 'checkPermissions: ' + msg })
        return
      }
      if (perm.receive !== 'granted') {
        setState('permission_denied', { error: 'Berechtigung: ' + perm.receive })
        toast(
          'Benachrichtigungen sind deaktiviert. Einstellungen → Mensaena → Benachrichtigungen → aktivieren.',
          { duration: 6500, icon: '🔕' },
        )
        return
      }
      if (cancelled) return

      // ── Listeners
      setState('registering')

      const tokenListener = await PushNotifications.addListener(
        'registration',
        async (tok) => {
          if (cancelled) return
          const savedOk = await saveFcmToken(
            tok.value,
            Capacitor!.getPlatform() as 'android' | 'ios',
          )
          if (savedOk) {
            registeredRef.current = true
            setState('token_saved', { token: tok.value.substring(0, 24) + '…' })
            toast.success('Push-Benachrichtigungen aktiv', { duration: 3500 })
          } else {
            setState('token_save_error', {
              error: 'Token konnte nicht in fcm_tokens gespeichert werden',
              token: tok.value.substring(0, 24) + '…',
            })
            toast.error('Push-Token DB-Fehler – siehe Einstellungen', {
              duration: 5500,
            })
          }
        },
      )

      const errorListener = await PushNotifications.addListener(
        'registrationError',
        (err) => {
          if (cancelled) return
          const msg =
            (err as { error?: string })?.error ??
            (typeof err === 'string' ? err : JSON.stringify(err))
          setState('registration_error', { error: msg })
          toast.error('Firebase-Registrierung fehlgeschlagen: ' + msg, {
            duration: 6500,
          })
        },
      )

      const receivedListener = await PushNotifications.addListener(
        'pushNotificationReceived',
        (notification) => {
          if (cancelled) return
          const data = notification.data as Record<string, unknown> | undefined
          // FIX-94 (KRITISCH): Eingehender Anruf → IncomingCallActivity DIREKT
          // anzeigen via IncomingCallKit. Vorher wurde nur ein CustomEvent
          // dispatched das niemand hört → IncomingCallActivity wurde NIE
          // angezeigt → 'Splash flackert + kein Anruf' Symptom.
          // Realtime ist auf Native disabled, also ist DAS hier der einzige
          // Trigger für die native Vollbild-Anrufanzeige.
          if (data?.type === 'incoming_call') {
            void (async () => {
              try {
                const { showNativeIncomingCall } = await import('./useNativeIncomingCall')
                await showNativeIncomingCall({
                  callId:         String(data.call_id ?? ''),
                  callerName:     String(data.caller_name ?? 'Anrufer'),
                  callerAvatar:   typeof data.caller_avatar === 'string' ? data.caller_avatar : null,
                  callType:       (data.call_type === 'video' ? 'video' : 'audio'),
                  conversationId: String(data.conversation_id ?? ''),
                  roomName:       String(data.room_name ?? ''),
                })
              } catch (err) {
                console.error('[useCapacitorPush] showNativeIncomingCall failed', err)
              }
            })()
            return
          }
          toast(
            notification.title
              ? `${notification.title}\n${notification.body ?? ''}`
              : (notification.body ?? 'Neue Nachricht'),
            { duration: 4500, icon: '🔔' },
          )
        },
      )

      const actionListener = await PushNotifications.addListener(
        'pushNotificationActionPerformed',
        (action) => {
          if (cancelled) return
          const data = action.notification?.data as Record<string, unknown> | undefined
          // Eingehender Anruf: zur Chat-Seite navigieren + DB-Query holt den Call
          if (data?.type === 'incoming_call' && data.conversation_id) {
            // FIX-94: action=accept anhängen damit ChatPageInner direkt /answer
            // ruft + LiveRoomModal öffnet (Parität zu sw.js notificationclick).
            router.push(
              `/dashboard/chat?conv=${data.conversation_id}&call=${data.call_id ?? ''}&action=accept`,
            )
            return
          }
          const url = data?.url
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

      // Triggers 'registration' oder 'registrationError'
      try {
        await PushNotifications.register()
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err)
        setState('registration_error', { error: 'register(): ' + msg })
        toast.error('Push-Registrierung fehlgeschlagen: ' + msg)
      }
    })()

    return () => {
      cancelled = true
      cleanup?.()
    }
  }, [user?.id, user, router])

  return status
}

/**
 * Upsert FCM-Token in DB. Returns true bei Erfolg, false bei DB-Fehler.
 * Schreibt Fehler-Detail in localStorage damit das Debug-Panel es zeigt.
 */
async function saveFcmToken(
  token: string,
  platform: 'android' | 'ios',
): Promise<boolean> {
  if (!token) return false
  try {
    const supabase = createClient()
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()
    if (authError || !user) {
      writeStatus('token_save_error', {
        error: 'Kein User: ' + (authError?.message ?? 'getUser() gab null'),
      })
      return false
    }

    const { error } = await supabase.from('fcm_tokens').upsert(
      {
        user_id: user.id,
        token,
        platform,
        active: true,
        last_used: new Date().toISOString(),
      },
      { onConflict: 'user_id,token', ignoreDuplicates: false },
    )

    if (error) {
      writeStatus('token_save_error', {
        error: `Supabase: ${error.code ?? ''} ${error.message}`.trim(),
      })
      return false
    }
    return true
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    writeStatus('token_save_error', { error: 'Catch: ' + msg })
    return false
  }
}
