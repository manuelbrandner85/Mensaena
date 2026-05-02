'use client'

// FIX-74: DM-Call wie Livestream — leichtgewichtiges Overlay über LiveRoomModal
import { useState, useEffect, useRef, useCallback } from 'react'
import Image from 'next/image'
import { PhoneOff } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { startDialTone, stopDialTone } from '@/lib/audio/dial-tone'

const CALL_TIMEOUT_SECONDS = 45

export interface CallingOverlayProps {
  calleeName: string
  calleeAvatar: string | null
  callType: 'audio' | 'video'
  callId: string
  onStatusChange: (status: string) => void
}

export default function CallingOverlay({
  calleeName,
  calleeAvatar,
  callType,
  callId,
  onStatusChange,
}: CallingOverlayProps) {
  const [seconds, setSeconds] = useState(CALL_TIMEOUT_SECONDS)
  const onStatusChangeRef = useRef(onStatusChange)
  onStatusChangeRef.current = onStatusChange

  // Dial tone
  useEffect(() => {
    startDialTone()
    return () => { stopDialTone() }
  }, [])

  // Countdown — fires missed when it reaches 0
  useEffect(() => {
    const tick = setInterval(() => {
      setSeconds((s) => {
        if (s <= 1) {
          clearInterval(tick)
          fetch('/api/dm-calls/missed', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ callId }),
          }).catch(() => {})
          onStatusChangeRef.current('missed')
          return 0
        }
        return s - 1
      })
    }, 1000)
    return () => clearInterval(tick)
  }, [callId])

  // Realtime: listen for status changes on this call row
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`calling-overlay:${callId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'dm_calls',
          filter: `id=eq.${callId}`,
        },
        (payload) => {
          const status = (payload.new as Record<string, unknown>).status as string
          onStatusChangeRef.current(status)
        },
      )
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [callId])

  const handleCancel = useCallback(async () => {
    stopDialTone()
    try {
      await fetch('/api/dm-calls/cancel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      })
    } catch { /* server will expire the call */ }
    onStatusChangeRef.current('cancelled')
  }, [callId])

  return (
    <div className="fixed inset-0 z-[201] flex flex-col items-center justify-center gap-8 bg-black/80 backdrop-blur-sm">
      {/* Avatar */}
      <div className="relative">
        {calleeAvatar ? (
          <div className="w-28 h-28 rounded-full overflow-hidden ring-4 ring-white/20 shadow-2xl">
            <Image
              src={calleeAvatar}
              alt={calleeName}
              width={112}
              height={112}
              className="w-full h-full object-cover"
            />
          </div>
        ) : (
          <div className="w-28 h-28 rounded-full bg-gray-700 flex items-center justify-center ring-4 ring-white/20 shadow-2xl">
            <span className="text-4xl text-white font-bold">
              {calleeName[0]?.toUpperCase() ?? '?'}
            </span>
          </div>
        )}
        {/* Pulse rings */}
        <span className="absolute inset-0 rounded-full animate-ping bg-white/10 -z-10" />
        <span className="absolute inset-[-8px] rounded-full animate-ping bg-white/5 animation-delay-300 -z-10" />
      </div>

      {/* Name + status */}
      <div className="text-center space-y-2">
        <p className="text-2xl font-semibold text-white">{calleeName}</p>
        <p className="text-white/60 text-sm flex items-center justify-center gap-2">
          <span className="inline-block w-2 h-2 rounded-full bg-yellow-400 animate-pulse" />
          {callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'} · Klingelt… {seconds}s
        </p>
      </div>

      {/* Cancel button */}
      <button
        onClick={handleCancel}
        className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 transition-all flex items-center justify-center shadow-lg"
        aria-label="Auflegen"
      >
        <PhoneOff className="w-7 h-7 text-white" />
      </button>
    </div>
  )
}
