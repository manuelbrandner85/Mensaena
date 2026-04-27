'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import {
  X, MicOff, Mic, VideoOff, Video, PhoneOff,
  Loader2, FlipHorizontal2, Volume2, VolumeX,
  ScreenShare, ScreenShareOff, Hand, Users,
} from 'lucide-react'
import {
  LiveKitRoom,
  RoomAudioRenderer,
  useParticipants,
  useLocalParticipant,
  useRoomContext,
  useTracks,
  VideoTrack,
  useConnectionState,
} from '@livekit/components-react'
import { Track, RoomEvent, ConnectionState } from 'livekit-client'
import type { Participant, RemoteParticipant } from 'livekit-client'
import type { TrackReference, TrackReferenceOrPlaceholder } from '@livekit/components-react'
import '@livekit/components-styles'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import { createClient } from '@/lib/supabase/client'
import { useNavigationStore } from '@/store/useNavigationStore'
import toast from 'react-hot-toast'

const LIVEKIT_CLOUD_URL = 'wss://mensaena-atyyhep6.livekit.cloud'

// Avatar-URL-Cache (verhindert doppeltes Laden)
const avatarCache = new Map<string, string | null>()

interface LiveRoomModalProps {
  roomName: string
  channelLabel: string
  userName: string
  userAvatar?: string | null
  onClose: () => void
}

// ─── Hilfsfunktionen ──────────────────────────────────────────────────────────

function isRealTrack(ref: TrackReferenceOrPlaceholder | undefined): ref is TrackReference {
  return !!ref && 'publication' in ref && ref.publication != null
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// ─── Profilbild-Hook (lädt per Supabase, cached lokal) ───────────────────────

function useParticipantAvatar(
  identity: string,
  localIdentity: string,
  localAvatarUrl: string | null | undefined,
): string | null {
  const [avatarUrl, setAvatarUrl] = useState<string | null>(() => {
    if (identity === localIdentity) return localAvatarUrl ?? null
    return avatarCache.get(identity) ?? null
  })

  useEffect(() => {
    if (identity === localIdentity) {
      setAvatarUrl(localAvatarUrl ?? null)
      return
    }
    if (avatarCache.has(identity)) {
      setAvatarUrl(avatarCache.get(identity) ?? null)
      return
    }
    const supabase = createClient()
    supabase.from('profiles')
      .select('avatar_url')
      .eq('id', identity)
      .maybeSingle()
      .then(({ data }) => {
        const url = data?.avatar_url ?? null
        avatarCache.set(identity, url)
        setAvatarUrl(url)
      })
  }, [identity, localIdentity, localAvatarUrl])

  return avatarUrl
}

// ─── Einzelner Teilnehmer-Kreis ───────────────────────────────────────────────

interface ParticipantTileProps {
  participant: Participant
  cameraTrack?: TrackReferenceOrPlaceholder
  localIdentity: string
  localAvatarUrl?: string | null
  raisedHand?: boolean
  size?: 'lg' | 'md' | 'sm'
}

function ParticipantTile({
  participant,
  cameraTrack,
  localIdentity,
  localAvatarUrl,
  raisedHand = false,
  size = 'md',
}: ParticipantTileProps) {
  const avatarUrl = useParticipantAvatar(participant.identity, localIdentity, localAvatarUrl)
  const name = participant.name || 'Mitglied'
  const initials = name.trim().split(/\s+/).map((w: string) => w[0]).join('').slice(0, 2).toUpperCase()
  const isSpeaking = participant.isSpeaking
  const isMuted = !participant.isMicrophoneEnabled

  const dim = size === 'lg' ? 'w-32 h-32' : size === 'sm' ? 'w-16 h-16' : 'w-[88px] h-[88px]'
  const textSize = size === 'lg' ? 'text-3xl' : size === 'sm' ? 'text-base' : 'text-2xl'
  const badgeDim = size === 'sm' ? 'w-5 h-5' : 'w-6 h-6'
  const badgeIcon = size === 'sm' ? 'w-2.5 h-2.5' : 'w-3 h-3'
  const nameWidth = size === 'sm' ? 'max-w-[60px] text-[10px]' : 'max-w-[100px] text-xs'

  return (
    <div className="flex flex-col items-center gap-2 select-none">
      <div className="relative">
        {/* Sprecher-Halo */}
        {isSpeaking && (
          <div className="absolute -inset-2 rounded-full bg-primary-500/20 animate-ping pointer-events-none" />
        )}

        {/* Avatar-Kreis */}
        <div
          className={[
            'relative rounded-full overflow-hidden ring-2 transition-all duration-300',
            dim,
            isSpeaking
              ? 'ring-primary-400 shadow-[0_0_20px_4px_rgba(30,170,166,0.4)]'
              : 'ring-white/10',
          ].join(' ')}
        >
          {isRealTrack(cameraTrack) ? (
            <VideoTrack trackRef={cameraTrack} className="w-full h-full object-cover" />
          ) : avatarUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={avatarUrl} alt={name} className="w-full h-full object-cover" />
          ) : (
            <div
              className={`w-full h-full bg-gradient-to-br from-primary-600 to-primary-800 flex items-center justify-center text-white font-semibold ${textSize}`}
            >
              {initials}
            </div>
          )}
        </div>

        {/* Stummgeschaltet-Badge */}
        {isMuted && (
          <div className={`absolute -bottom-0.5 -right-0.5 ${badgeDim} rounded-full bg-gray-900 border border-white/10 flex items-center justify-center`}>
            <MicOff className={`${badgeIcon} text-red-400`} />
          </div>
        )}
        {/* Hand-heben-Badge */}
        {raisedHand && (
          <div className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-yellow-500 flex items-center justify-center text-[11px]">
            ✋
          </div>
        )}
      </div>

      <span className={`text-white/75 font-medium truncate text-center leading-tight ${nameWidth}`}>
        {name}
        {participant.identity === localIdentity && (
          <span className="text-white/30 ml-1 text-[10px]">(du)</span>
        )}
      </span>
    </div>
  )
}

// ─── Anruf-Timer ──────────────────────────────────────────────────────────────

function CallTimer() {
  const [seconds, setSeconds] = useState(0)
  useEffect(() => {
    const t = setInterval(() => setSeconds(s => s + 1), 1000)
    return () => clearInterval(t)
  }, [])
  return <span className="text-white/40 text-[10px] tabular-nums">{formatDuration(seconds)}</span>
}

// ─── Kontroll-Button ──────────────────────────────────────────────────────────

function ControlButton({
  children,
  onClick,
  active,
  activeClass,
  inactiveClass,
  label,
  disabled = false,
}: {
  children: React.ReactNode
  onClick: () => void
  active: boolean
  activeClass: string
  inactiveClass: string
  label: string
  disabled?: boolean
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      className={[
        'w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95',
        disabled ? 'opacity-30 cursor-not-allowed' : '',
        active ? activeClass : inactiveClass,
      ].join(' ')}
    >
      {children}
    </button>
  )
}

// ─── Innerer Raum (braucht LiveKitRoom-Kontext für Hooks) ─────────────────────

interface InnerRoomProps {
  onClose: () => void
  localAvatarUrl?: string | null
}

function InnerRoom({ onClose, localAvatarUrl }: InnerRoomProps) {
  const room = useRoomContext()
  const participants = useParticipants()
  const { localParticipant, isMicrophoneEnabled, isCameraEnabled } = useLocalParticipant()
  const cameraTracks = useTracks([{ source: Track.Source.Camera, withPlaceholder: false }])
  const screenTracks = useTracks([{ source: Track.Source.ScreenShare, withPlaceholder: false }])

  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user')
  const [isFlipping, setIsFlipping] = useState(false)
  const [speakerMuted, setSpeakerMuted] = useState(false)
  const [handRaised, setHandRaised] = useState(false)
  const [raisedHands, setRaisedHands] = useState<Set<string>>(new Set())

  const connectionState = useConnectionState()
  const isScreenSharing = screenTracks.some(t => t.participant.isLocal)

  // Autoplay-Sperre aufheben: Browser erlaubt Audio nach User-Geste
  useEffect(() => {
    if (connectionState === ConnectionState.Connected) {
      room.startAudio().catch(() => {})
    }
  }, [connectionState, room])

  // Hand-heben: Nachrichten von anderen Teilnehmern empfangen
  useEffect(() => {
    const decoder = new TextDecoder()
    const handler = (payload: Uint8Array, participant?: RemoteParticipant) => {
      try {
        const msg = JSON.parse(decoder.decode(payload))
        if (msg.type === 'raise-hand' && participant) {
          setRaisedHands(prev => {
            const next = new Set(prev)
            if (msg.raised) next.add(participant.identity)
            else next.delete(participant.identity)
            return next
          })
        }
      } catch { /* ungültige Nachricht ignorieren */ }
    }
    room.on(RoomEvent.DataReceived, handler)
    return () => { room.off(RoomEvent.DataReceived, handler) }
  }, [room])

  const toggleHand = () => {
    const next = !handRaised
    setHandRaised(next)
    localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'raise-hand', raised: next })),
      { reliable: true },
    )
  }

  const toggleScreenShare = async () => {
    try {
      await localParticipant.setScreenShareEnabled(!isScreenSharing)
    } catch {
      toast.error('Bildschirmfreigabe nicht verfügbar')
    }
  }

  const localIdentity = localParticipant.identity

  const getCameraTrack = useCallback(
    (identity: string) => cameraTracks.find(t => t.participant.identity === identity),
    [cameraTracks],
  )

  const toggleMic = async () => {
    try {
      await localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled)
    } catch {
      toast.error('Mikrofon-Zugriff verweigert')
    }
  }

  const toggleCamera = async () => {
    try {
      if (!isCameraEnabled) {
        await localParticipant.setCameraEnabled(true, { facingMode })
      } else {
        await localParticipant.setCameraEnabled(false)
      }
    } catch {
      toast.error('Kamera-Zugriff verweigert')
    }
  }

  const flipCamera = async () => {
    if (!isCameraEnabled || isFlipping) return
    setIsFlipping(true)
    const next: 'user' | 'environment' = facingMode === 'user' ? 'environment' : 'user'
    try {
      await localParticipant.setCameraEnabled(false)
      await localParticipant.setCameraEnabled(true, { facingMode: next })
      setFacingMode(next)
    } catch {
      toast.error('Kamera drehen fehlgeschlagen')
    } finally {
      setIsFlipping(false)
    }
  }

  const leave = () => {
    room.disconnect()
    onClose()
  }

  const count = participants.length
  const tileSize: 'lg' | 'md' | 'sm' =
    count === 1 ? 'lg' : count <= 4 ? 'md' : 'sm'

  return (
    <div className="flex flex-col h-full">
      {/* Teilnehmer-Raster */}
      <div className="flex-1 flex items-center justify-center p-6 overflow-hidden">
        {count === 0 ? (
          <p className="text-sm text-white/30 text-center">Warte auf Teilnehmer…</p>
        ) : (
          <div
            className={[
              'flex flex-wrap justify-center content-center',
              count <= 2 ? 'gap-10' : count <= 4 ? 'gap-6' : 'gap-4',
              count > 6 ? 'max-w-xs' : '',
            ].join(' ')}
          >
            {participants.map(p => (
              <ParticipantTile
                key={p.identity}
                participant={p}
                cameraTrack={getCameraTrack(p.identity)}
                localIdentity={localIdentity}
                localAvatarUrl={localAvatarUrl}
                raisedHand={p.identity === localIdentity ? handRaised : raisedHands.has(p.identity)}
                size={tileSize}
              />
            ))}
          </div>
        )}
      </div>

      {/* Kontrollleiste */}
      <div className="flex-shrink-0 px-5 pb-10 pt-2">
        {/* Sekundäre Aktionen */}
        <div className="flex items-center justify-center gap-3 mb-3">
          <button
            onClick={toggleHand}
            className={[
              'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
              handRaised
                ? 'bg-yellow-500/20 text-yellow-300'
                : 'bg-white/[0.08] text-white/50 hover:bg-white/15',
            ].join(' ')}
          >
            <Hand className="w-3.5 h-3.5" />
            {handRaised ? 'Hand senken' : 'Hand heben'}
          </button>
          <button
            onClick={toggleScreenShare}
            className={[
              'hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
              isScreenSharing
                ? 'bg-primary-500/20 text-primary-300'
                : 'bg-white/[0.08] text-white/50 hover:bg-white/15',
            ].join(' ')}
          >
            {isScreenSharing
              ? <ScreenShareOff className="w-3.5 h-3.5" />
              : <ScreenShare className="w-3.5 h-3.5" />}
            {isScreenSharing ? 'Teilen stoppen' : 'Teilen'}
          </button>
          <div className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-white/[0.06] text-white/30 text-xs">
            <Users className="w-3.5 h-3.5" />
            {count}
          </div>
        </div>

        <div className="flex items-center justify-center gap-3 bg-white/[0.06] backdrop-blur-xl rounded-[30px] py-4 px-6 border border-white/[0.08]">

          {/* Mikrofon */}
          <ControlButton
            onClick={toggleMic}
            active={isMicrophoneEnabled}
            activeClass="bg-white/12 hover:bg-white/20"
            inactiveClass="bg-red-500/20 hover:bg-red-500/30"
            label={isMicrophoneEnabled ? 'Stummschalten' : 'Ton aktivieren'}
          >
            {isMicrophoneEnabled
              ? <Mic className="w-5 h-5 text-white" />
              : <MicOff className="w-5 h-5 text-red-400" />}
          </ControlButton>

          {/* Kamera */}
          <ControlButton
            onClick={toggleCamera}
            active={isCameraEnabled}
            activeClass="bg-primary-500/20 hover:bg-primary-500/30"
            inactiveClass="bg-white/10 hover:bg-white/18"
            label={isCameraEnabled ? 'Kamera aus' : 'Kamera ein'}
          >
            {isCameraEnabled
              ? <Video className="w-5 h-5 text-primary-400" />
              : <VideoOff className="w-5 h-5 text-white/50" />}
          </ControlButton>

          {/* Verlassen — rot, groß */}
          <button
            onClick={leave}
            className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center transition-all shadow-lg shadow-red-500/30 mx-1"
            aria-label="Anruf beenden"
          >
            <PhoneOff className="w-6 h-6 text-white" />
          </button>

          {/* Kamera drehen */}
          <ControlButton
            onClick={flipCamera}
            active={isCameraEnabled && !isFlipping}
            activeClass="bg-white/10 hover:bg-white/18"
            inactiveClass="bg-white/5"
            label="Kamera drehen"
            disabled={!isCameraEnabled || isFlipping}
          >
            <FlipHorizontal2
              className={[
                'w-5 h-5 transition-all duration-300',
                isCameraEnabled && !isFlipping ? 'text-white' : 'text-white/25',
                isFlipping ? 'animate-spin' : '',
              ].join(' ')}
            />
          </ControlButton>

          {/* Lautsprecher */}
          <ControlButton
            onClick={() => setSpeakerMuted(m => !m)}
            active={!speakerMuted}
            activeClass="bg-white/10 hover:bg-white/18"
            inactiveClass="bg-red-500/20 hover:bg-red-500/30"
            label={speakerMuted ? 'Lautsprecher ein' : 'Lautsprecher aus'}
          >
            {speakerMuted
              ? <VolumeX className="w-5 h-5 text-red-400" />
              : <Volume2 className="w-5 h-5 text-white" />}
          </ControlButton>
        </div>

        {count > 0 && (
          <p className="text-center text-[10px] text-white/20 mt-2 tracking-wide">
            {count} Teilnehmer
          </p>
        )}
      </div>
      {/* LiveKit zeigt sonst einen "Audio starten"-Button → wir rufen startAudio() selbst auf */}
      <style>{`.lk-start-audio-button{display:none!important}`}</style>
    </div>
  )
}

// ─── Haupt-Modal ──────────────────────────────────────────────────────────────

export default function LiveRoomModal({
  roomName,
  channelLabel,
  userName,
  userAvatar,
  onClose,
}: LiveRoomModalProps) {
  const [token, setToken]           = useState<string | null>(null)
  const [serverUrl, setServerUrl]   = useState(LIVEKIT_CLOUD_URL)
  const [fetchError, setFetchError] = useState(false)
  const [visible, setVisible]       = useState(false)
  const setIsInCall                 = useNavigationStore(s => s.setIsInCall)
  const cleanedUp                   = useRef(false)

  useModalDismiss(onClose)

  // Navigationsleisten beim Öffnen ausblenden, beim Schließen wiederherstellen
  useEffect(() => {
    setIsInCall(true)
    cleanedUp.current = false
    return () => {
      if (!cleanedUp.current) {
        setIsInCall(false)
        cleanedUp.current = true
      }
    }
  }, [setIsInCall])

  // Einblend-Animation
  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  // Token holen (Bearer-Auth für Cloudflare Workers Edge)
  useEffect(() => {
    async function loadToken() {
      try {
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

  const handleClose = useCallback(() => {
    if (!cleanedUp.current) {
      setIsInCall(false)
      cleanedUp.current = true
    }
    onClose()
  }, [onClose, setIsInCall])

  return (
    <div
      className={[
        'fixed inset-0 z-[9999] flex flex-col bg-gray-950',
        'transition-opacity duration-300',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      {/* Header */}
      <div className="flex-shrink-0 relative flex items-center justify-center px-12 py-3 border-b border-white/[0.06]">
        <div className="text-center">
          <p className="text-[10px] font-semibold text-primary-400 uppercase tracking-widest">
            Live-Raum
          </p>
          <p className="text-sm font-semibold text-white leading-tight mt-0.5 truncate max-w-[180px]">
            {channelLabel}
          </p>
        </div>

        {/* Live + Timer links */}
        {token && (
          <div className="absolute left-4 flex flex-col items-start gap-0.5">
            <span className="flex items-center gap-1.5 text-[10px] text-green-400 font-semibold uppercase tracking-wide">
              <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
              Live
            </span>
            <CallTimer />
          </div>
        )}

        {/* Schließen */}
        <button
          onClick={handleClose}
          className="absolute right-3 w-8 h-8 flex items-center justify-center rounded-full bg-white/[0.08] hover:bg-white/15 text-white transition-colors"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Inhalt */}
      <div className="flex-1 relative overflow-hidden">
        {/* Laden */}
        {!token && !fetchError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
            <p className="text-sm text-white/40">Verbinde…</p>
          </div>
        )}

        {/* Fehler */}
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
              onClick={handleClose}
              className="mt-1 px-6 py-2.5 rounded-full bg-white/10 hover:bg-white/15 text-white text-sm font-medium transition-colors"
            >
              Zurück zum Chat
            </button>
          </div>
        )}

        {/* LiveKit-Raum */}
        {token && (
          <LiveKitRoom
            serverUrl={serverUrl}
            token={token}
            connect={true}
            video={false}
            audio={true}
            onDisconnected={handleClose}
            style={{ height: '100%', width: '100%', background: 'transparent' }}
          >
            <InnerRoom onClose={handleClose} localAvatarUrl={userAvatar} />
            <RoomAudioRenderer />
          </LiveKitRoom>
        )}
      </div>
    </div>
  )
}
