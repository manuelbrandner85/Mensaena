'use client'

import React, { useEffect, useRef, useState } from 'react'
import { Loader2, Phone, PhoneOff, Video, Volume2, VolumeX } from 'lucide-react'
import toast from 'react-hot-toast'
import { startRingtone, stopRingtone } from '@/lib/audio/ringtone'
import { playEndTone } from '@/lib/audio/end-tone' // FEATURE: End-Ton
import { createClient } from '@/lib/supabase/client'

export interface IncomingCallScreenProps {
  callerName: string
  callerAvatar: string | null
  callType: 'audio' | 'video'
  callId: string
  conversationId: string
  onAccept: (token: string, url: string, roomName: string) => void
  onDecline: () => void
}

interface DmCallStatusRow {
  id: string
  status: string
  room_name: string
}

interface AnswerResponse {
  token: string
  url: string
  roomName: string
}

/**
 * Fullscreen-Overlay den der Empfänger sieht solange der Anruf klingelt.
 * Spielt Klingelton, zeigt Profilbild + Annehmen/Ablehnen-Buttons.
 *
 * Verhalten:
 * - Bei Mount: startRingtone()
 * - Annehmen-Button: POST /api/dm-calls/answer → onAccept(token, url, roomName)
 * - Ablehnen-Button: POST /api/dm-calls/decline → onDecline()
 * - Realtime-Subscription auf dm_calls.id:
 *   - status='ended' or 'missed' or 'declined' (vom Anrufer ausgelöst) → onDecline()
 * - 45s Timeout: onDecline() (Caller-Side markiert es als missed)
 */
export default function IncomingCallScreen({
  callerName, callerAvatar, callType, callId, conversationId, onAccept, onDecline,
}: IncomingCallScreenProps): React.JSX.Element {
  const [duration, setDuration] = useState(0)
  const [muted, setMuted] = useState(false)
  const [busy, setBusy] = useState(false)
  // FIX-6: Verbindungs-Feedback – true zwischen Antippen und LiveRoomModal-Mount
  const [connecting, setConnecting] = useState(false)
  const startRef = useRef(Date.now())
  const handledRef = useRef(false)
  void conversationId
  // FIX-2: Stabile Callback-Refs – verhindert Realtime-Channel-Reconnects bei Re-Renders
  const onAcceptRef = useRef(onAccept)
  const onDeclineRef = useRef(onDecline)
  useEffect(() => { onAcceptRef.current = onAccept }, [onAccept])
  useEffect(() => { onDeclineRef.current = onDecline }, [onDecline])

  // Mount/unmount: Ringtone starten + immer am Ende stoppen.
  useEffect(() => {
    startRingtone()
    return () => { stopRingtone() }
  }, [])

  // Stummschaltung separat – stoppt nur den Ringtone, startet bei
  // Wiederaktivierung neu (sofern der Call noch nicht beendet wurde).
  useEffect(() => {
    if (muted) stopRingtone()
    else if (!handledRef.current) startRingtone()
  }, [muted])

  useEffect(() => {
    const t = setInterval(() => setDuration(Math.floor((Date.now() - startRef.current) / 1000)), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    if (duration >= 45 && !handledRef.current) {
      handledRef.current = true
      stopRingtone()
      // FIX-5: Doppelte Missed-Markierung – Caller verwaltet den Timeout serverseitig.
      // Kein API-Call hier, sonst entstehen zwei Systemnachrichten (Caller + Callee).
      playEndTone() // FEATURE: End-Ton
      onDeclineRef.current()
    }
  }, [duration]) // FIX-5: callId entfernt – kein API-Call mehr nötig

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
        if (handledRef.current) return
        const row = payload.new as DmCallStatusRow
        if (row.status === 'ended' || row.status === 'missed' || row.status === 'declined') {
          handledRef.current = true
          stopRingtone()
          toast('📵 Anruf beendet', { duration: 2000 })
          playEndTone() // FEATURE: End-Ton
          onDeclineRef.current() // FIX-2: Stabile Callback-Refs
        }
      })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [callId]) // FIX-2: Stabile Callback-Refs – kein onDecline im Dep-Array

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
        stopRingtone()
        playEndTone() // FEATURE: End-Ton
        onDeclineRef.current()
      }
    }
    document.addEventListener('visibilitychange', handler)
    return () => document.removeEventListener('visibilitychange', handler)
  }, [callId])

  const handleAccept = async (): Promise<void> => {
    if (busy || handledRef.current) return
    setBusy(true)
    setConnecting(true) // FIX-6: Spinner sofort anzeigen
    handledRef.current = true
    stopRingtone()
    try {
      const supabase = createClient()
      const { data: { session: answerSession } } = await supabase.auth.getSession()
      const answerToken = answerSession?.access_token ?? ''
      const res = await fetch('/api/dm-calls/answer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(answerToken ? { Authorization: `Bearer ${answerToken}` } : {}),
        },
        body: JSON.stringify({ callId }),
      })
      if (!res.ok) throw new Error('Answer fehlgeschlagen')
      const data = await res.json() as AnswerResponse
      onAcceptRef.current(data.token, data.url, data.roomName) // FIX-2: Stabile Callback-Refs
    } catch (e) {
      // FIX-40: LiveKit-Fallback-Hinweis
      const msg = (e as Error)?.message ?? ''
      if (msg.includes('fetch') || msg.includes('network') || msg.includes('Failed')) {
        toast.error('Sprachanrufe sind gerade nicht verfügbar. Bitte nutze den Text-Chat.', { duration: 6000 })
      } else {
        toast.error(`Anruf konnte nicht angenommen werden: ${msg}`, { duration: 4000 })
      }
      onDeclineRef.current() // FIX-2: Stabile Callback-Refs
    } finally {
      setBusy(false)
    }
  }

  const handleDecline = async (): Promise<void> => {
    if (busy || handledRef.current) return
    setBusy(true)
    handledRef.current = true
    stopRingtone()
    try {
      await fetch('/api/dm-calls/decline', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId }),
      })
    } catch { /* server-side timeout will catch */ }
    playEndTone() // FEATURE: End-Ton
    onDeclineRef.current() // FIX-2: Stabile Callback-Refs
    setBusy(false)
  }

  const initials = callerName.split(' ').map(s => s[0]).join('').slice(0, 2).toUpperCase()

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Eingehender Anruf"
      className="fixed inset-0 z-[200] bg-gradient-to-b from-gray-900 via-gray-950 to-black flex flex-col items-center justify-between py-12 px-6 text-white"
    >
      <div className="text-center mt-4">
        <p className="text-xs uppercase tracking-widest text-primary-400 mb-2">
          {callType === 'video' ? '📹 Eingehender Videoanruf' : '📞 Eingehender Sprachanruf'}
        </p>
        {/* FIX-41: Countdown statt Hochzählen */}
        <p className={['text-xs tabular-nums', Math.max(0, 45 - duration) < 10 ? 'text-red-400' : 'text-white/30'].join(' ')}>
          Klingelt noch {Math.max(0, 45 - duration)}s
        </p>
      </div>

      <div className="flex flex-col items-center gap-5 flex-1 justify-center">
        <div className="relative">
          <span className="absolute inset-0 rounded-full bg-primary-400/30 animate-ping" style={{ animationDuration: '1.5s' }} />
          <span className="absolute inset-0 rounded-full bg-primary-400/20 animate-ping" style={{ animationDuration: '2.5s', animationDelay: '0.3s' }} />
          <span className="absolute inset-0 rounded-full bg-primary-400/10 animate-ping" style={{ animationDuration: '3.5s', animationDelay: '0.6s' }} />
          <div className="relative w-36 h-36 rounded-full bg-white/15 backdrop-blur-md border-2 border-white/30 flex items-center justify-center text-5xl font-bold overflow-hidden shadow-2xl">
            {callerAvatar
              ? <img src={callerAvatar} alt={callerName} className="w-full h-full object-cover" />
              : <span>{initials}</span>}
          </div>
        </div>
        <div className="text-center">
          <p className="text-3xl font-bold mb-1">{callerName}</p>
          <p className="text-sm text-white/60 flex items-center justify-center gap-1.5">
            {callType === 'video' ? <Video className="w-4 h-4" /> : <Phone className="w-4 h-4" />}
            ruft dich an…
          </p>
        </div>
      </div>

      <div className="w-full max-w-sm">
        <div className="flex justify-center mb-8">
          <button
            onClick={() => setMuted(m => !m)}
            className="p-3 rounded-full bg-white/15 backdrop-blur-md hover:bg-white/25 transition-all"
            aria-label={muted ? 'Klingelton an' : 'Klingelton aus'}
          >
            {muted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
          </button>
        </div>

        {connecting ? (
          <div className="flex flex-col items-center gap-3 animate-fade-in">
            <Loader2 className="w-10 h-10 text-primary-400 animate-spin" />
            <p className="text-white/70 text-sm">Verbindung wird hergestellt…</p>
          </div>
        ) : (
          <div className="flex items-center justify-around gap-16">
            <button
              onClick={handleDecline}
              disabled={busy}
              className="flex flex-col items-center gap-2 group disabled:opacity-50"
              aria-label="Ablehnen"
            >
              <div className="w-20 h-20 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center shadow-xl shadow-red-500/40 transition-all group-hover:scale-110 group-active:scale-95">
                <PhoneOff className="w-8 h-8" /> {/* FIX-14: PhoneOff Rotation entfernt */}
              </div>
              <span className="text-xs text-red-300 font-medium">Ablehnen</span>
            </button>

            <button
              onClick={handleAccept}
              disabled={busy}
              className="flex flex-col items-center gap-2 group disabled:opacity-50"
              aria-label="Annehmen"
            >
              <div className="w-20 h-20 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center shadow-xl shadow-green-500/40 transition-all group-hover:scale-110 group-active:scale-95 animate-pulse">
                {callType === 'video' ? <Video className="w-8 h-8" /> : <Phone className="w-8 h-8" />}
              </div>
              <span className="text-xs text-green-300 font-medium">Annehmen</span>
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
