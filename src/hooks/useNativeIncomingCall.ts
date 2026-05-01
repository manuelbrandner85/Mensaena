'use client'
// FEATURE: WhatsApp-Style Call – Nativer Incoming-Call-Screen (Android Full-Screen / iOS CallKit)

import { useEffect, useRef } from 'react'
import { Capacitor } from '@capacitor/core'

interface NativeCallOptions {
  userId: string
  onAccept: (callId: string, extra: Record<string, unknown>) => void
  onDecline: (callId: string) => void
}

export function useNativeIncomingCall({ userId, onAccept, onDecline }: NativeCallOptions) {
  const onAcceptRef = useRef(onAccept)
  const onDeclineRef = useRef(onDecline)
  useEffect(() => { onAcceptRef.current = onAccept }, [onAccept])
  useEffect(() => { onDeclineRef.current = onDecline }, [onDecline])

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return
    const cleanups: Array<() => void> = []

    async function init() {
      const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')
      await IncomingCallKit.requestPermissions()
      // FIX-83: FullScreen-Intent-Permission nur einmal pro Gerät anfragen.
      // Wiederholtes Promptbei jedem App-Start nervt den User; einmal Ja/Nein
      // reicht – Status merken wir uns in localStorage.
      try {
        const ASKED_KEY = 'mensaena.fullScreenIntentAsked'
        if (typeof localStorage !== 'undefined' && !localStorage.getItem(ASKED_KEY)) {
          await IncomingCallKit.requestFullScreenIntentPermission()
          localStorage.setItem(ASKED_KEY, '1')
        }
      } catch { /* localStorage nicht verfügbar – einfach nicht fragen */ }

      const a = await IncomingCallKit.addListener('callAccepted', ({ call }) => {
        onAcceptRef.current(call.callId, call.extra ?? {})
      })
      cleanups.push(() => { void a.remove() })

      const d = await IncomingCallKit.addListener('callDeclined', ({ call }) => {
        onDeclineRef.current(call.callId)
      })
      cleanups.push(() => { void d.remove() })

      const t = await IncomingCallKit.addListener('callTimedOut', ({ call }) => {
        onDeclineRef.current(call.callId)
      })
      cleanups.push(() => { void t.remove() })

      // FIX-93: Cold-Start-Recovery – wenn der User auf Annehmen tippt während
      // die App komplett tot war, feuert das Plugin den callAccepted-Event noch
      // BEVOR unser JS-Listener attached ist → Event verloren → kein Call-UI.
      // Nach dem addListener fragen wir die aktiven Calls ab und feuern den
      // onAccept-Callback manuell für alle bereits 'accepted' Calls nach.
      try {
        const { calls } = await IncomingCallKit.getActiveCalls()
        for (const call of calls) {
          if (call.state === 'accepted') {
            onAcceptRef.current(call.callId, call.extra ?? {})
            break // nur der erste – mehrere parallele Calls gibt's nicht
          }
        }
      } catch { /* ignore – Cold-Start-Recovery best-effort */ }
    }

    void init()
    return () => { cleanups.forEach(fn => fn()) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])
}

export async function showNativeIncomingCall(opts: {
  callId: string
  callerName: string
  callerAvatar?: string | null
  callType: 'audio' | 'video'
  conversationId: string
  roomName: string
}): Promise<void> {
  if (!Capacitor.isNativePlatform()) return
  const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')

  await IncomingCallKit.showIncomingCall({
    callId: opts.callId,
    callerName: opts.callerName,
    handle: opts.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
    appName: 'Mensaena',
    hasVideo: opts.callType === 'video',
    timeoutMs: 45_000,
    extra: {
      conversationId: opts.conversationId,
      roomName: opts.roomName,
      callType: opts.callType,
      callerName: opts.callerName,
      callerAvatar: opts.callerAvatar ?? null,
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
}

export async function endNativeIncomingCall(callId: string): Promise<void> {
  if (!Capacitor.isNativePlatform()) return
  const { IncomingCallKit } = await import('@capgo/capacitor-incoming-call-kit')
  await IncomingCallKit.endCall({ callId })
}
