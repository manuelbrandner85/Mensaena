'use client'

import { useEffect, useState } from 'react'
import { X, MicOff, Mic, VideoOff, Video, PhoneOff, Loader2 } from 'lucide-react'
import {
  LiveKitRoom,
  RoomAudioRenderer,
  useParticipants,
  useLocalParticipant,
  useRoomContext,
  useTracks,
  VideoTrack,
} from '@livekit/components-react'
import { Track } from 'livekit-client'
import type { Participant } from 'livekit-client'
import type { TrackReference, TrackReferenceOrPlaceholder } from '@livekit/components-react'
import '@livekit/components-styles'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import { createClient } from '@/lib/supabase/client'

function isRealTrack(ref: TrackReferenceOrPlaceholder | undefined): ref is TrackReference {
  return !!ref && 'publication' in ref && ref.publication != null
}

const LIVEKIT_CLOUD_URL = 'wss://mensaena-atyyhep6.livekit.cloud'

interface LiveRoomModalProps {
  roomName: string
  channelLabel: string
  userName: string
  userAvatar?: string | null
  onClose: () => void
}

// ─── Single participant tile (Telegram-style) ─────────────────────────────────
function ParticipantTile({
  participant,
  cameraTrack,
}: {
  participant: Participant
  cameraTrack?: TrackReferenceOrPlaceholder
}) {
  const name = participant.name || 'Mitglied'
  const initials = name.slice(0, 2).toUpperCase()
  const isSpeaking = participant.isSpeaking
  const isMuted = !participant.isMicrophoneEnabled

  return (
    <div className="flex flex-col items-center gap-2">
      <div className="relative">
        {/* Speaking pulse ring */}
        {isSpeaking && (
          <div className="absolute -inset-2 rounded-full bg-primary-500/25 animate-ping" />
        )}

        {/* Avatar / video circle */}
        <div
          className={[
            'relative w-[88px] h-[88px] rounded-full overflow-hidden ring-2 transition-all duration-300',
            isSpeaking ? 'ring-primary-400 shadow-[0_0_16px_rgba(30,170,166,0.5)]' : 'ring-white/10',
          ].join(' ')}
        >
          {isRealTrack(cameraTrack) ? (
            <VideoTrack
              trackRef={cameraTrack}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-primary-700 to-primary-900 flex items-center justify-center text-white text-[26px] font-semibold select-none">
              {initials}
            </div>
          )}
        </div>

        {/* Muted badge */}
        {isMuted && (
          <div className="absolute -bottom-0.5 -right-0.5 w-6 h-6 rounded-full bg-gray-900 border border-white/10 flex items-center justify-center">
            <MicOff className="w-3 h-3 text-red-400" />
          </div>
        )}
      </div>

      <span className="text-xs text-white/70 font-medium max-w-[88px] truncate text-center leading-none">
        {name}
      </span>
    </div>
  )
}

// ─── Inner room – must live inside <LiveKitRoom> for hooks to work ─────────────
function InnerRoom({ channelLabel, onClose }: { channelLabel: string; onClose: () => void }) {
  const room = useRoomContext()
  const participants = useParticipants()
  const { localParticipant, isMicrophoneEnabled, isCameraEnabled } = useLocalParticipant()
  const cameraTracks = useTracks([{ source: Track.Source.Camera, withPlaceholder: false }])

  const getCameraTrack = (identity: string) =>
    cameraTracks.find(t => t.participant.identity === identity)

  const toggleMic = () => localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled)
  const toggleCamera = () => localParticipant.setCameraEnabled(!isCameraEnabled)
  const leave = () => {
    room.disconnect()
    onClose()
  }

  return (
    <div className="flex flex-col h-full select-none">
      {/* Participants grid */}
      <div className="flex-1 flex items-center justify-center px-6 py-4">
        <div
          className={[
            'flex flex-wrap justify-center gap-6',
            participants.length > 6 ? 'max-w-xs' : '',
          ].join(' ')}
        >
          {participants.map(p => (
            <ParticipantTile
              key={p.identity}
              participant={p}
              cameraTrack={getCameraTrack(p.identity)}
            />
          ))}

          {participants.length === 0 && (
            <p className="text-sm text-white/30 text-center">
              Warte auf Teilnehmer…
            </p>
          )}
        </div>
      </div>

      {/* Control bar – Telegram style */}
      <div className="flex-shrink-0 px-6 pb-10 pt-2">
        <div className="flex items-center justify-center gap-4 bg-white/[0.06] backdrop-blur-xl rounded-[28px] py-4 px-8 border border-white/[0.07]">

          {/* Mute */}
          <button
            onClick={toggleMic}
            className={[
              'w-14 h-14 rounded-full flex items-center justify-center transition-colors',
              isMicrophoneEnabled
                ? 'bg-white/10 hover:bg-white/18'
                : 'bg-red-500/20 hover:bg-red-500/30',
            ].join(' ')}
            aria-label={isMicrophoneEnabled ? 'Stummschalten' : 'Stummschaltung aufheben'}
          >
            {isMicrophoneEnabled
              ? <Mic className="w-5 h-5 text-white" />
              : <MicOff className="w-5 h-5 text-red-400" />
            }
          </button>

          {/* Leave (centered, red, prominent) */}
          <button
            onClick={leave}
            className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center transition-colors shadow-lg shadow-red-500/30 mx-2"
            aria-label="Verlassen"
          >
            <PhoneOff className="w-6 h-6 text-white" />
          </button>

          {/* Camera */}
          <button
            onClick={toggleCamera}
            className={[
              'w-14 h-14 rounded-full flex items-center justify-center transition-colors',
              isCameraEnabled
                ? 'bg-primary-500/20 hover:bg-primary-500/30'
                : 'bg-white/10 hover:bg-white/18',
            ].join(' ')}
            aria-label={isCameraEnabled ? 'Kamera ausschalten' : 'Kamera einschalten'}
          >
            {isCameraEnabled
              ? <Video className="w-5 h-5 text-primary-400" />
              : <VideoOff className="w-5 h-5 text-white/50" />
            }
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Main modal ───────────────────────────────────────────────────────────────
export default function LiveRoomModal({
  roomName,
  channelLabel,
  userName,
  onClose,
}: LiveRoomModalProps) {
  const [token, setToken]           = useState<string | null>(null)
  const [serverUrl, setServerUrl]   = useState(LIVEKIT_CLOUD_URL)
  const [fetchError, setFetchError] = useState(false)
  const [visible, setVisible]       = useState(false)

  useModalDismiss(onClose)

  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  useEffect(() => {
    async function loadToken() {
      try {
        // Always send the Supabase access token in the Authorization header.
        // Cookie-based auth is unreliable on Cloudflare Workers edge runtime.
        const supabase = createClient()
        const { data: { session } } = await supabase.auth.getSession()
        const accessToken = session?.access_token ?? ''

        const r = await fetch('/api/live-room/token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
          },
          body: JSON.stringify({ roomName, displayName: userName }),
        })
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        const { token: t, url } = await r.json()
        setToken(t)
        if (url) setServerUrl(url)
      } catch {
        setFetchError(true)
      }
    }
    loadToken()
  }, [roomName, userName])

  return (
    <div
      className={[
        'fixed inset-0 z-[70] flex flex-col bg-gray-950',
        'transition-opacity duration-200',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      {/* Header */}
      <div className="flex-shrink-0 relative flex items-center justify-center px-12 py-3.5 border-b border-white/[0.06]">
        <div className="text-center">
          <p className="text-[10px] font-semibold text-primary-400 uppercase tracking-widest">
            Live-Raum
          </p>
          <p className="text-sm font-semibold text-white leading-tight mt-0.5">
            {channelLabel}
          </p>
        </div>

        {token && (
          <span className="absolute left-4 flex items-center gap-1.5 text-[10px] text-green-400 font-semibold uppercase tracking-wide">
            <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
            Live
          </span>
        )}

        <button
          onClick={onClose}
          className="absolute right-3 w-8 h-8 flex items-center justify-center rounded-full bg-white/[0.08] hover:bg-white/15 text-white transition-colors"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 relative overflow-hidden">
        {/* Loading */}
        {!token && !fetchError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
            <p className="text-sm text-white/40">Verbinde…</p>
          </div>
        )}

        {/* Error */}
        {fetchError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 px-8 text-center">
            <div className="w-16 h-16 rounded-full bg-red-500/10 flex items-center justify-center">
              <PhoneOff className="w-7 h-7 text-red-400" />
            </div>
            <div>
              <p className="text-white font-semibold mb-1">Verbindung fehlgeschlagen</p>
              <p className="text-sm text-white/40">Bitte versuche es erneut.</p>
            </div>
            <button
              onClick={onClose}
              className="mt-1 px-6 py-2.5 rounded-full bg-white/10 hover:bg-white/15 text-white text-sm font-medium transition-colors"
            >
              Zurück zum Chat
            </button>
          </div>
        )}

        {/* LiveKit room */}
        {token && (
          <LiveKitRoom
            serverUrl={serverUrl}
            token={token}
            connect={true}
            video={false}
            audio={false}
            onDisconnected={onClose}
            style={{ height: '100%', width: '100%', background: 'transparent' }}
          >
            <InnerRoom channelLabel={channelLabel} onClose={onClose} />
            <RoomAudioRenderer />
          </LiveKitRoom>
        )}
      </div>
    </div>
  )
}
