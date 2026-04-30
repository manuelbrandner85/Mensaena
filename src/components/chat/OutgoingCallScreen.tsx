'use client'

import React, { useEffect, useRef, useState } from 'react'
import { Phone, PhoneOff, Video } from 'lucide-react'
import { startDialTone, stopDialTone } from '@/lib/audio/dial-tone'
import { playEndTone } from '@/lib/audio/end-tone' // FEATURE: End-Ton
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

export interface OutgoingCallScreenProps {
  calleeName: string
  calleeAvatar: string | null
  callType: 'audio' | 'video'
  callId: string
  onCancel: () => void
  onConnected: (token: string, url: string, roomName: string) => void
  preToken?: string | null   // BUG-FIX: Vorab generierter LiveKit Token
  preUrl?: string | null     // BUG-FIX: Vorab generierte LiveKit URL
}

interface DmCallStatusRow {
  id: string
  status: string
  room_name: string
}

/**
 * Fullscreen-Overlay den der Anrufer sieht solange der Anruf klingelt.
 * Spielt Wählton, zeigt Profilbild + animierten Pulse-Ring + Auflegen-Button.
 *
 * Verhalten:
 * - Bei Mount: startDialTone()
 * - Realtime-Subscription auf dm_calls.id:
 *   - status='active'  → onConnected(token, url, roomName)
 *   - status='declined' → toast + onCancel()
 *   - status='ended' or 'missed' → onCancel()
 * - 45s Timeout: POST /api/dm-calls/missed → onCancel()
 * - Auflegen-Button: POST /api/dm-calls/cancel → onCancel()
 */
export default function OutgoingCallScreen({
  calleeName, calleeAvatar, callType, callId, onCancel, onConnected,
  preToken, preUrl,   // BUG-FIX
}: OutgoingCallScreenProps): React.JSX.Element {
  const [duration, setDuration] = useState(0)
  const startRef = useRef(Date.now())
  const cancelledRef = useRef(false)
  const callerNameRef = useRef<string>('Anrufer')
  // FIX-2: Stabile Callback-Refs – verhindert Realtime-Channel-Reconnects bei Re-Renders
  const onCancelRef = useRef(onCancel)
  const onConnectedRef = useRef(onConnected)
  useEffect(() => { onCancelRef.current = onCancel }, [onCancel])
  useEffect(() => { onConnectedRef.current = onConnected }, [onConnected])

  useEffect(() => {
    startDialTone()
    return () => { stopDialTone() }
  }, [])

  // Eigenen Profilnamen für LiveKit-Token vorladen, damit der Empfänger
  // beim Verbinden den richtigen Namen sieht statt hardcoded "Anrufer".
  useEffect(() => {
    const supabase = createClient()
    void supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) return
      const { data } = await supabase
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle<{ name: string | null }>()
      if (data?.name) callerNameRef.current = data.name
    })
  }, [])

  useEffect(() => {
    const t = setInterval(() => setDuration(Math.floor((Date.now() - startRef.current) / 1000)), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    const supabase = createClient()

    const handleStatus = async (row: DmCallStatusRow): Promise<void> => {
      if (cancelledRef.current) return
      if (row.status === 'active') {
        cancelledRef.current = true // FIX-72: gegen Doppel-Auslösung (Realtime + Initial-Poll)
        stopDialTone()

        // BUG-FIX: Pre-Token verwenden wenn vorhanden (kein extra Netzwerk-Request nötig)
        if (preToken && preUrl) {
          onConnectedRef.current(preToken, preUrl, row.room_name)
          return
        }

        // BUG-FIX: Fallback – Token neu fetchen falls /start keinen liefern konnte
        try {
          const { data: { session: lkSession } } = await supabase.auth.getSession()
          let authHeader = lkSession?.access_token ?? ''

          // BUG-FIX: Session-Refresh erzwingen falls Token abgelaufen
          if (!authHeader) {
            const { data: { session: refreshed } } = await supabase.auth.refreshSession()
            authHeader = refreshed?.access_token ?? ''
          }

          const res = await fetch('/api/live-room/token', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              ...(authHeader ? { Authorization: `Bearer ${authHeader}` } : {}),
            },
            body: JSON.stringify({ roomName: row.room_name, displayName: callerNameRef.current }),
          })
          if (!res.ok) throw new Error('Token-Anfrage fehlgeschlagen')
          const data = await res.json() as { token: string; url: string }
          // FIX-2: Stabile Callback-Refs
          onConnectedRef.current(data.token, data.url, row.room_name)
        } catch (e) {
          // FIX-3: Rollback bei Token-Fehler – Call beenden damit Empfänger nicht hängt
          await fetch('/api/dm-calls/end', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ callId }),
          }).catch(() => {})
          // FIX-40: LiveKit-Fallback-Hinweis
          const msg = (e as Error)?.message ?? ''
          if (msg.includes('fetch') || msg.includes('network') || msg.includes('Failed')) {
            toast.error('Sprachanrufe sind gerade nicht verfügbar. Bitte nutze den Text-Chat.', { duration: 6000 })
          } else {
            toast.error(`Verbindung fehlgeschlagen: ${msg}`, { duration: 4000 })
          }
          playEndTone() // FEATURE: End-Ton
          onCancelRef.current()
        }
      } else if (row.status === 'declined') {
        cancelledRef.current = true
        stopDialTone()
        toast('📵 Anruf abgelehnt', { duration: 3000 })
        playEndTone() // FEATURE: End-Ton
        onCancelRef.current() // FIX-2: Stabile Callback-Refs
      } else if (row.status === 'ended' || row.status === 'missed') {
        cancelledRef.current = true
        stopDialTone()
        playEndTone() // FEATURE: End-Ton
        onCancelRef.current() // FIX-2: Stabile Callback-Refs
      }
    }

    const channel = supabase
      .channel(`outgoing-call-${callId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `id=eq.${callId}`,
      }, (payload) => {
        void handleStatus(payload.new as DmCallStatusRow)
      })
      .subscribe(async (status) => {
        // FIX-72: Initial-Poll nach Subscribe – Race-Schutz wenn Callee
        // bereits angenommen/abgelehnt hat während die Subscription aufgebaut wurde.
        if (status !== 'SUBSCRIBED' || cancelledRef.current) return
        const { data } = await supabase
          .from('dm_calls')
          .select('id, status, room_name')
          .eq('id', callId)
          .maybeSingle<DmCallStatusRow>()
        if (data && data.status !== 'ringing') void handleStatus(data)
      })
    return () => { void supabase.removeChannel(channel) }
  }, [callId, preToken, preUrl]) // FIX-72: preToken/preUrl in Deps damit Race-Poll aktuelle Werte nutzt

  useEffect(() => {
    const timeout = window.setTimeout(async () => {
      if (cancelledRef.current) return
      cancelledRef.current = true
      stopDialTone()
      try {
        await fetch('/api/dm-calls/missed', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId }),
        })
      } catch { /* network error – server-side cleanup will catch it */ }
      playEndTone() // FEATURE: End-Ton
      onCancelRef.current() // FIX-2: Stabile Callback-Refs
    }, 45_000)
    return () => clearTimeout(timeout)
  }, [callId]) // FIX-2: Stabile Callback-Refs – kein onCancel im Dep-Array

  // FIX-8: Visibilitychange Call-Status-Check
  useEffect(() => {
    const handler = async (): Promise<void> => {
      if (document.visibilityState !== 'visible') return
      const supabase = createClient()
      const { data } = await supabase
        .from('dm_calls')
        .select('status')
        .eq('id', callId)
        .maybeSingle()
      if (!data || ['ended', 'declined', 'missed', 'cancelled'].includes(data.status)) {
        stopDialTone()
        playEndTone() // FEATURE: End-Ton
        onCancelRef.current()
      }
    }
    document.addEventListener('visibilitychange', handler)
    return () => document.removeEventListener('visibilitychange', handler)
  }, [callId])

  const handleHangup = async (): Promise<void> => {
    if (cancelledRef.current) return
    cancelledRef.current = true
    stopDialTone()
    try {
      await fetch('/api/dm-calls/cancel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      })
    } catch { /* server-side timeout will mark it missed */ }
    playEndTone() // FEATURE: End-Ton
    onCancelRef.current() // FIX-2: Stabile Callback-Refs
  }

  const initials = calleeName.split(' ').map(s => s[0]).join('').slice(0, 2).toUpperCase()

  const formatTimer = (s: number): string => {
    const m = Math.floor(s / 60)
    const sec = s % 60
    return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Ausgehender Anruf"
      className="fixed inset-0 z-[199] bg-gradient-to-b from-gray-900 via-gray-950 to-black flex flex-col items-center justify-between py-12 px-6 text-white"
    >
      <div className="text-center mt-4">
        <p className="text-sm uppercase tracking-widest text-primary-400 mb-2">
          {callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
        </p>
        {/* FIX-41: Countdown statt Hochzählen */}
        <p className={['text-xs tabular-nums', Math.max(0, 45 - duration) < 10 ? 'text-red-400' : 'text-white/30'].join(' ')}>
          Klingelt noch {Math.max(0, 45 - duration)}s
        </p>
      </div>

      <div className="flex flex-col items-center gap-5 flex-1 justify-center">
        <div className="relative">
          <span className="absolute inset-0 rounded-full bg-primary-400/20 animate-ping" style={{ animationDuration: '2s' }} />
          <span className="absolute inset-0 rounded-full bg-primary-400/10 animate-ping" style={{ animationDuration: '3s', animationDelay: '0.5s' }} />
          <div className="relative w-32 h-32 rounded-full bg-white/10 backdrop-blur-md border-2 border-primary-400/40 flex items-center justify-center text-5xl font-bold overflow-hidden shadow-2xl">
            {calleeAvatar
              ? <img src={calleeAvatar} alt={calleeName} className="w-full h-full object-cover" />
              : <span>{initials}</span>}
          </div>
        </div>
        <div className="text-center">
          <p className="text-2xl font-semibold mb-1">{calleeName}</p>
          <p className="text-sm text-white/50 flex items-center justify-center gap-1.5">
            {callType === 'video' ? <Video className="w-4 h-4" /> : <Phone className="w-4 h-4" />}
            <DotsLoader />
          </p>
        </div>
      </div>

      <div className="flex flex-col items-center gap-2">
        <button
          onClick={handleHangup}
          className="w-20 h-20 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center shadow-lg shadow-red-500/40 transition-all"
          aria-label="Auflegen"
        >
          <PhoneOff className="w-8 h-8" />
        </button>
        <span className="text-xs text-white/40">Auflegen</span>
      </div>
    </div>
  )
}

function DotsLoader(): React.JSX.Element {
  return (
    <span className="inline-flex gap-0.5" aria-hidden="true">
      <span className="w-1 h-1 rounded-full bg-current animate-bounce" style={{ animationDelay: '0ms' }} />
      <span className="w-1 h-1 rounded-full bg-current animate-bounce" style={{ animationDelay: '150ms' }} />
      <span className="w-1 h-1 rounded-full bg-current animate-bounce" style={{ animationDelay: '300ms' }} />
      <span className="ml-1.5">Klingelt</span>
    </span>
  )
}
