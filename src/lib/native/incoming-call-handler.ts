// FIX-125: Native Incoming Call Handler.
// Empfängt FCM Data-Push, zeigt nativen Vollbild-Anruf via IncomingCallKit,
// behandelt Annehmen/Ablehnen und füttert useNativeCallStore.

import { createClient } from '@/lib/supabase/client'
import { useNativeCallStore } from '@/store/useNativeCallStore'
import toast from 'react-hot-toast'

interface IncomingCallData {
  type: string
  callId: string
  callerName: string
  callerAvatar: string
  callType: 'audio' | 'video'
  roomName: string
  conversationId: string
}

let initialized = false

function isNativePlatform(): boolean {
  try {
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean } }
    return !!w.Capacitor?.isNativePlatform()
  } catch { return false }
}

async function showNativeCallScreen(data: IncomingCallData): Promise<void> {
  try {
    const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')
    await IncomingCallKit.showIncomingCall({
      callId: data.callId,
      callerName: data.callerName || 'Unbekannt',
      handle: data.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
      appName: 'Mensaena',
      hasVideo: data.callType === 'video',
      timeoutMs: 45_000,
      extra: {
        callType: data.callType,
        callerName: data.callerName,
        callerAvatar: data.callerAvatar,
        roomName: data.roomName,
        conversationId: data.conversationId,
      },
      android: {
        channelId: 'mensaena-calls',
        channelName: 'Eingehende Anrufe',
        showFullScreen: true,
        isHighPriority: true,
        accentColor: '#1EAAA6',
      },
      ios: { handleType: 'generic' },
    })
  } catch (e) {
    console.error('[IncomingCallHandler] showIncomingCall failed:', e)
  }
}

async function handleAcceptedCall(callId: string, extra: Record<string, unknown>): Promise<void> {
  try {
    const supabase = createClient()
    const { data: { session } } = await supabase.auth.getSession()
    const accessToken = session?.access_token ?? ''

    const res = await fetch('/api/dm-calls/answer', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
      },
      body: JSON.stringify({ callId }),
    })

    if (!res.ok) {
      // Phase 5.2: Bereits gecanceled
      try {
        const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')
        await IncomingCallKit.endCall({ callId })
      } catch { /* ignore */ }
      toast.error('Anruf nicht mehr verfügbar', { duration: 3000 })
      return
    }

    const data = await res.json() as { token: string; url: string; roomName: string }

    useNativeCallStore.getState().setPendingCall({
      callId,
      token: data.token,
      url: data.url,
      roomName: data.roomName,
      callType: (extra.callType as 'audio' | 'video') ?? 'audio',
      partnerName: (extra.callerName as string) ?? 'Anrufer',
      partnerAvatar: (extra.callerAvatar as string) || null,
      answeredAt: new Date().toISOString(),
    })
  } catch (e) {
    console.error('[IncomingCallHandler] accept failed:', e)
    toast.error('Anruf konnte nicht angenommen werden')
  }
}

async function handleDeclinedCall(callId: string): Promise<void> {
  try {
    const supabase = createClient()
    const { data: { session } } = await supabase.auth.getSession()
    const accessToken = session?.access_token ?? ''
    await fetch('/api/dm-calls/decline', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
      },
      body: JSON.stringify({ callId }),
    }).catch(() => {})
  } catch { /* ignore */ }
}

/**
 * Initialisiert die nativen Listener. Idempotent — kann mehrfach aufgerufen werden.
 * NUR auf Capacitor (Android/iOS) aktiv, im Browser No-op.
 */
export async function initIncomingCallHandler(): Promise<void> {
  if (initialized || !isNativePlatform()) return
  initialized = true

  try {
    const { PushNotifications } = await import('@capacitor/push-notifications')
    const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')

    // ── Foreground push (App offen) ─────────────────────────────────────────
    await PushNotifications.addListener('pushNotificationReceived', (notification) => {
      const data = (notification.data ?? {}) as Record<string, string>
      if (data.type !== 'incoming_call') return

      // Phase 5.1: Im Vordergrund den Web-Flow (GlobalCallListener via Realtime)
      // entscheiden lassen, KEIN nativer Screen.
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') return

      void showNativeCallScreen(data as unknown as IncomingCallData)
    })

    // ── Background/Killed push ─────────────────────────────────────────────
    // Wenn Notification getappt wird (z.B. via Banner), öffnet die App und
    // wir bekommen den Action-Event. Aber Data-Only erscheint hier nicht
    // immer; wir registrieren trotzdem als Sicherheitsnetz.
    await PushNotifications.addListener('pushNotificationActionPerformed', (action) => {
      const data = (action.notification.data ?? {}) as Record<string, string>
      if (data.type !== 'incoming_call') return
      void showNativeCallScreen(data as unknown as IncomingCallData)
    })

    // ── IncomingCallKit Events ─────────────────────────────────────────────
    await IncomingCallKit.addListener('callAnswered', async ({ call }) => {
      await handleAcceptedCall(call.callId, call.extra ?? {})
    })

    await IncomingCallKit.addListener('callDeclined', async ({ call }) => {
      await handleDeclinedCall(call.callId)
    })

    await IncomingCallKit.addListener('callTimedOut', () => {
      // Server-side wird Status auf 'missed' gesetzt vom Caller's Timeout.
      // Nichts weiter tun.
    })

    console.log('[IncomingCallHandler] initialized')
  } catch (e) {
    console.error('[IncomingCallHandler] init failed:', e)
  }
}
