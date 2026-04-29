'use client'

import React, { useEffect, useRef, useState } from 'react'
import { Phone, PhoneOff, Video } from 'lucide-react'
import { startDialTone, stopDialTone } from '@/lib/audio/dial-tone'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

export interface OutgoingCallScreenProps {
  calleeName: string
  calleeAvatar: string | null
  callType: 'audio' | 'video'
  callId: string
  onCancel: () => void
  onConnected: (token: string, url: string, roomName: string) => void
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
}: OutgoingCallScreenProps): React.JSX.Element {
  const [duration, setDuration] = useState(0)
  const startRef = useRef(Date.now())
  const cancelledRef = useRef(false)

  useEffect(() => {
    startDialTone()
    return () => { stopDialTone() }
  }, [])

  useEffect(() => {
    const t = setInterval(() => setDuration(Math.floor((Date.now() - startRef.current) / 1000)), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`outgoing-call-${callId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `id=eq.${callId}`,
      }, async (payload) => {
        if (cancelledRef.current) return
        const row = payload.new as DmCallStatusRow
        if (row.status === 'active') {
          stopDialTone()
          try {
            const res = await fetch('/api/live-room/token', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ roomName: row.room_name, displayName: 'Anrufer' }),
            })
            if (!res.ok) throw new Error('Token-Anfrage fehlgeschlagen')
            const data = await res.json() as { token: string; url: string }
            onConnected(data.token, data.url, row.room_name)
          } catch {
            toast.error('Verbindung fehlgeschlagen')
            onCancel()
          }
        } else if (row.status === 'declined') {
          stopDialTone()
          toast('📵 Anruf abgelehnt', { duration: 3000 })
          onCancel()
        } else if (row.status === 'ended' || row.status === 'missed') {
          stopDialTone()
          onCancel()
        }
      })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [callId, onCancel, onConnected])

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
      onCancel()
    }, 45_000)
    return () => clearTimeout(timeout)
  }, [callId, onCancel])

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
    onCancel()
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
      className="fixed inset-0 z-[9998] bg-gradient-to-b from-gray-900 via-gray-950 to-black flex flex-col items-center justify-between py-12 px-6 text-white"
    >
      <div className="text-center mt-4">
        <p className="text-sm uppercase tracking-widest text-primary-400 mb-2">
          {callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'}
        </p>
        <p className="text-xs text-white/30">{formatTimer(duration)}</p>
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
