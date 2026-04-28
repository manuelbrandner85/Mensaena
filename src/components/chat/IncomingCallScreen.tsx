'use client'

import { useEffect, useRef, useState } from 'react'
import { Phone, PhoneOff, Video, VideoOff, Volume2, VolumeX } from 'lucide-react'
import { startRingtone, stopRingtone } from '@/lib/audio/ringtone'

interface Props {
  callerName: string
  callerAvatar?: string | null
  callType: 'audio' | 'video'
  onAccept: () => void
  onDecline: () => void
}

export default function IncomingCallScreen({ callerName, callerAvatar, callType, onAccept, onDecline }: Props) {
  const [duration, setDuration] = useState(0)
  const [muted, setMuted] = useState(false)
  const startRef = useRef(Date.now())

  useEffect(() => {
    if (!muted) startRingtone()
    return () => { stopRingtone() }
  }, [muted])

  useEffect(() => {
    const t = setInterval(() => setDuration(Math.floor((Date.now() - startRef.current) / 1000)), 1000)
    return () => clearInterval(t)
  }, [])

  // Auto-decline after 45s (no answer)
  useEffect(() => {
    if (duration >= 45) onDecline()
  }, [duration, onDecline])

  const initials = callerName.split(' ').map(s => s[0]).join('').slice(0, 2).toUpperCase()

  return (
    <div className="fixed inset-0 z-[100] bg-gradient-to-b from-primary-700 via-primary-600 to-primary-900 flex flex-col items-center justify-between py-12 px-6 text-white">
      {/* Header */}
      <div className="text-center mt-4">
        <p className="text-sm uppercase tracking-widest opacity-80 mb-2">
          {callType === 'video' ? '📹 Eingehender Videoanruf' : '📞 Eingehender Sprachanruf'}
        </p>
        <p className="text-xs opacity-60">{duration}s</p>
      </div>

      {/* Avatar + Name */}
      <div className="flex flex-col items-center gap-5 flex-1 justify-center">
        <div className="relative">
          {/* Pulsing rings */}
          <span className="absolute inset-0 rounded-full bg-white/20 animate-ping" style={{ animationDuration: '2s' }} />
          <span className="absolute inset-0 rounded-full bg-white/10 animate-ping" style={{ animationDuration: '3s', animationDelay: '0.5s' }} />
          <div className="relative w-36 h-36 rounded-full bg-white/15 backdrop-blur-md border-2 border-white/30 flex items-center justify-center text-5xl font-bold overflow-hidden shadow-2xl">
            {callerAvatar
              ? <img src={callerAvatar} alt={callerName} className="w-full h-full object-cover" />
              : <span>{initials}</span>}
          </div>
        </div>
        <div className="text-center">
          <p className="text-3xl font-bold mb-1">{callerName}</p>
          <p className="text-sm opacity-70">ruft dich an…</p>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="w-full max-w-sm">
        {/* Mute ringtone */}
        <div className="flex justify-center mb-8">
          <button
            onClick={() => setMuted(m => !m)}
            className="p-3 rounded-full bg-white/15 backdrop-blur-md hover:bg-white/25 transition-all"
            aria-label={muted ? 'Klingelton an' : 'Klingelton aus'}>
            {muted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
          </button>
        </div>

        <div className="flex items-center justify-around">
          {/* Decline */}
          <button
            onClick={onDecline}
            className="flex flex-col items-center gap-2 group"
            aria-label="Ablehnen">
            <div className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center shadow-xl shadow-red-500/40 transition-all group-hover:scale-110 group-active:scale-95">
              <PhoneOff className="w-7 h-7 rotate-[135deg]" />
            </div>
            <span className="text-xs font-medium opacity-80">Ablehnen</span>
          </button>

          {/* Accept */}
          <button
            onClick={onAccept}
            className="flex flex-col items-center gap-2 group"
            aria-label="Annehmen">
            <div className="w-16 h-16 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center shadow-xl shadow-green-500/40 transition-all group-hover:scale-110 group-active:scale-95 animate-pulse-subtle">
              {callType === 'video'
                ? <Video className="w-7 h-7" />
                : <Phone className="w-7 h-7" />}
            </div>
            <span className="text-xs font-medium opacity-80">Annehmen</span>
          </button>
        </div>
      </div>
    </div>
  )
}
