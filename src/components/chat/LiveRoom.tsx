'use client'

import { useEffect, useRef, useCallback, useState } from 'react'
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
import { PhoneOff, Video, VideoOff, Mic, MicOff, SwitchCamera, Loader2 } from 'lucide-react'
import Image from 'next/image'
import toast from 'react-hot-toast'
import { startForegroundService, stopForegroundService } from '@/hooks/useForegroundService'
import { createClient } from '@/lib/supabase/client'
import '@livekit/components-styles'

// FIX-104: /api/dm-calls/end braucht Auth (getApiClient).
// Ohne Bearer-Token bleiben dm_calls-Rows 'active' → blockiert nächsten Anruf.
async function endDmCall(callId: string): Promise<void> {
  try {
    const supabase = createClient()
    const { data: { session } } = await supabase.auth.getSession()
    await fetch('/api/dm-calls/end', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {}),
      },
      body: JSON.stringify({ callId }),
      keepalive: true,
    })
  } catch { /* best effort */ }
}

// ─── Typen ────────────────────────────────────────────────────────────────────

export interface LiveRoomProps {
  roomName: string
  token: string
  serverUrl: string
  title: string
  isDMCall?: boolean
  dmCallId?: string
  answeredAt?: string | null
  partnerName?: string
  partnerAvatar?: string | null
  onClose: () => void
}

// ─── Avatar (Mensaena-Style mit Teal-Ring) ────────────────────────────────────

function Avatar({
  name,
  avatarUrl,
  size = 80,
  ring = true,
}: { name: string; avatarUrl?: string | null; size?: number; ring?: boolean }) {
  const ringClass = ring ? 'ring-2 ring-primary-400/40 shadow-glow-teal' : ''
  if (avatarUrl) {
    return (
      <div className={`rounded-full overflow-hidden ${ringClass}`} style={{ width: size, height: size }}>
        <Image src={avatarUrl} alt={name} width={size} height={size} className="object-cover w-full h-full" />
      </div>
    )
  }
  return (
    <div
      className={`rounded-full bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center text-white font-bold ${ringClass}`}
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
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

  const [micEnabled, setMicEnabled] = useState(true)
  const [camEnabled, setCamEnabled] = useState(false)
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user')
  const [isFlipping, setIsFlipping] = useState(false)
  const [isReconnecting, setIsReconnecting] = useState(false)

  const videoTracks = useTracks([Track.Source.Camera], { onlySubscribed: false })
  const allAudioTracks = useTracks([Track.Source.Microphone], { onlySubscribed: true })
  const remoteParticipants = participants.filter(p => p.identity !== (localParticipant?.identity ?? ''))

  // Reconnect-Banner
  useEffect(() => {
    const onR = () => setIsReconnecting(true)
    const onC = () => setIsReconnecting(false)
    room.on(RoomEvent.Reconnecting, onR)
    room.on(RoomEvent.Reconnected, onC)
    room.on(RoomEvent.Disconnected, onC)
    return () => {
      room.off(RoomEvent.Reconnecting, onR)
      room.off(RoomEvent.Reconnected, onC)
      room.off(RoomEvent.Disconnected, onC)
    }
  }, [room])

  // FIX-103: KEIN 30s-Timeout im Raum mehr. CallingOverlay handhabt die
  // Ringing-Phase (45s). Sobald beide im Raum sind, gibt es keine
  // automatische Beendigung außer durch explizites Hangup oder Server-Status.

  // FIX-103: 15s-Grace bei Partner-Disconnect (statt 3s).
  // LiveKit reconnected oft 5-10s, Mobile-Netze können kurz wegbrechen.
  // Doppelte Sicherheit: nur beenden wenn Room nicht in Reconnecting-State.
  const partnerLeftRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  useEffect(() => {
    if (!isDMCall || !dmCallId) return
    const clearGrace = () => {
      if (partnerLeftRef.current) {
        clearTimeout(partnerLeftRef.current)
        partnerLeftRef.current = null
      }
    }
    const onLeft = () => {
      clearGrace()
      try {
        if (room.remoteParticipants.size > 0) return
      } catch { return }
      partnerLeftRef.current = setTimeout(() => {
        partnerLeftRef.current = null
        try {
          // Doppel-Check: Wirklich niemand mehr im Raum UND nicht am reconnecten?
          if (room.remoteParticipants.size > 0) return
          if (room.state === ConnectionState.Reconnecting) return
        } catch { return }
        void endDmCall(dmCallId)
        onHangup()
      }, 15_000)
    }
    const onJoined = () => clearGrace()
    room.on(RoomEvent.ParticipantDisconnected, onLeft)
    room.on(RoomEvent.ParticipantConnected, onJoined)
    return () => {
      try {
        room.off(RoomEvent.ParticipantDisconnected, onLeft)
        room.off(RoomEvent.ParticipantConnected, onJoined)
      } catch { /* room evtl. schon disposed */ }
      clearGrace()
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDMCall, dmCallId, room])

  // Server beendet Call (Supabase Realtime)
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
    if (!localParticipant) return
    try {
      await localParticipant.setMicrophoneEnabled(!micEnabled)
      setMicEnabled(v => !v)
    } catch (e) {
      const msg = (e as Error)?.message ?? 'unbekannt'
      if (/permission|notallowed/i.test(msg)) {
        toast.error('Mikrofon-Zugriff verweigert. Bitte in den Einstellungen erlauben.')
      } else {
        toast.error('Mikrofon: ' + msg)
      }
    }
  }, [localParticipant, micEnabled])

  const toggleCam = useCallback(async () => {
    if (!localParticipant) return
    try {
      await localParticipant.setCameraEnabled(!camEnabled, { facingMode })
      setCamEnabled(v => !v)
    } catch (e) {
      const msg = (e as Error)?.message ?? 'unbekannt'
      if (/permission|notallowed/i.test(msg)) {
        toast.error('Kamera-Zugriff verweigert. Bitte in den Einstellungen erlauben.')
      } else if (/notfound|devicenotfound/i.test(msg)) {
        toast.error('Keine Kamera gefunden')
      } else {
        toast.error('Kamera: ' + msg)
      }
    }
  }, [localParticipant, camEnabled, facingMode])

  const flipCamera = useCallback(async () => {
    if (!camEnabled || isFlipping || !localParticipant) return
    setIsFlipping(true)
    const next: 'user' | 'environment' = facingMode === 'user' ? 'environment' : 'user'
    try {
      // Sanft: erst neue Kamera anfordern, dann State updaten
      await localParticipant.setCameraEnabled(false)
      await localParticipant.setCameraEnabled(true, { facingMode: next })
      setFacingMode(next)
    } catch {
      // Fallback: alte Kamera wieder einschalten
      try {
        await localParticipant.setCameraEnabled(true, { facingMode })
      } catch { /* best effort */ }
      toast.error('Kamera-Wechsel fehlgeschlagen')
    } finally {
      setIsFlipping(false)
    }
  }, [camEnabled, facingMode, isFlipping, localParticipant])

  const handleHangup = useCallback(async () => {
    if (isDMCall && dmCallId) await endDmCall(dmCallId)
    onHangup()
  }, [isDMCall, dmCallId, onHangup])

  // FIX-104: Null-safe – localParticipant kann waehrend Connect undefined sein
  const localId = localParticipant?.identity
  const localVideoTrack = localId ? videoTracks.find(t => t.participant.identity === localId) : undefined
  const remoteVideoTrack = localId ? videoTracks.find(t => t.participant.identity !== localId) : videoTracks[0]
  const hasRemoteVideo = !!remoteVideoTrack?.publication?.isSubscribed

  const mainParticipant: Participant | undefined = remoteParticipants[0]
  const isConnected = connectionState === ConnectionState.Connected

  return (
    <div className="flex flex-col h-full bg-gray-950 text-white">
      {/* Header — Mensaena Gradient */}
      <div className="flex-shrink-0 relative flex items-center justify-between px-5 py-3.5 bg-gradient-to-b from-gray-900 to-gray-950 border-b border-white/[0.06]">
        <div className="flex flex-col">
          <span className="flex items-center gap-1.5 text-[10px] font-bold text-primary-400 uppercase tracking-widest">
            <span className="w-1.5 h-1.5 rounded-full bg-primary-400 animate-pulse" />
            Live
          </span>
          <p className="text-sm font-semibold text-white truncate max-w-[220px] leading-tight mt-0.5">{title}</p>
        </div>
        <div className="flex items-center gap-3">
          {timerStr && (
            <span className="text-sm text-primary-400 font-mono font-medium">{timerStr}</span>
          )}
          <span className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-400' : 'bg-yellow-400 animate-pulse'}`} />
        </div>
        {/* Reconnect-Banner */}
        {isReconnecting && (
          <div className="absolute left-0 right-0 top-full bg-yellow-500/90 text-black text-center text-xs font-medium py-1.5 flex items-center justify-center gap-2 z-10">
            <Loader2 className="w-3.5 h-3.5 animate-spin" />
            Verbindung wird wiederhergestellt…
          </div>
        )}
      </div>

      {/* Haupt-Video-Bereich */}
      <div className="flex-1 relative overflow-hidden bg-gradient-to-b from-gray-900 to-gray-950">
        {isDMCall ? (
          // DM-Call: 1-zu-1 Layout
          <div className="h-full flex flex-col items-center justify-center">
            {hasRemoteVideo && remoteVideoTrack ? (
              <>
                <VideoTrack trackRef={remoteVideoTrack} className="w-full h-full object-cover" />
                {/* Name-Overlay unten */}
                <div className="absolute bottom-6 left-6 px-3 py-1.5 rounded-full bg-black/50 backdrop-blur-md text-sm font-medium text-white">
                  {mainParticipant?.name ?? partnerName ?? 'Partner'}
                </div>
              </>
            ) : (
              <div className="flex flex-col items-center gap-5">
                <Avatar name={mainParticipant?.name ?? partnerName ?? '?'} avatarUrl={partnerAvatar} size={120} />
                <div className="text-center">
                  <p className="text-white text-xl font-semibold">{mainParticipant?.name ?? partnerName ?? 'Teilnehmer'}</p>
                  {!isConnected && <p className="text-white/50 text-sm mt-1">Verbindet…</p>}
                  {isConnected && remoteParticipants.length === 0 && (
                    <p className="text-primary-400 text-sm mt-1 animate-pulse">Warte auf Partner…</p>
                  )}
                </div>
                {allAudioTracks
                  .filter(t => t.participant.identity !== (localParticipant?.identity ?? ''))
                  .map(t => <AudioTrack key={t.publication.trackSid} trackRef={t} />)
                }
              </div>
            )}
          </div>
        ) : (
          // Community-Livestream: Raster
          <div
            className="h-full grid gap-2 p-2"
            style={{
              gridTemplateColumns: participants.length === 1 ? '1fr' : participants.length <= 4 ? 'repeat(2, 1fr)' : 'repeat(3, 1fr)',
              gridAutoRows: '1fr',
            }}
          >
            {participants.map(p => {
              const camTrack = videoTracks.find(t => t.participant.identity === p.identity)
              const hasVideo = (camTrack?.publication?.isSubscribed || p.identity === (localParticipant?.identity ?? '')) && camTrack
              const isLocal = p.identity === (localParticipant?.identity ?? '')
              return (
                <div
                  key={p.identity}
                  className="relative rounded-2xl overflow-hidden bg-gray-800 flex items-center justify-center ring-1 ring-white/5"
                >
                  {hasVideo ? (
                    <VideoTrack trackRef={camTrack} className="w-full h-full object-cover" />
                  ) : (
                    <Avatar name={p.name ?? p.identity} size={64} ring={false} />
                  )}
                  {/* Name + Avatar-Overlay */}
                  <div className="absolute bottom-2 left-2 right-2 flex items-center gap-2">
                    <div className="flex items-center gap-2 px-2.5 py-1 rounded-full bg-black/60 backdrop-blur-md max-w-full">
                      {!hasVideo && (
                        <span className="w-4 h-4 rounded-full bg-primary-500 flex items-center justify-center text-[9px] font-bold text-white shrink-0">
                          {(p.name ?? p.identity)[0]?.toUpperCase() ?? '?'}
                        </span>
                      )}
                      <span className="text-xs text-white truncate">
                        {p.name ?? p.identity}
                        {isLocal && <span className="text-primary-400 ml-1">(Du)</span>}
                      </span>
                    </div>
                  </div>
                  {!isLocal &&
                    allAudioTracks
                      .filter(t => t.participant.identity === p.identity)
                      .map(t => <AudioTrack key={t.publication.trackSid} trackRef={t} />)
                  }
                </div>
              )
            })}
          </div>
        )}

        {/* Lokale Kamera-Vorschau (PiP für DM-Call) */}
        {isDMCall && camEnabled && localVideoTrack && (
          <div className="absolute bottom-5 right-5 w-28 h-36 rounded-2xl overflow-hidden ring-2 ring-primary-400/60 shadow-glow-teal">
            <VideoTrack trackRef={localVideoTrack} className="w-full h-full object-cover" />
            <div className="absolute bottom-1 left-1 right-1 text-center text-[10px] text-white bg-black/40 rounded px-1 py-0.5">
              Du
            </div>
          </div>
        )}
      </div>

      {/* Steuerleiste — Mensaena-Style */}
      <div className="flex-shrink-0 flex items-center justify-center gap-4 py-5 px-4 bg-gradient-to-t from-gray-900 to-gray-950 border-t border-white/[0.06]">
        {/* Mikrofon */}
        <button
          onClick={toggleMic}
          className={`w-13 h-13 rounded-full flex items-center justify-center transition-all active:scale-95 shadow-lg ${
            micEnabled
              ? 'bg-white/[0.08] hover:bg-white/15 text-white ring-1 ring-white/10'
              : 'bg-red-500 hover:bg-red-600 text-white shadow-red-500/30'
          }`}
          style={{ width: 52, height: 52 }}
          aria-label={micEnabled ? 'Mikrofon stumm' : 'Mikrofon an'}
        >
          {micEnabled ? <Mic className="w-5 h-5" /> : <MicOff className="w-5 h-5" />}
        </button>

        {/* Kamera */}
        <button
          onClick={toggleCam}
          className={`w-13 h-13 rounded-full flex items-center justify-center transition-all active:scale-95 shadow-lg ${
            camEnabled
              ? 'bg-primary-500 hover:bg-primary-600 text-white shadow-primary-500/30'
              : 'bg-white/[0.08] hover:bg-white/15 text-white ring-1 ring-white/10'
          }`}
          style={{ width: 52, height: 52 }}
          aria-label={camEnabled ? 'Kamera aus' : 'Kamera an'}
        >
          {camEnabled ? <Video className="w-5 h-5" /> : <VideoOff className="w-5 h-5" />}
        </button>

        {/* Auflegen — größer, zentral */}
        <button
          onClick={handleHangup}
          className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center transition-all shadow-lg shadow-red-500/40"
          aria-label="Auflegen"
        >
          <PhoneOff className="w-7 h-7 text-white" />
        </button>

        {/* Kamera flip — nur sichtbar wenn Kamera an */}
        {camEnabled && (
          <button
            onClick={flipCamera}
            disabled={isFlipping}
            className="w-13 h-13 rounded-full flex items-center justify-center transition-all active:scale-95 bg-white/[0.08] hover:bg-white/15 text-white ring-1 ring-white/10 shadow-lg disabled:opacity-50"
            style={{ width: 52, height: 52 }}
            aria-label="Kamera wechseln"
          >
            {isFlipping ? <Loader2 className="w-5 h-5 animate-spin" /> : <SwitchCamera className="w-5 h-5" />}
          </button>
        )}
      </div>
    </div>
  )
}

// ─── Öffentliche LiveRoom-Komponente ──────────────────────────────────────────

export default function LiveRoom(props: LiveRoomProps) {
  const { token, serverUrl, title, isDMCall, onClose } = props
  const hangupCalledRef = useRef(false)

  useEffect(() => {
    void startForegroundService({
      title,
      onHangup: () => {
        if (!hangupCalledRef.current) {
          hangupCalledRef.current = true
          if (isDMCall && props.dmCallId) void endDmCall(props.dmCallId)
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
    if (reason === DisconnectReason.CLIENT_INITIATED) {
      handleHangup()
    }
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
