'use client'

import { useEffect, useRef, useCallback } from 'react'
import Image from 'next/image'
import { PhoneOff } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { startDialTone, stopDialTone } from '@/lib/audio/dial-tone'

export interface CallingOverlayProps {
  callId: string
  calleeName: string
  calleeAvatar: string | null
  callType: 'audio' | 'video'
  onStatusChange: (status: string) => void
}

export default function CallingOverlay({ callId, calleeName, calleeAvatar, callType, onStatusChange }: CallingOverlayProps) {
  const onStatusChangeRef = useRef(onStatusChange)
  onStatusChangeRef.current = onStatusChange
  const handledRef = useRef(false)

  useEffect(() => {
    startDialTone()
    return () => { stopDialTone() }
  }, [])

  // Realtime: Callee antwortet oder lehnt ab
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`calling-overlay-${callId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `id=eq.${callId}`,
      }, (payload) => {
        const status = (payload.new as { status: string }).status
        if (!handledRef.current) {
          handledRef.current = true
          stopDialTone()
          onStatusChangeRef.current(status)
        }
      })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [callId])

  // 45s Timeout → missed
  useEffect(() => {
    const t = setTimeout(() => {
      if (handledRef.current) return
      handledRef.current = true
      stopDialTone()
      fetch('/api/dm-calls/missed', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      }).catch(() => {})
      onStatusChangeRef.current('missed')
    }, 45_000)
    return () => clearTimeout(t)
  }, [callId])

  const handleCancel = useCallback(async () => {
    if (handledRef.current) return
    handledRef.current = true
    stopDialTone()
    await fetch('/api/dm-calls/cancel', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callId }),
    }).catch(() => {})
    onStatusChangeRef.current('cancelled')
  }, [callId])

  return (
    <div className="fixed inset-0 z-[10000] flex flex-col items-center justify-center gap-8 bg-black/85 backdrop-blur-sm">
      <div className="relative">
        {calleeAvatar ? (
          <div className="w-28 h-28 rounded-full overflow-hidden ring-4 ring-white/20 shadow-2xl">
            <Image src={calleeAvatar} alt={calleeName} width={112} height={112} className="w-full h-full object-cover" />
          </div>
        ) : (
          <div className="w-28 h-28 rounded-full bg-gray-700 flex items-center justify-center ring-4 ring-white/20 shadow-2xl">
            <span className="text-4xl text-white font-bold">{calleeName[0]?.toUpperCase() ?? '?'}</span>
          </div>
        )}
        <span className="absolute inset-0 rounded-full animate-ping bg-white/10 -z-10" />
      </div>

      <div className="text-center space-y-2">
        <p className="text-2xl font-semibold text-white">{calleeName}</p>
        <p className="text-white/50 text-sm flex items-center justify-center gap-2">
          <span className="w-2 h-2 rounded-full bg-yellow-400 animate-pulse inline-block" />
          {callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf'} · Klingelt…
        </p>
      </div>

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
