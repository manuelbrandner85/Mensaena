'use client'

import { useEffect, useRef, useCallback } from 'react'
import Image from 'next/image'
import { Phone, PhoneOff } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { startRingtone, stopRingtone } from '@/lib/audio/ringtone'

export interface IncomingCallScreenProps {
  callId: string
  conversationId: string
  callerName: string
  callerAvatar: string | null
  callType: 'audio' | 'video'
  onAccept: (token: string, url: string, roomName: string) => void
  onDecline: () => void
}

export default function IncomingCallScreen({
  callId, conversationId, callerName, callerAvatar, callType, onAccept, onDecline,
}: IncomingCallScreenProps) {
  const handledRef = useRef(false)

  // Klingelton
  useEffect(() => {
    void startRingtone()
    return () => { stopRingtone() }
  }, [])

  // Supabase-Realtime: Call wurde vom Caller storniert
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`incoming-call-${callId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
        filter: `id=eq.${callId}`,
      }, (payload) => {
        const status = (payload.new as { status: string }).status
        if (status !== 'ringing' && !handledRef.current) {
          handledRef.current = true
          stopRingtone()
          onDecline()
        }
      })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [callId])

  const handleAccept = useCallback(async () => {
    if (handledRef.current) return
    handledRef.current = true
    stopRingtone()
    try {
      const supabase = createClient()
      const { data: { session } } = await supabase.auth.getSession()
      const res = await fetch('/api/dm-calls/answer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {}),
        },
        body: JSON.stringify({ callId }),
      })
      if (!res.ok) throw new Error('Answer failed')
      const data = await res.json() as { token: string; url: string; roomName: string }
      onAccept(data.token, data.url, data.roomName)
    } catch {
      handledRef.current = false
      void startRingtone()
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [callId, onAccept])

  const handleDecline = useCallback(async () => {
    if (handledRef.current) return
    handledRef.current = true
    stopRingtone()
    await fetch('/api/dm-calls/decline', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callId }),
    }).catch(() => {})
    onDecline()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [callId, onDecline])

  return (
    <div className="fixed inset-0 z-[9998] flex flex-col items-center justify-center gap-10 bg-gradient-to-b from-gray-900 via-gray-950 to-black">
      <div className="relative flex flex-col items-center gap-4">
        {callerAvatar ? (
          <div className="w-28 h-28 rounded-full overflow-hidden ring-4 ring-primary-500/40 shadow-2xl">
            <Image src={callerAvatar} alt={callerName} width={112} height={112} className="w-full h-full object-cover" />
          </div>
        ) : (
          <div className="w-28 h-28 rounded-full bg-gray-700 flex items-center justify-center ring-4 ring-primary-500/40 shadow-2xl">
            <span className="text-4xl text-white font-bold">{callerName[0]?.toUpperCase() ?? '?'}</span>
          </div>
        )}
        <span className="absolute inset-0 rounded-full animate-ping bg-primary-500/10 -z-10" />
      </div>

      <div className="text-center space-y-1">
        <p className="text-2xl font-semibold text-white">{callerName}</p>
        <p className="text-white/50 text-sm">{callType === 'video' ? '📹 Eingehender Videoanruf' : '📞 Eingehender Sprachanruf'}</p>
      </div>

      <div className="flex items-center gap-16">
        <button
          onClick={handleDecline}
          className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 transition-all flex items-center justify-center shadow-lg"
          aria-label="Ablehnen"
        >
          <PhoneOff className="w-7 h-7 text-white" />
        </button>
        <button
          onClick={handleAccept}
          className="w-16 h-16 rounded-full bg-green-500 hover:bg-green-600 active:scale-95 transition-all flex items-center justify-center shadow-lg animate-pulse"
          aria-label="Annehmen"
        >
          <Phone className="w-7 h-7 text-white" />
        </button>
      </div>
    </div>
  )
}
