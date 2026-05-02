'use client'

import { useEffect, useRef, useCallback, useState } from 'react'
import { createPortal } from 'react-dom'
import {
  LiveKitRoom,
  useParticipants,
  useLocalParticipant,
  useTracks,
  VideoTrack,
  AudioTrack,
  useRoomContext,
  useConnectionState,
} from '@livekit/components-react'
import { Track, RoomEvent, ConnectionState, DisconnectReason } from 'livekit-client'
import type { Participant } from 'livekit-client'
import { Phone, PhoneOff, Video, VideoOff, Mic, MicOff, X } from 'lucide-react'
import Image from 'next/image'
import toast from 'react-hot-toast'
import { startForegroundService, stopForegroundService } from '@/hooks/useForegroundService'
import '@livekit/components-styles'

// ─── Typen ────────────────────────────────────────────────────────────────────

export interface LiveRoomProps {
  roomName: string
  token: string
  serverUrl: string
  title: string
  isDMCall?: boolean
  dmCallId?: string
  answeredAt?: string | null   // null = klingelt noch (Caller-Seite)
  partnerName?: string
  partnerAvatar?: string | null
  onClose: () => void
}

// ─── Avatar-Hilfe ─────────────────────────────────────────────────────────────

function Avatar({ name, avatarUrl, size = 80 }: { name: string; avatarUrl?: string | null; size?: number }) {
  if (avatarUrl) {
    return (
      <div className="rounded-full overflow-hidden ring-2 ring-white/20" style={{ width: size, height: size }}>
        <Image src={avatarUrl} alt={name} width={size} height={size} className="object-cover w-full h-full" />
      </div>
    )
  }
  return (
    <div className="rounded-full bg-gray-700 flex items-center justify-center ring-2 ring-white/20 text-white font-bold" style={{ width: size, height: size, fontSize: size * 0.4 }}>
      {name[0]?.toUpperCase() ?? '?'}
    </div>
  )
}

// ─── Timer ────────────────────────────────────────────────────────────────────

function useCallTimer(answeredAt: string | null | undefined) {
  const [elapsed, setElapsed] = useState(0)
  useEffect(() => {
    if (!answeredAt) { setElapsed(0); return }
    const base = new Date(answeredAt).getTime()
    const tick = setInterval(() => setElapsed(Math.floor((Date.now() - base) / 1000)), 1000)
    return () => clearInterval(tick)
  }, [answeredAt])
  const m = String(Math.floor(elapsed / 60)).padStart(2, '0')
  const s = String(elapsed % 60).padStart(2, '0')
  return answeredAt ? `${m}:${s}` : null
}

// ─── Innerer Raum ──────────────────────────────────────────────────────────────

interface InnerRoomProps {
  props: LiveRoomProps
  onHangup: () => void
}

function InnerRoom({ props, onHangup }: InnerRoomProps) {
  const { isDMCall, dmCallId, answeredAt, partnerName, partnerAvatar, title } = props
  const room = useRoomContext()
  const connectionState = useConnectionState()
  const participants = useParticipants()
  const { localParticipant } = useLocalParticipant()
  const timerStr = useCallTimer(answeredAt)

  // Lokale Medien-Steuerung
  const [micEnabled, setMicEnabled] = useState(true)
  const [camEnabled, setCamEnabled] = useState(false)

  // Tracks aller Teilnehmer — Hooks nie in Loops aufrufen, hier auf Top-Level
  const videoTracks = useTracks([Track.Source.Camera], { onlySubscribed: false })
  const allAudioTracks = useTracks([Track.Source.Microphone], { onlySubscribed: true })
  const remoteParticipants = participants.filter(p => p.identity !== localParticipant.identity)

  // ── 30s-Timeout: kein Partner erschienen ─────────────────────────────────
  const timeoutStartedRef = useRef(false)
  useEffect(() => {
    if (!isDMCall || !dmCallId) return
    if (connectionState !== ConnectionState.Connected) return
    if (timeoutStartedRef.current) return
    timeoutStartedRef.current = true
    const t = setTimeout(() => {
      if (room.remoteParticipants.size === 0) {
        fetch('/api/dm-calls/end', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: dmCallId }),
        }).catch(() => {})
        toast.error('Dein Gesprächspartner konnte nicht verbinden')
        onHangup()
      }
    }, 30_000)
    return () => clearTimeout(t)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connectionState, isDMCall, dmCallId])

  // ── 3s-Grace: Partner hat den Raum verlassen ──────────────────────────────
  const partnerLeftRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  useEffect(() => {
    if (!isDMCall || !dmCallId) return
    const onLeft = () => {
      if (partnerLeftRef.current) { clearTimeout(partnerLeftRef.current); partnerLeftRef.current = null }
      if (room.remoteParticipants.size > 0) return
      partnerLeftRef.current = setTimeout(() => {
        partnerLeftRef.current = null
        if (room.remoteParticipants.size === 0) {
          fetch('/api/dm-calls/end', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ callId: dmCallId }),
          }).catch(() => {})
          onHangup()
        }
      }, 3_000)
    }
    const onJoined = () => {
      if (partnerLeftRef.current) { clearTimeout(partnerLeftRef.current); partnerLeftRef.current = null }
    }
    room.on(RoomEvent.ParticipantDisconnected, onLeft)
    room.on(RoomEvent.ParticipantConnected, onJoined)
    return () => {
      room.off(RoomEvent.ParticipantDisconnected, onLeft)
      room.off(RoomEvent.ParticipantConnected, onJoined)
      if (partnerLeftRef.current) { clearTimeout(partnerLeftRef.current); partnerLeftRef.current = null }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDMCall, dmCallId, room])

  // ── Supabase-Status: Server beendet den Call ──────────────────────────────
  useEffect(() => {
    if (!isDMCall || !dmCallId) return
    let cancelled = false
    async function listen() {
      const { createClient } = await import('@/lib/supabase/client')
      const supabase = createClient()
      const channel = supabase
        .channel(`live-room-status-${dmCallId}`)
        .on('postgres_changes', {
          event: 'UPDATE',
          schema: 'public',
          table: 'dm_calls',
          filter: `id=eq.${dmCallId}`,
        }, (payload) => {
          const status = (payload.new as { status: string }).status
          if (['ended', 'declined', 'missed', 'cancelled'].includes(status) && !cancelled) {
            onHangup()
          }
        })
        .subscribe()
      return () => { cancelled = true; void supabase.removeChannel(channel) }
    }
    let cleanup: (() => void) | undefined
    listen().then(fn => { cleanup = fn }).catch(() => {})
    return () => { cleanup?.() }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDMCall, dmCallId])

  const toggleMic = useCallback(async () => {
    await localParticipant.setMicrophoneEnabled(!micEnabled)
    setMicEnabled(v => !v)
  }, [localParticipant, micEnabled])

  const toggleCam = useCallback(async () => {
    await localParticipant.setCameraEnabled(!camEnabled)
    setCamEnabled(v => !v)
  }, [localParticipant, camEnabled])

  const handleHangup = useCallback(async () => {
    if (isDMCall && dmCallId) {
      await fetch('/api/dm-calls/end', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId: dmCallId }),
      }).catch(() => {})
    }
    onHangup()
  }, [isDMCall, dmCallId, onHangup])

  // Lokales Video-Track für Vorschau
  const localVideoTrack = videoTracks.find(t => t.participant.identity === localParticipant.identity)
  const remoteVideoTrack = videoTracks.find(t => t.participant.identity !== localParticipant.identity)
  const hasRemoteVideo = !!remoteVideoTrack?.publication?.isSubscribed

  // Haupt-Teilnehmer (für die Großansicht im DM-Call)
  const mainParticipant: Participant | undefined = remoteParticipants[0]
  const isConnected = connectionState === ConnectionState.Connected

  return (
    <div className="flex flex-col h-full bg-gray-950 text-white">
      {/* Header */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 py-3 border-b border-white/10">
        <div>
          <p className="text-xs font-semibold text-primary-400 uppercase tracking-widest">Live</p>
          <p className="text-sm font-semibold text-white truncate max-w-[200px]">{title}</p>
        </div>
        <div className="flex items-center gap-3">
          {timerStr && (
            <span className="text-sm text-green-400 font-mono">{timerStr}</span>
          )}
          <span className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-400' : 'bg-yellow-400 animate-pulse'}`} />
        </div>
      </div>

      {/* Haupt-Video-Bereich */}
      <div className="flex-1 relative overflow-hidden bg-gray-900">
        {isDMCall ? (
          // DM-Call: 1-zu-1 Layout
          <div className="h-full flex flex-col items-center justify-center">
            {hasRemoteVideo && remoteVideoTrack ? (
              <VideoTrack trackRef={remoteVideoTrack} className="w-full h-full object-cover" />
            ) : (
              <div className="flex flex-col items-center gap-4">
                <Avatar name={mainParticipant?.name ?? partnerName ?? '?'} avatarUrl={partnerAvatar} size={96} />
                <p className="text-white text-lg font-semibold">{mainParticipant?.name ?? partnerName ?? 'Teilnehmer'}</p>
                {!isConnected && <p className="text-white/50 text-sm">Verbindet…</p>}
                {isConnected && remoteParticipants.length === 0 && (
                  <p className="text-white/50 text-sm">Warte auf Partner…</p>
                )}
                {/* Remote-Audio */}
                {allAudioTracks
                  .filter(t => t.participant.identity !== localParticipant.identity)
                  .map(t => <AudioTrack key={t.publication.trackSid} trackRef={t} />)
                }
              </div>
            )}
          </div>
        ) : (
          // Community-Livestream: Raster-Layout
          <div className="h-full grid grid-cols-2 gap-1 p-1" style={{ gridAutoRows: '1fr' }}>
            {participants.map(p => {
              const camTrack = videoTracks.find(t => t.participant.identity === p.identity)
              return (
                <div key={p.identity} className="relative rounded-lg overflow-hidden bg-gray-800 flex items-center justify-center">
                  {camTrack?.publication?.isSubscribed || p.identity === localParticipant.identity ? (
                    camTrack ? <VideoTrack trackRef={camTrack} className="w-full h-full object-cover" /> : null
                  ) : null}
                  {(!camTrack || !camTrack.publication?.isSubscribed) && (
                    <Avatar name={p.name ?? p.identity} size={56} />
                  )}
                  <div className="absolute bottom-1 left-2 text-xs text-white/80 bg-black/40 px-1.5 py-0.5 rounded">
                    {p.name ?? p.identity}
                    {p.identity === localParticipant.identity && ' (Du)'}
                  </div>
                  {/* Remote-Audio */}
                  {p.identity !== localParticipant.identity &&
                    allAudioTracks
                      .filter(t => t.participant.identity === p.identity)
                      .map(t => <AudioTrack key={t.publication.trackSid} trackRef={t} />)
                  }
                </div>
              )
            })}
          </div>
        )}

        {/* Lokale Kamera-Vorschau (klein, unten rechts) */}
        {camEnabled && localVideoTrack && (
          <div className="absolute bottom-4 right-4 w-24 h-32 rounded-xl overflow-hidden ring-2 ring-white/20 shadow-lg">
            <VideoTrack trackRef={localVideoTrack} className="w-full h-full object-cover" />
          </div>
        )}
      </div>

      {/* Steuerleiste */}
      <div className="flex-shrink-0 flex items-center justify-center gap-6 py-5 border-t border-white/10">
        <button
          onClick={toggleMic}
          className={`w-12 h-12 rounded-full flex items-center justify-center transition-colors ${micEnabled ? 'bg-white/10 hover:bg-white/20' : 'bg-red-500 hover:bg-red-600'}`}
          aria-label={micEnabled ? 'Mikrofon stumm' : 'Mikrofon an'}
        >
          {micEnabled ? <Mic className="w-5 h-5" /> : <MicOff className="w-5 h-5" />}
        </button>
        <button
          onClick={handleHangup}
          className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center transition-all shadow-lg"
          aria-label="Auflegen"
        >
          <PhoneOff className="w-7 h-7" />
        </button>
        <button
          onClick={toggleCam}
          className={`w-12 h-12 rounded-full flex items-center justify-center transition-colors ${camEnabled ? 'bg-primary-500 hover:bg-primary-600' : 'bg-white/10 hover:bg-white/20'}`}
          aria-label={camEnabled ? 'Kamera aus' : 'Kamera an'}
        >
          {camEnabled ? <Video className="w-5 h-5" /> : <VideoOff className="w-5 h-5" />}
        </button>
      </div>
    </div>
  )
}

// ─── Öffentliche LiveRoom-Komponente ──────────────────────────────────────────

export default function LiveRoom(props: LiveRoomProps) {
  const { roomName, token, serverUrl, title, isDMCall, onClose } = props
  const hangupCalledRef = useRef(false)

  // Foreground-Service beim Mount starten (nicht erst beim Connect)
  useEffect(() => {
    void startForegroundService({
      title,
      onHangup: () => {
        if (!hangupCalledRef.current) {
          hangupCalledRef.current = true
          if (isDMCall && props.dmCallId) {
            fetch('/api/dm-calls/end', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ callId: props.dmCallId }),
            }).catch(() => {})
          }
          onClose()
        }
      },
    })
    return () => { void stopForegroundService() }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleHangup = useCallback(() => {
    if (hangupCalledRef.current) return
    hangupCalledRef.current = true
    onClose()
  }, [onClose])

  const handleDisconnected = useCallback((reason?: DisconnectReason) => {
    // CLIENT_INITIATED = 1: User hat aufgelegt
    if (reason === DisconnectReason.CLIENT_INITIATED) {
      handleHangup()
    }
    // Andere Gründe: LiveKit reconnected automatisch, nichts tun
  }, [handleHangup])

  return (
    <div className="fixed inset-0 z-[9999] bg-gray-950">
      <LiveKitRoom
        serverUrl={serverUrl}
        token={token}
        connect={true}
        video={false}
        audio={true}
        onDisconnected={handleDisconnected}
        style={{ height: '100%', width: '100%', background: 'transparent' }}
      >
        <InnerRoom props={props} onHangup={handleHangup} />
      </LiveKitRoom>
    </div>
  )
}
