'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import { createPortal } from 'react-dom'
import {
  X, MicOff, Mic, VideoOff, Video, PhoneOff,
  Loader2, SwitchCamera, Volume2, VolumeX,
  ScreenShare, ScreenShareOff, Hand, Users,
  Settings, Wifi, FlipHorizontal2, Send,
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
  useConnectionQualityIndicator,
} from '@livekit/components-react'
import { ConnectionQuality } from 'livekit-client'
import { Track, RoomEvent, ConnectionState, type MediaDeviceFailure } from 'livekit-client'
import type { Participant, RemoteParticipant } from 'livekit-client'
import type { TrackReference, TrackReferenceOrPlaceholder } from '@livekit/components-react'
import '@livekit/components-styles'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import {
  startCallForegroundService,
  updateCallForegroundService,
  stopCallForegroundService,
} from '@/hooks/useCallForegroundService' // FIX-43: Foreground Service
import { playEndTone } from '@/lib/audio/end-tone' // FEATURE: End-Ton
import { stopDialTone } from '@/lib/audio/dial-tone' // FIX-75
import { stopRingtone } from '@/lib/audio/ringtone' // FIX-75
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
  /** Wenn gesetzt: kein eigener Token-Fetch, dieser Token wird verwendet (1:1-Call). */
  preToken?: string
  /** LiveKit-Server-URL passend zu preToken. */
  preUrl?: string
  /** Wenn gesetzt: bei Disconnect wird POST /api/dm-calls/end aufgerufen. */
  dmCallId?: string
  /** FIX-10: ISO-Timestamp der Annahme für korrekte Timer-Berechnung bei Remount. */
  answeredAt?: string
  /** FIX-81: Wird gefeuert sobald der erste Remote-Participant joined.
   * Caller-Side: setzt answeredAt → CallingOverlay verschwindet, kein
   * False-Positive-"Missed" mehr wenn DB-Realtime hinkt. */
  onRemoteJoined?: () => void
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

// ─── Verbindungsqualitäts-Punkt ──────────────────────────────────────────────

function QualityDot({ participant, size }: { participant: Participant; size: 'lg' | 'md' | 'sm' }) {
  const { quality } = useConnectionQualityIndicator({ participant })
  if (quality === ConnectionQuality.Unknown) return null
  const color =
    quality === ConnectionQuality.Excellent ? 'bg-green-400' :
    quality === ConnectionQuality.Good      ? 'bg-yellow-400' :
    quality === ConnectionQuality.Poor      ? 'bg-red-400'    :
    'bg-gray-400'
  // FIX-TS: ConnectionQuality[quality] Typfehler — explizites Label-Mapping statt enum-Reverse-Lookup
  const qualityLabel =
    quality === ConnectionQuality.Excellent ? 'Ausgezeichnet' :
    quality === ConnectionQuality.Good      ? 'Gut' :
    quality === ConnectionQuality.Poor      ? 'Schlecht' : ''
  const dim = size === 'sm' ? 'w-2 h-2' : 'w-2.5 h-2.5'
  return (
    <div
      className={`absolute top-1 left-1 ${dim} rounded-full ${color} ring-2 ring-gray-900/60`}
      title={`Verbindung: ${qualityLabel}`}
    />
  )
}

// FEATURE: Admin/Mod-Badge — Rolle aus LiveKit-Metadata parsen
function getParticipantRole(participant: Participant): string {
  try {
    const meta = JSON.parse(participant.metadata ?? '{}')
    return meta.role ?? 'user'
  } catch {
    return 'user'
  }
}

// ─── Einzelner Teilnehmer-Kreis ───────────────────────────────────────────────

interface ParticipantTileProps {
  participant: Participant
  cameraTrack?: TrackReferenceOrPlaceholder
  localIdentity: string
  localAvatarUrl?: string | null
  raisedHand?: boolean
  size?: 'lg' | 'md' | 'sm'
  onClick?: () => void
  mirrorVideo?: boolean
  isFlipping?: boolean // FIX-23: Kamera-Wechsel Platzhalter
}

function ParticipantTile({
  participant,
  cameraTrack,
  localIdentity,
  localAvatarUrl,
  raisedHand = false,
  size = 'md',
  onClick,
  mirrorVideo = false,
  isFlipping = false,
}: ParticipantTileProps) {
  const avatarUrl = useParticipantAvatar(participant.identity, localIdentity, localAvatarUrl)
  const name = participant.name || 'Mitglied'
  const initials = name.trim().split(/\s+/).map((w: string) => w[0]).join('').slice(0, 2).toUpperCase()
  const isSpeaking = participant.isSpeaking
  const isMuted = !participant.isMicrophoneEnabled

  const dim = size === 'lg' ? 'w-60 h-60 sm:w-72 sm:h-72' : size === 'sm' ? 'w-16 h-16' : 'w-[88px] h-[88px]'
  const textSize = size === 'lg' ? 'text-6xl' : size === 'sm' ? 'text-base' : 'text-2xl'
  const badgeDim = size === 'sm' ? 'w-5 h-5' : size === 'lg' ? 'w-9 h-9' : 'w-6 h-6'
  const badgeIcon = size === 'sm' ? 'w-2.5 h-2.5' : size === 'lg' ? 'w-4 h-4' : 'w-3 h-3'
  const nameWidth = size === 'sm' ? 'max-w-[60px] text-[10px]' : size === 'lg' ? 'max-w-[200px] text-base' : 'max-w-[100px] text-xs'

  return (
    <div
      className={`flex flex-col items-center gap-2 select-none ${onClick ? 'cursor-pointer active:scale-95 transition-transform' : ''}`}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
    >
      <div className="relative">
        {/* Telegram-Style Schallwellen: zwei pulsierende Ringe leicht versetzt */}
        {isSpeaking && (
          <>
            <div className="absolute -inset-1 rounded-full ring-2 ring-primary-400/60 animate-[lk-wave_1.5s_ease-out_infinite] pointer-events-none" />
            <div className="absolute -inset-1 rounded-full ring-2 ring-primary-400/40 animate-[lk-wave_1.5s_ease-out_infinite_0.5s] pointer-events-none" />
          </>
        )}

        {/* Avatar-Kreis */}
        <div
          className={[
            'relative rounded-full overflow-hidden ring-2 transition-all duration-300',
            dim,
            isSpeaking
              ? 'ring-primary-400 shadow-[0_0_24px_6px_rgba(30,170,166,0.5)]'
              : 'ring-white/10',
          ].join(' ')}
        >
          {participant.identity === localIdentity && isFlipping ? (
            // FIX-23: Kamera-Wechsel Platzhalter — verhindert schwarzes Bild für Partner
            <div className="w-full h-full bg-gray-800 flex items-center justify-center">
              <SwitchCamera className="w-8 h-8 text-white/50 animate-spin" />
            </div>
          ) : isRealTrack(cameraTrack) ? (
            <VideoTrack
              trackRef={cameraTrack}
              className="w-full h-full object-cover"
              style={mirrorVideo ? { transform: 'scaleX(-1)' } : undefined}
            />
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

        {/* Verbindungsqualität */}
        <QualityDot participant={participant} size={size} />

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
        {/* FEATURE: Admin/Mod-Badge */}
        {(() => {
          const role = getParticipantRole(participant)
          if (role === 'admin') return (
            <div className="absolute -top-1 -left-1 px-1.5 py-0.5 rounded-full bg-red-500/90 text-white text-[9px] font-bold flex items-center gap-0.5 shadow-sm">
              🛡️ Admin
            </div>
          )
          if (role === 'moderator') return (
            <div className="absolute -top-1 -left-1 px-1.5 py-0.5 rounded-full bg-amber-500/90 text-white text-[9px] font-bold flex items-center gap-0.5 shadow-sm">
              ⚔️ Mod
            </div>
          )
          return null
        })()}
      </div>

      <span className={`text-white/75 font-medium truncate text-center leading-tight ${nameWidth}`}>
        {name}
        {participant.identity === localIdentity && (
          <span className="text-white/30 ml-1 text-[10px]">(du)</span>
        )}
        {/* FEATURE: Admin/Mod-Badge */}
        {(() => {
          const role = getParticipantRole(participant)
          if (role === 'admin') return (
            <span className="text-red-400 text-[9px] font-semibold ml-1">Admin</span>
          )
          if (role === 'moderator') return (
            <span className="text-amber-400 text-[9px] font-semibold ml-1">Mod</span>
          )
          return null
        })()}
      </span>
    </div>
  )
}

// ─── Anruf-Timer ──────────────────────────────────────────────────────────────

// FIX-10: Timer ab answered_at statt 0
function CallTimer({ answeredAt }: { answeredAt?: string }) {
  const [seconds, setSeconds] = useState(() => {
    if (!answeredAt) return 0
    return Math.max(0, Math.floor((Date.now() - new Date(answeredAt).getTime()) / 1000))
  })
  useEffect(() => {
    const t = setInterval(() => {
      if (answeredAt) {
        setSeconds(Math.max(0, Math.floor((Date.now() - new Date(answeredAt).getTime()) / 1000)))
      } else {
        setSeconds(s => s + 1)
      }
    }, 1000)
    return () => clearInterval(t)
  }, [answeredAt])
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
      type="button"
      onClick={(e) => { e.stopPropagation(); onClick() }}
      onTouchEnd={(e) => { e.stopPropagation() }}
      disabled={disabled}
      aria-label={label}
      style={{ touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}
      className={[
        'w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95 cursor-pointer relative',
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
  viewerMode?: boolean
  roomName?: string
  isLandscape?: boolean
  dmCallId?: string // FIX-3: Rollback bei Token-Fehler
  /** WA-FIX: true = 1:1-DM-Call → vereinfachte Controls (nur Mute/Camera/Auflegen) */
  isDMCall?: boolean
  /** FIX-81: Callback sobald Remote-Participant joined */
  onRemoteJoined?: () => void
}

function InnerRoom({ onClose, localAvatarUrl, viewerMode = false, roomName = '', isLandscape = false, dmCallId, isDMCall = false, onRemoteJoined }: InnerRoomProps) {
  const room = useRoomContext()
  const participants = useParticipants()
  const { localParticipant, isMicrophoneEnabled, isCameraEnabled } = useLocalParticipant()
  const cameraTracks = useTracks([{ source: Track.Source.Camera, withPlaceholder: false }])
  const screenTracks = useTracks([{ source: Track.Source.ScreenShare, withPlaceholder: false }])

  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user')
  const [isFlipping, setIsFlipping] = useState(false)
  const [speakerMuted, setSpeakerMuted] = useState(false)
  const [volume, setVolume] = useState(1)             // 0..2 (Web-Audio Boost bis 200%)
  const [showSettings, setShowSettings] = useState(false)
  const [mirrorOwnVideo, setMirrorOwnVideo] = useState(true)
  const [audioInputs, setAudioInputs] = useState<MediaDeviceInfo[]>([])
  const [videoInputs, setVideoInputs] = useState<MediaDeviceInfo[]>([])
  const [handRaised, setHandRaised] = useState(false)
  const [raisedHands, setRaisedHands] = useState<Set<string>>(new Set())
  const [reactions, setReactions] = useState<Array<{ id: number; emoji: string; identity: string }>>([])
  const [pushToTalk, setPushToTalk] = useState(false)
  const [showParticipants, setShowParticipants] = useState(false)
  const [backgroundBlur, setBackgroundBlur] = useState(false)
  const reactionIdRef = useRef(0)
  const [pinnedIdentity, setPinnedIdentity] = useState<string | null>(null)
  const [autoFocus, setAutoFocus] = useState(true)
  const [manualPin, setManualPin] = useState(false)
  const [permState, setPermState] = useState<{ mic?: PermissionState; cam?: PermissionState }>({})
  // FIX-76/81: Permission-Warnung nur einmal anzeigen – Dismissal persistieren
  // damit die Warnung nach erstem Wegtippen nie wieder erscheint (auch nicht
  // bei jedem Call-Open).
  const [permDismissed, setPermDismissed] = useState(() => {
    if (typeof window === 'undefined') return false
    try { return localStorage.getItem('mensaena.permWarnDismissed') === '1' } catch { return false }
  })
  const dismissPermWarn = useCallback(() => {
    setPermDismissed(true)
    try { localStorage.setItem('mensaena.permWarnDismissed', '1') } catch {}
  }, [])
  // FIX-11: Audio-Output-Wechsel
  const [speakerActive, setSpeakerActive] = useState(false)

  // Chat-Sidebar
  const [showChat, setShowChat] = useState(false)
  const [chatMessages, setChatMessages] = useState<Array<{ id: string; sender: string; text: string; ts: number }>>([])
  const [chatInput, setChatInput] = useState('')
  const chatEndRef = useRef<HTMLDivElement>(null)
  // FIX-27: Intelligentes Chat-Scroll
  const chatContainerRef = useRef<HTMLDivElement>(null)
  const isChatNearBottomRef = useRef(true)

  // Vollbild für Screen-Share
  const [fullscreenSharer, setFullscreenSharer] = useState<string | null>(null)

  const connectionState = useConnectionState()
  const isConnected = connectionState === ConnectionState.Connected
  const isScreenSharing = screenTracks.some(t => t.participant.isLocal)

  // Mobile WebView (iOS/Android) kann kein getDisplayMedia – Button ausblenden
  const isMobile = typeof navigator !== 'undefined' &&
    (/Android|iPhone|iPad|iPod/i.test(navigator.userAgent) ||
     !navigator.mediaDevices?.getDisplayMedia)

  const isIOS = typeof navigator !== 'undefined' && /iPhone|iPad|iPod/i.test(navigator.userAgent)
  const isAndroid = typeof navigator !== 'undefined' && /Android/i.test(navigator.userAgent)
  // Capacitor-WebView erkennen: enthält "wv" oder "Mensaena" im UA, oder Capacitor-globale
  const isCapacitor = typeof window !== 'undefined' && (
    !!(window as { Capacitor?: unknown }).Capacitor ||
    /Mensaena|Capacitor/i.test(navigator.userAgent ?? '') ||
    /\bwv\b/.test(navigator.userAgent ?? '')
  )

  const micDenied = permState.mic === 'denied'
  const camDenied = permState.cam === 'denied'
  const anyDenied = micDenied || camDenied

  // Permission-Status beim Öffnen abfragen
  const checkPermissions = useCallback(async () => {
    if (typeof navigator === 'undefined' || !navigator.permissions) return
    try {
      const mic = await navigator.permissions.query({ name: 'microphone' as PermissionName })
      setPermState(s => ({ ...s, mic: mic.state }))
      mic.onchange = () => setPermState(s => ({ ...s, mic: mic.state }))
    } catch { /* nicht alle Browser unterstützen 'microphone' */ }
    try {
      const cam = await navigator.permissions.query({ name: 'camera' as PermissionName })
      setPermState(s => ({ ...s, cam: cam.state }))
      cam.onchange = () => setPermState(s => ({ ...s, cam: cam.state }))
    } catch { /* nicht alle Browser unterstützen 'camera' */ }
  }, [])

  useEffect(() => { checkPermissions() }, [checkPermissions])

  const handlePermErr = (kind: 'Mikrofon' | 'Kamera', err: Error) => {
    const msg = err.message || ''
    if (/Permission denied|NotAllowed/i.test(msg)) {
      toast.error(`${kind}-Zugriff verweigert. Bitte in den App-Einstellungen erlauben.`, { duration: 6000 })
    } else if (/NotFound|DeviceNotFound/i.test(msg)) {
      toast.error(`Kein ${kind} gefunden`)
    } else {
      toast.error(`${kind}: ${msg}`)
    }
  }

  // Autoplay-Sperre aufheben: Browser erlaubt Audio nach User-Geste
  useEffect(() => {
    if (isConnected) {
      room.startAudio().catch(() => {})
    }
  }, [isConnected, room])

  // FIX-80/81: Timeout NUR wenn Partner nie joined. Sobald Partner im Raum
  // ist, Timeout abbrechen + onRemoteJoined feuern → CallingOverlay schließt
  // auch wenn DB-Realtime nicht ankommt → unbegrenzte Gesprächsdauer.
  const dmTimeoutFiredRef = useRef(false)
  const onRemoteJoinedRef = useRef(onRemoteJoined)
  useEffect(() => { onRemoteJoinedRef.current = onRemoteJoined }, [onRemoteJoined])
  useEffect(() => {
    if (!isConnected || !dmCallId || dmTimeoutFiredRef.current) return
    // Partner schon da? → kein Timeout nötig + sofort signalisieren
    if (room.remoteParticipants.size > 0) {
      dmTimeoutFiredRef.current = true
      onRemoteJoinedRef.current?.()
      return
    }

    const timeout = setTimeout(() => {
      if (room.remoteParticipants.size === 0) {
        dmTimeoutFiredRef.current = true
        fetch('/api/dm-calls/end', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ callId: dmCallId }),
        }).catch(() => {})
        toast.error('Dein Gesprächspartner konnte nicht verbinden')
        room.disconnect().catch(() => {})
        onClose()
      }
    }, 45_000)

    const handleJoin = (): void => {
      clearTimeout(timeout)
      dmTimeoutFiredRef.current = true
      onRemoteJoinedRef.current?.()
    }
    room.on(RoomEvent.ParticipantConnected, handleJoin)

    return () => {
      clearTimeout(timeout)
      room.off(RoomEvent.ParticipantConnected, handleJoin)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, dmCallId, room])

  // FIX-75: Partner hat Raum verlassen → Call für beide beenden
  useEffect(() => {
    if (!isConnected || !dmCallId) return
    const handler = () => {
      if (room.remoteParticipants.size === 0) {
        // 3s Grace-Period – könnte kurzer Reconnect sein
        const timeout = setTimeout(() => {
          if (room.remoteParticipants.size === 0) {
            playEndTone()
            void stopCallForegroundService()
            fetch('/api/dm-calls/end', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ callId: dmCallId }),
            }).catch(() => {})
            room.disconnect().catch(() => {})
            onClose()
          }
        }, 3000)
        return () => clearTimeout(timeout)
      }
    }
    room.on(RoomEvent.ParticipantDisconnected, handler)
    return () => { room.off(RoomEvent.ParticipantDisconnected, handler) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, dmCallId, room])

  // FIX-75: DB-Status-Listener – Partner hat aufgelegt
  // FIX-79: Stabile Refs + uniques Channel-Suffix verhindern
  // "cannot add postgres_changes callbacks after subscribe()" durch
  // Supabase-Channel-Cache bei React-StrictMode-Doppel-Mount oder
  // Re-Render mit neuem onClose.
  const onCloseRef = useRef(onClose)
  const roomRef = useRef(room)
  useEffect(() => { onCloseRef.current = onClose }, [onClose])
  useEffect(() => { roomRef.current = room }, [room])
  useEffect(() => {
    if (!dmCallId) return
    const supabase = createClient()
    const channelKey = `dm-call-end-${dmCallId}-${Math.random().toString(36).slice(2, 8)}`
    const channel = supabase
      .channel(channelKey)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'dm_calls',
          filter: `id=eq.${dmCallId}`,
        },
        (payload) => {
          const status = (payload.new as { status: string }).status
          if (['ended', 'declined', 'missed', 'cancelled'].includes(status)) {
            playEndTone()
            void stopCallForegroundService()
            roomRef.current.disconnect().catch(() => {})
            onCloseRef.current()
          }
        },
      )
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [dmCallId])

  // FIX-75: Wählton/Klingeln stoppen sobald Partner im Raum ist
  useEffect(() => {
    if (!isConnected || !dmCallId) return
    const remoteCount = participants.filter(
      (p) => p.identity !== localParticipant.identity,
    ).length
    if (remoteCount > 0) {
      try { stopDialTone() } catch {}
      try { stopRingtone() } catch {}
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, dmCallId, participants, localParticipant.identity])

  // FIX-43: Foreground Service bei Verbindung starten
  // Timestamp speichern damit Dauer-Berechnung ohne externen 'seconds'-State funktioniert
  const connectedAtRef = useRef<number | null>(null)
  useEffect(() => {
    if (!isConnected) return
    connectedAtRef.current = Date.now()
    const remoteParticipant = participants.find(p => p.identity !== localParticipant.identity)
    const partnerName = remoteParticipant?.name ?? 'Anruf'
    const callType = cameraTracks.some(t => t.participant.isLocal) ? 'video' as const : 'audio' as const
    void startCallForegroundService({
      partnerName,
      callType,
      onHangupFromNotification: () => {
        room.disconnect().catch(() => {})
        onClose()
      },
    })
    return () => {
      connectedAtRef.current = null
      void stopCallForegroundService()
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected])

  // FIX-43: Notification-Dauer alle 30s aktualisieren
  // BUGFIX: 'seconds' war nicht in InnerRoom definiert (ReferenceError → Video-Crash)
  // Stattdessen: Dauer aus connectedAtRef.current berechnen
  useEffect(() => {
    if (!isConnected) return
    const interval = setInterval(() => {
      const remote = participants.find(p => p.identity !== localParticipant.identity)
      const name = remote?.name ?? 'Anruf'
      const type = cameraTracks.some(t => t.participant.isLocal) ? 'video' as const : 'audio' as const
      const elapsedSecs = connectedAtRef.current
        ? Math.floor((Date.now() - connectedAtRef.current) / 1000)
        : 0
      void updateCallForegroundService(formatDuration(elapsedSecs), name, type)
    }, 30_000)
    return () => clearInterval(interval)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected])

  // FIX-77: Token alle 3.5h refreshen damit TTL nie abläuft
  useEffect(() => {
    if (!isConnected || !roomName) return
    const REFRESH = 3.5 * 60 * 60 * 1000
    const interval = setInterval(async () => {
      try {
        const res = await fetch('/api/live-room/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            roomName,
            displayName: localParticipant.name ?? 'Mitglied',
          }),
        })
        if (!res.ok) return
        const data = await res.json() as { token: string }
        ;(room as unknown as { token: string }).token = data.token
      } catch { /* nächster Versuch in 3.5h */ }
    }, REFRESH)
    return () => clearInterval(interval)
  }, [isConnected, room, roomName, localParticipant.name])

  // FIX-77: Bei Reconnect Audio neu starten (iOS Safari Bug)
  useEffect(() => {
    const onReconnected = () => {
      room.startAudio().catch(() => {})
    }
    room.on(RoomEvent.Reconnected, onReconnected)
    return () => { room.off(RoomEvent.Reconnected, onReconnected) }
  }, [room])

  // Web-Audio-Boost: Lautstärke über 100% via GainNode (HTMLAudio max ist 1.0)
  // NUR aktivieren wenn volume > 1, sonst normale Audio-Wiedergabe (Web Audio kann auf Safari brechen)
  const gainRef = useRef<GainNode | null>(null)
  const audioCtxRef = useRef<AudioContext | null>(null)
  useEffect(() => {
    if (!isConnected || volume <= 1) return
    const wAny = window as unknown as { webkitAudioContext?: typeof AudioContext }
    const Ctor = window.AudioContext || wAny.webkitAudioContext
    if (!Ctor) return
    let ctx: AudioContext
    try { ctx = new Ctor() } catch { return }
    audioCtxRef.current = ctx
    ctx.resume().catch(() => {})

    const sources = new WeakMap<HTMLAudioElement, MediaElementAudioSourceNode>()
    const gain = ctx.createGain()
    gain.gain.value = volume
    gain.connect(ctx.destination)
    gainRef.current = gain

    const attach = () => {
      document.querySelectorAll<HTMLAudioElement>('audio').forEach(el => {
        if (sources.has(el)) return
        try {
          const src = ctx.createMediaElementSource(el)
          src.connect(gain)
          sources.set(el, src)
        } catch { /* schon verbunden oder cross-origin */ }
      })
    }
    attach()
    const obs = new MutationObserver(attach)
    obs.observe(document.body, { childList: true, subtree: true })
    return () => {
      obs.disconnect()
      gainRef.current = null
      audioCtxRef.current = null
      ctx.close().catch(() => {})
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected, volume > 1])

  // Live-Update bei Slider-Bewegung (nur wenn Web Audio aktiv)
  useEffect(() => {
    if (gainRef.current) gainRef.current.gain.value = speakerMuted ? 0 : volume
  }, [volume, speakerMuted])

  // Auto-Speaker-Focus: pinnt automatisch wer gerade spricht (außer User hat manuell gepinnt)
  useEffect(() => {
    if (!autoFocus || manualPin) return
    const speaker = participants.find(p => p.isSpeaking && p.identity !== localParticipant.identity)
    if (speaker) setPinnedIdentity(speaker.identity)
  }, [participants, autoFocus, manualPin, localParticipant.identity])

  // Geräte-Liste beim Connect laden (Labels nur nach Permission verfügbar)
  useEffect(() => {
    if (!isConnected) return
    const load = () => {
      navigator.mediaDevices.enumerateDevices().then(d => {
        setAudioInputs(d.filter(x => x.kind === 'audioinput' && x.deviceId))
        setVideoInputs(d.filter(x => x.kind === 'videoinput' && x.deviceId))
      }).catch(() => {})
    }
    load()
    navigator.mediaDevices.addEventListener?.('devicechange', load)
    return () => navigator.mediaDevices.removeEventListener?.('devicechange', load)
  }, [isConnected])

  const switchAudioInput = async (deviceId: string) => {
    try { await room.switchActiveDevice('audioinput', deviceId) }
    catch { toast.error('Mikrofon wechseln fehlgeschlagen') }
  }
  const switchVideoInput = async (deviceId: string) => {
    try {
      await room.switchActiveDevice('videoinput', deviceId)
      const dev = videoInputs.find(d => d.deviceId === deviceId)
      const label = dev?.label.toLowerCase() ?? ''
      setFacingMode(label.includes('back') || label.includes('rear') || label.includes('environment') ? 'environment' : 'user')
    }
    catch { toast.error('Kamera wechseln fehlgeschlagen') }
  }

  // DataChannel: Hand-heben + Reaktionen + Chat-Nachrichten empfangen
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
        } else if (msg.type === 'reaction' && participant) {
          const id = ++reactionIdRef.current
          setReactions(prev => [...prev, { id, emoji: msg.emoji, identity: participant.identity }])
          setTimeout(() => {
            setReactions(prev => prev.filter(r => r.id !== id))
          }, 3000)
        } else if (msg.type === 'chat' && participant) {
          setChatMessages(prev => [...prev, {
            id: `${Date.now()}-${participant.identity}`,
            sender: participant.name ?? participant.identity,
            text: msg.text,
            ts: Date.now(),
          }])
          // FIX-27: Nur scrollen wenn User nahe am Ende war
          if (isChatNearBottomRef.current) {
            setTimeout(() => {
              chatEndRef.current?.scrollIntoView({ behavior: 'smooth' })
            }, 50)
          }
        }
      } catch { /* ungültige Nachricht ignorieren */ }
    }
    room.on(RoomEvent.DataReceived, handler)
    return () => { room.off(RoomEvent.DataReceived, handler) }
  }, [room])

  const sendChatMessage = () => {
    const text = chatInput.trim()
    if (!text || !isConnected) return
    setChatInput('')
    const myMsg = { id: `${Date.now()}-local`, sender: 'Du', text, ts: Date.now() }
    setChatMessages(prev => [...prev, myMsg])
    // FIX-27: Nur scrollen wenn User nahe am Ende war
    if (isChatNearBottomRef.current) {
      setTimeout(() => chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 50)
    }
    localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'chat', text })),
      { reliable: true },
    ).catch(() => {})
  }

  const sendReaction = (emoji: string) => {
    if (!isConnected) return
    const id = ++reactionIdRef.current
    setReactions(prev => [...prev, { id, emoji, identity: localParticipant.identity }])
    setTimeout(() => setReactions(prev => prev.filter(r => r.id !== id)), 3000)
    localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'reaction', emoji })),
      { reliable: false },
    ).catch(() => {})
  }

  // Hintergrund-Unschärfe via @livekit/track-processors (dynamisch geladen)
  useEffect(() => {
    if (!isConnected) return
    let cancelled = false
    const apply = async () => {
      const pub = localParticipant.getTrackPublication(Track.Source.Camera)
      const track = pub?.track
      if (!track) return
      try {
        if (backgroundBlur) {
          const mod = await import('@livekit/track-processors')
          if (cancelled) return
          await track.setProcessor(mod.BackgroundBlur(15))
        } else {
          await track.stopProcessor()
        }
      } catch (e) {
        toast.error('Hintergrund-Unschärfe nicht unterstützt')
      }
    }
    apply()
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [backgroundBlur, isCameraEnabled, isConnected])

  // Push-to-Talk: bei Aktivierung Mic stumm, dann hold-to-talk
  useEffect(() => {
    if (pushToTalk && isConnected && isMicrophoneEnabled) {
      localParticipant.setMicrophoneEnabled(false).catch(() => {})
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pushToTalk])

  const pttDown = () => {
    if (!pushToTalk || !isConnected) return
    localParticipant.setMicrophoneEnabled(true).catch(() => {})
  }
  const pttUp = () => {
    if (!pushToTalk || !isConnected) return
    localParticipant.setMicrophoneEnabled(false).catch(() => {})
  }

  const toggleHand = () => {
    if (!isConnected) return
    const next = !handRaised
    setHandRaised(next)
    localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'raise-hand', raised: next })),
      { reliable: true },
    ).catch(() => toast.error('Senden fehlgeschlagen'))
  }

  const toggleScreenShare = async () => {
    if (!isConnected) return
    if (isMobile) {
      toast.error('Bildschirm teilen ist auf Handys nicht verfügbar')
      return
    }
    try {
      await localParticipant.setScreenShareEnabled(!isScreenSharing)
    } catch (e) {
      toast.error('Bildschirmfreigabe: ' + ((e as Error).message || 'Fehler'))
    }
  }

  const localIdentity = localParticipant.identity

  const getCameraTrack = useCallback(
    (identity: string) => cameraTracks.find(t => t.participant.identity === identity),
    [cameraTracks],
  )

  const toggleMic = async () => {
    if (!isConnected) return
    try {
      await localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled)
    } catch (e) {
      handlePermErr('Mikrofon', e as Error)
      checkPermissions()
    }
  }

  const toggleCamera = async () => {
    if (!isConnected) return
    try {
      if (!isCameraEnabled) {
        await localParticipant.setCameraEnabled(true, { facingMode })
      } else {
        await localParticipant.setCameraEnabled(false)
      }
    } catch (e) {
      handlePermErr('Kamera', e as Error)
      checkPermissions()
    }
  }

  const flipCamera = async () => {
    if (!isCameraEnabled || isFlipping) return
    setIsFlipping(true)
    const next: 'user' | 'environment' = facingMode === 'user' ? 'environment' : 'user'

    // Strategie 1 (Mobile/WebView): Track stoppen und mit facingMode-Constraint
    // neu publishen. Auf Android/iOS/Capacitor zuverlässiger als switchActiveDevice,
    // da der OS-Layer dann wirklich die Front- bzw. Rückkamera öffnet.
    try {
      await localParticipant.setCameraEnabled(false)
      // FIX-23: Kürzere Pause beim Kamera-Wechsel (200→100ms)
      await new Promise(r => setTimeout(r, 100))
      await localParticipant.setCameraEnabled(true, { facingMode: next })
      setFacingMode(next)
      return
    } catch (errFacing) {
      // Strategie 2 (Desktop / externe Webcams): über Device-ID switchen.
      try {
        const devices = await navigator.mediaDevices.enumerateDevices()
        const cameras = devices.filter(d => d.kind === 'videoinput' && d.deviceId)
        if (cameras.length < 2) {
          // Falls Camera nach Strategie 1 aus blieb, wieder mit alter Front einschalten
          try { await localParticipant.setCameraEnabled(true, { facingMode }) } catch {}
          toast.error('Keine zweite Kamera gefunden')
          return
        }
        const currentPub = localParticipant.getTrackPublication(Track.Source.Camera)
        const currentDeviceId = currentPub?.track?.mediaStreamTrack.getSettings().deviceId
        const currentIdx = cameras.findIndex(c => c.deviceId === currentDeviceId)
        const target = cameras[(currentIdx + 1) % cameras.length]
        if (target && target.deviceId !== currentDeviceId) {
          await room.switchActiveDevice('videoinput', target.deviceId)
          const lbl = target.label.toLowerCase()
          setFacingMode(
            lbl.includes('back') || lbl.includes('rear') || lbl.includes('environment')
              ? 'environment'
              : 'user',
          )
        } else {
          throw errFacing
        }
      } catch (e) {
        toast.error('Kamera wechseln: ' + ((e as Error).message || 'Fehler'))
        // Sicherstellen dass Kamera nach Fehler wieder läuft
        try { await localParticipant.setCameraEnabled(true, { facingMode }) } catch {}
      }
    } finally {
      setIsFlipping(false)
    }
  }

  const leave = () => {
    playEndTone() // FEATURE: End-Ton
    void stopCallForegroundService() // FIX-43: Foreground Service beenden
    // FIX-75: Bei DM-Call DB-Row beenden damit Partner rausfliegt
    if (dmCallId) {
      fetch('/api/dm-calls/end', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callId: dmCallId }),
      }).catch(() => {})
    }
    room.disconnect().catch(() => {})
    onClose()
  }

  const count = participants.length
  const tileSize: 'lg' | 'md' | 'sm' =
    count === 1 ? 'lg' : count <= 4 ? 'md' : 'sm'

  // Plattform-spezifische Anleitung wenn Mikro/Kamera blockiert sind
  const permissionHelp = anyDenied ? (
    isCapacitor && isAndroid
      ? 'Android-App: Lange auf das Mensaena-App-Icon → "App-Info" → "Berechtigungen" → Mikrofon/Kamera auf "Erlauben". Dann App neu öffnen.'
      : isCapacitor && isIOS
      ? 'iOS-App: Einstellungen → Mensaena → Mikrofon/Kamera einschalten. Dann App neu öffnen.'
      : isIOS
      ? 'iOS: Einstellungen → Safari → Webseiten-Einstellungen → Mikrofon/Kamera → mensaena.de auf "Erlauben". Danach Seite neu laden.'
      : isAndroid
      ? 'Android: Tippe auf das 🔒-Symbol in der URL-Leiste → Berechtigungen → Mikrofon/Kamera → "Zulassen". Danach Seite neu laden.'
      : 'Browser: Klicke auf das 🔒-Symbol in der URL-Leiste → Mikrofon/Kamera → "Zulassen". Danach Seite neu laden.'
  ) : null

  // Direkt-Anfrage: ruft getUserMedia auf um System-Dialog zu triggern (falls möglich)
  const requestPermissionsNow = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true })
      stream.getTracks().forEach(t => t.stop())
      toast.success('Berechtigungen erteilt!')
      checkPermissions()
    } catch {
      toast.error('Bitte in den App-/Browser-Einstellungen erlauben')
    }
  }

  // ── Steuerleiste als eigene Variable: wird via Portal an document.body gerendert
  // Damit kann KEIN LiveKit-Element (z. B. <video>, lk-start-audio-button) sie überlagern.
  const settingsPanel = showSettings ? (
    <div
      className="fixed inset-x-0 bottom-0 pointer-events-auto"
      style={{ zIndex: 10001 }}
      onClick={(e) => { if (e.target === e.currentTarget) setShowSettings(false) }}
    >
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={() => setShowSettings(false)}
      />
      <div className="relative bg-gray-900 border-t border-white/10 rounded-t-2xl px-5 pt-3 pb-8 max-h-[70vh] overflow-y-auto">
        <div className="w-10 h-1 bg-white/20 rounded-full mx-auto mb-3" />
        <h3 className="text-white text-sm font-semibold mb-3">Einstellungen</h3>

        {/* Lautstärke-Slider mit Boost bis 200% */}
        <div className="mb-4">
          <div className="flex items-center justify-between text-xs text-white/70 mb-2">
            <span className="flex items-center gap-1.5"><Volume2 className="w-3.5 h-3.5" /> Lautstärke</span>
            <span className="text-white">{Math.round(volume * 100)}%{volume > 1 && ' 🔊'}</span>
          </div>
          <input
            type="range"
            min="0" max="2" step="0.05"
            value={volume}
            onChange={(e) => setVolume(parseFloat(e.target.value))}
            className="w-full accent-primary-500"
          />
          <p className="text-[10px] text-white/30 mt-1">Über 100%: Verstärkung via Web Audio</p>
        </div>

        {/* Push-to-Talk */}
        <button
          type="button"
          onClick={() => setPushToTalk(p => !p)}
          className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg bg-white/5 hover:bg-white/10 mb-2"
        >
          <span className="flex items-center gap-2 text-white text-sm">
            🎙️ Push-to-Talk (gedrückt halten zum Sprechen)
          </span>
          <span className={`w-9 h-5 rounded-full transition-colors relative ${pushToTalk ? 'bg-primary-500' : 'bg-white/20'}`}>
            <span className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${pushToTalk ? 'translate-x-4' : 'translate-x-0.5'}`} />
          </span>
        </button>

        {/* Auto-Speaker-Focus */}
        <button
          type="button"
          onClick={() => { setAutoFocus(a => !a); setManualPin(false) }}
          className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg bg-white/5 hover:bg-white/10 mb-2"
        >
          <span className="flex items-center gap-2 text-white text-sm">
            🎯 Sprecher automatisch fokussieren
          </span>
          <span className={`w-9 h-5 rounded-full transition-colors relative ${autoFocus ? 'bg-primary-500' : 'bg-white/20'}`}>
            <span className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${autoFocus ? 'translate-x-4' : 'translate-x-0.5'}`} />
          </span>
        </button>

        {/* Hintergrund-Unschärfe */}
        <button
          type="button"
          onClick={() => setBackgroundBlur(b => !b)}
          className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg bg-white/5 hover:bg-white/10 mb-2"
        >
          <span className="flex items-center gap-2 text-white text-sm">
            🌫️ Hintergrund unscharf
          </span>
          <span className={`w-9 h-5 rounded-full transition-colors relative ${backgroundBlur ? 'bg-primary-500' : 'bg-white/20'}`}>
            <span className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${backgroundBlur ? 'translate-x-4' : 'translate-x-0.5'}`} />
          </span>
        </button>

        {/* Eigenes Bild spiegeln */}
        <button
          type="button"
          onClick={() => setMirrorOwnVideo(m => !m)}
          className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg bg-white/5 hover:bg-white/10 mb-4"
        >
          <span className="flex items-center gap-2 text-white text-sm">
            <FlipHorizontal2 className="w-4 h-4" /> Eigenes Bild spiegeln
          </span>
          <span className={`w-9 h-5 rounded-full transition-colors relative ${mirrorOwnVideo ? 'bg-primary-500' : 'bg-white/20'}`}>
            <span className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${mirrorOwnVideo ? 'translate-x-4' : 'translate-x-0.5'}`} />
          </span>
        </button>

        {/* Mikrofon-Auswahl */}
        {audioInputs.length > 1 && (
          <div className="mb-4">
            <p className="text-xs text-white/70 mb-2 flex items-center gap-1.5"><Mic className="w-3.5 h-3.5" /> Mikrofon</p>
            <div className="space-y-1">
              {audioInputs.map(d => (
                <button
                  key={d.deviceId}
                  type="button"
                  onClick={() => switchAudioInput(d.deviceId)}
                  className="w-full text-left px-3 py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white text-xs truncate"
                >
                  {d.label || 'Mikrofon ' + d.deviceId.slice(0, 6)}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Kamera-Auswahl */}
        {videoInputs.length > 1 && (
          <div className="mb-4">
            <p className="text-xs text-white/70 mb-2 flex items-center gap-1.5"><Video className="w-3.5 h-3.5" /> Kamera</p>
            <div className="space-y-1">
              {videoInputs.map(d => (
                <button
                  key={d.deviceId}
                  type="button"
                  onClick={() => switchVideoInput(d.deviceId)}
                  className="w-full text-left px-3 py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white text-xs truncate"
                >
                  {d.label || 'Kamera ' + d.deviceId.slice(0, 6)}
                </button>
              ))}
            </div>
          </div>
        )}

        <button
          type="button"
          onClick={() => setShowSettings(false)}
          className="w-full py-2.5 rounded-lg bg-white/10 hover:bg-white/15 text-white text-sm font-medium mt-2"
        >
          Schließen
        </button>
      </div>
    </div>
  ) : null

  // Teilnehmer-Panel (Bottom-Sheet)
  const participantsPanel = showParticipants ? (
    <div className="fixed inset-x-0 bottom-0 pointer-events-auto" style={{ zIndex: 10001 }}>
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowParticipants(false)} />
      <div className="relative bg-gray-900 border-t border-white/10 rounded-t-2xl px-5 pt-3 pb-8 max-h-[70vh] overflow-y-auto">
        <div className="w-10 h-1 bg-white/20 rounded-full mx-auto mb-3" />
        <h3 className="text-white text-sm font-semibold mb-3">Teilnehmer ({participants.length})</h3>
        <div className="space-y-1">
          {participants
            .slice()
            // FEATURE: Admin/Mod-Sortierung
            .sort((a, b) => {
              // 1) Rollen-Priorität: admin > moderator > user
              const rolePriority = (p: Participant) => {
                const role = getParticipantRole(p)
                if (role === 'admin') return 0
                if (role === 'moderator') return 1
                return 2
              }
              const rp = rolePriority(a) - rolePriority(b)
              if (rp !== 0) return rp

              // 2) Bestehende Sortierung: Hand gehoben > sprechend > Rest
              const aRaised = a.identity === localIdentity ? handRaised : raisedHands.has(a.identity)
              const bRaised = b.identity === localIdentity ? handRaised : raisedHands.has(b.identity)
              if (aRaised && !bRaised) return -1
              if (!aRaised && bRaised) return 1
              if (a.isSpeaking && !b.isSpeaking) return -1
              if (!a.isSpeaking && b.isSpeaking) return 1
              return 0
            })
            .map(p => {
              const isMe = p.identity === localIdentity
              const isRaised = isMe ? handRaised : raisedHands.has(p.identity)
              return (
                <div key={p.identity} className="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white/5">
                  <div className={`w-2 h-2 rounded-full ${p.isSpeaking ? 'bg-primary-400 animate-pulse' : 'bg-white/20'}`} />
                  <span className="flex-1 text-white text-sm truncate flex items-center gap-1.5">
                    {p.name || 'Mitglied'}{isMe && <span className="text-white/40 ml-1 text-xs">(du)</span>}
                    {/* FEATURE: Admin/Mod-Sortierung — Rollen-Badge in Liste */}
                    {(() => {
                      const role = getParticipantRole(p)
                      if (role === 'admin') return (
                        <span className="px-1.5 py-0.5 rounded-full bg-red-500/20 text-red-400 text-[10px] font-semibold">
                          🛡️ Admin
                        </span>
                      )
                      if (role === 'moderator') return (
                        <span className="px-1.5 py-0.5 rounded-full bg-amber-500/20 text-amber-400 text-[10px] font-semibold">
                          ⚔️ Mod
                        </span>
                      )
                      return null
                    })()}
                  </span>
                  {isRaised && <span className="text-base">✋</span>}
                  {!p.isMicrophoneEnabled && <MicOff className="w-4 h-4 text-red-400" />}
                  {!isMe && (
                    <button
                      type="button"
                      onClick={() => { setPinnedIdentity(p.identity); setManualPin(true); setShowParticipants(false) }}
                      className="text-[10px] text-primary-400 hover:underline"
                    >
                      Fokus
                    </button>
                  )}
                </div>
              )
            })}
        </div>
        <button
          type="button"
          onClick={() => setShowParticipants(false)}
          className="w-full py-2.5 rounded-lg bg-white/10 hover:bg-white/15 text-white text-sm font-medium mt-4"
        >
          Schließen
        </button>
      </div>
    </div>
  ) : null

  const controlsBar = (
    <div
      className="fixed left-0 right-0 bottom-0 px-5 pt-2 pointer-events-none"
      style={{
        zIndex: 10000,
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 24px)',
      }}
    >
      {/* Permission-Warnung: persistent, klickbar zum erneuten Prüfen */}
      {/* FIX-76: nur anzeigen solange nicht weggeklickt */}
      {anyDenied && !permDismissed && (
        <div className="mb-2 pointer-events-auto">
          <div className="rounded-xl bg-red-500/15 border border-red-500/40 px-3 py-2 text-red-200 text-xs leading-relaxed">
            <div className="font-semibold mb-1">
              {micDenied && camDenied ? '🎤📷 Mikrofon & Kamera blockiert'
               : micDenied ? '🎤 Mikrofon blockiert'
               : '📷 Kamera blockiert'}
            </div>
            <div className="text-red-100/80">{permissionHelp}</div>
            <div className="flex items-center gap-3 mt-2">
              <button
                type="button"
                onClick={(e) => { e.stopPropagation(); requestPermissionsNow() }}
                className="px-3 py-1 rounded-full bg-primary-500 hover:bg-primary-600 text-white text-[11px] font-semibold"
              >
                Jetzt erlauben
              </button>
              <button
                type="button"
                onClick={(e) => { e.stopPropagation(); checkPermissions() }}
                className="text-red-200 underline text-[11px]"
              >
                Erneut prüfen
              </button>
              {/* FIX-76: Warnung wegklickbar */}
              <button
                type="button"
                onClick={(e) => { e.stopPropagation(); dismissPermWarn() }}
                className="text-red-200 underline text-[11px]"
              >
                Ausblenden
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Verbindungs-Status nur wenn nicht verbunden */}
      {!isConnected && (
        <div className="flex justify-center mb-2 pointer-events-auto">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-yellow-500/20 border border-yellow-500/30 text-yellow-300 text-xs font-medium">
            <Loader2 className="w-3 h-3 animate-spin" />
            {connectionState === ConnectionState.Connecting ? 'Verbinde…' :
             connectionState === ConnectionState.Reconnecting ? 'Neuverbindung…' :
             'Getrennt'}
          </div>
        </div>
      )}

      {/* Sekundäre Aktionen + Reaktionen – nur im Community-Livestream */}
      {!isDMCall && (
        <>
          <div className="flex items-center justify-center gap-2 mb-3 pointer-events-auto flex-wrap">
            <button type="button" onClick={(e) => { e.stopPropagation(); toggleHand() }}
              style={{ touchAction: 'manipulation' }}
              className={['flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
                handRaised ? 'bg-yellow-500/20 text-yellow-300' : 'bg-white/[0.08] text-white/70 hover:bg-white/15'].join(' ')}>
              <Hand className="w-3.5 h-3.5" />
              {handRaised ? 'Hand senken' : 'Hand heben'}
            </button>
            {!isMobile && (
              <button type="button" onClick={(e) => { e.stopPropagation(); toggleScreenShare() }}
                style={{ touchAction: 'manipulation' }}
                className={['flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
                  isScreenSharing ? 'bg-primary-500/20 text-primary-300' : 'bg-white/[0.08] text-white/70 hover:bg-white/15'].join(' ')}>
                {isScreenSharing ? <ScreenShareOff className="w-3.5 h-3.5" /> : <ScreenShare className="w-3.5 h-3.5" />}
                {isScreenSharing ? 'Teilen stoppen' : 'Teilen'}
              </button>
            )}
            <button type="button" onClick={(e) => { e.stopPropagation(); setShowChat(c => !c) }}
              style={{ touchAction: 'manipulation' }}
              className={['flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
                showChat ? 'bg-primary-500/20 text-primary-300' : 'bg-white/[0.08] text-white/70 hover:bg-white/15'].join(' ')}>
              💬 Chat{chatMessages.length > 0 && <span className="bg-primary-500 text-white text-[9px] font-bold w-4 h-4 rounded-full flex items-center justify-center">{Math.min(chatMessages.length, 9)}</span>}
            </button>
            <button type="button" onClick={(e) => { e.stopPropagation(); setShowParticipants(true) }}
              style={{ touchAction: 'manipulation' }}
              className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-white/[0.08] hover:bg-white/15 text-white/70 text-xs font-medium transition-all">
              <Users className="w-3.5 h-3.5" />
              {count}
            </button>
          </div>
          <div className="flex items-center justify-center gap-2 mb-3 pointer-events-auto">
            {['👍', '❤️', '😂', '😮', '🎉', '🙏'].map(emoji => (
              <button
                key={emoji}
                type="button"
                onClick={(e) => { e.stopPropagation(); sendReaction(emoji) }}
                style={{ touchAction: 'manipulation' }}
                className="w-9 h-9 rounded-full bg-white/[0.08] hover:bg-white/15 active:scale-90 flex items-center justify-center text-base transition-all"
              >
                {emoji}
              </button>
            ))}
          </div>
        </>
      )}

      {/* Haupt-Steuerleiste:
          - DM-Call: WhatsApp-Stil – nur Mute / Camera / Auflegen
          - Community: volle Leiste */}
      {isDMCall ? (
        <div className="flex items-center justify-center gap-10 mb-2 pointer-events-auto">
          {/* Mute */}
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); toggleMic() }}
            style={{ touchAction: 'manipulation' }}
            aria-label={isMicrophoneEnabled ? 'Stummschalten' : 'Ton aktivieren'}
            className="flex flex-col items-center gap-1.5 group"
          >
            <div className={['w-16 h-16 rounded-full flex items-center justify-center transition-all active:scale-95',
              isMicrophoneEnabled ? 'bg-white/15 hover:bg-white/25' : 'bg-red-500/30 hover:bg-red-500/40'].join(' ')}>
              {isMicrophoneEnabled
                ? <Mic className="w-6 h-6 text-white" />
                : <MicOff className="w-6 h-6 text-red-400" />}
            </div>
            <span className="text-[10px] text-white/50">{isMicrophoneEnabled ? 'Stumm' : 'Ton an'}</span>
          </button>

          {/* Auflegen – groß + rot */}
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); leave() }}
            style={{ touchAction: 'manipulation' }}
            aria-label="Auflegen"
            className="flex flex-col items-center gap-1.5 group"
          >
            <div className="w-20 h-20 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center shadow-xl shadow-red-500/40 transition-all">
              <PhoneOff className="w-8 h-8 text-white" />
            </div>
            <span className="text-[10px] text-white/50">Auflegen</span>
          </button>

          {/* Kamera */}
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); toggleCamera() }}
            style={{ touchAction: 'manipulation' }}
            aria-label={isCameraEnabled ? 'Kamera aus' : 'Kamera ein'}
            className="flex flex-col items-center gap-1.5 group"
          >
            <div className={['w-16 h-16 rounded-full flex items-center justify-center transition-all active:scale-95',
              isCameraEnabled ? 'bg-primary-500/30 hover:bg-primary-500/40' : 'bg-white/15 hover:bg-white/25'].join(' ')}>
              {isCameraEnabled
                ? <Video className="w-6 h-6 text-primary-400" />
                : <VideoOff className="w-6 h-6 text-white/70" />}
            </div>
            <span className="text-[10px] text-white/50">{isCameraEnabled ? 'Kamera aus' : 'Kamera an'}</span>
          </button>
        </div>
      ) : (
      <div className="mx-auto max-w-md flex items-center justify-center gap-3 bg-black/60 backdrop-blur-xl rounded-[30px] py-4 px-6 border border-white/[0.08] pointer-events-auto">
        {pushToTalk ? (
          <button
            type="button"
            onPointerDown={(e) => { e.stopPropagation(); pttDown() }}
            onPointerUp={(e) => { e.stopPropagation(); pttUp() }}
            onPointerLeave={() => pttUp()}
            onPointerCancel={() => pttUp()}
            aria-label="Push-to-Talk"
            style={{ touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}
            className={[
              'w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95 cursor-pointer relative',
              isMicrophoneEnabled ? 'bg-primary-500/40 ring-2 ring-primary-400' : 'bg-white/[0.12] hover:bg-white/20',
            ].join(' ')}
          >
            {isMicrophoneEnabled
              ? <Mic className="w-5 h-5 text-white animate-pulse" />
              : <MicOff className="w-5 h-5 text-white/70" />}
          </button>
        ) : (
          <ControlButton
            onClick={toggleMic}
            active={isMicrophoneEnabled}
            activeClass="bg-white/[0.12] hover:bg-white/20"
            inactiveClass="bg-red-500/20 hover:bg-red-500/30"
            label={isMicrophoneEnabled ? 'Stummschalten' : 'Ton aktivieren'}
          >
            {isMicrophoneEnabled
              ? <Mic className="w-5 h-5 text-white" />
              : <MicOff className="w-5 h-5 text-red-400" />}
          </ControlButton>
        )}

        <ControlButton
          onClick={toggleCamera}
          active={isCameraEnabled}
          activeClass="bg-primary-500/20 hover:bg-primary-500/30"
          inactiveClass="bg-white/[0.10] hover:bg-white/[0.18]"
          label={isCameraEnabled ? 'Kamera aus' : 'Kamera ein'}
        >
          {isCameraEnabled
            ? <Video className="w-5 h-5 text-primary-400" />
            : <VideoOff className="w-5 h-5 text-white/70" />}
        </ControlButton>

        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); leave() }}
          style={{ touchAction: 'manipulation' }}
          className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 active:scale-95 flex items-center justify-center transition-all shadow-lg shadow-red-500/30 mx-1 cursor-pointer"
          aria-label="Anruf beenden"
        >
          <PhoneOff className="w-6 h-6 text-white" />
        </button>

        <ControlButton
          onClick={flipCamera}
          active={isCameraEnabled && !isFlipping}
          activeClass="bg-white/[0.10] hover:bg-white/[0.18]"
          inactiveClass="bg-white/5"
          label="Front-/Rückkamera wechseln"
          disabled={!isCameraEnabled || isFlipping}
        >
          <SwitchCamera
            className={[
              'w-5 h-5 transition-all duration-300',
              isCameraEnabled ? 'text-white' : 'text-white/25',
              isFlipping ? 'animate-spin' : '',
            ].join(' ')}
          />
        </ControlButton>

        <ControlButton
          onClick={() => setSpeakerMuted(m => !m)}
          active={!speakerMuted}
          activeClass="bg-white/[0.10] hover:bg-white/[0.18]"
          inactiveClass="bg-red-500/20 hover:bg-red-500/30"
          label={speakerMuted ? 'Lautsprecher ein' : 'Lautsprecher aus'}
        >
          {speakerMuted
            ? <VolumeX className="w-5 h-5 text-red-400" />
            : <Volume2 className="w-5 h-5 text-white" />}
        </ControlButton>

        {/* FIX-11: Audio-Output-Wechsel */}
        <ControlButton
          onClick={async () => {
            try {
              const devices = await navigator.mediaDevices.enumerateDevices()
              const outputs = devices.filter(d => d.kind === 'audiooutput')
              if (outputs.length < 2) {
                toast('Nur ein Audioausgang verfügbar')
                return
              }
              const speaker = outputs.find(d =>
                d.label.toLowerCase().includes('speaker')
              )
              const earpiece = outputs.find(d =>
                d.label.toLowerCase().includes('earpiece') ||
                d.label.toLowerCase().includes('phone')
              )
              const target = speakerActive
                ? (earpiece ?? outputs[0])
                : (speaker ?? outputs[1])
              await room.switchActiveDevice('audiooutput', target.deviceId)
              setSpeakerActive(!speakerActive)
            } catch {
              toast.error('Audio-Ausgang wechseln fehlgeschlagen')
            }
          }}
          active={speakerActive}
          activeClass="bg-primary-500/20 hover:bg-primary-500/30"
          inactiveClass="bg-white/[0.10] hover:bg-white/[0.18]"
          label={speakerActive ? 'Ohrhörer' : 'Lautsprecher'}
        >
          <Volume2 className="w-6 h-6" />
        </ControlButton>

        <ControlButton
          onClick={() => setShowSettings(s => !s)}
          active={showSettings}
          activeClass="bg-primary-500/20"
          inactiveClass="bg-white/[0.10] hover:bg-white/[0.18]"
          label="Einstellungen"
        >
          <Settings className="w-5 h-5 text-white" />
        </ControlButton>
      </div>
      )}
    </div>
  )

  // Landscape: eigenes Kamerabild fullscreen, Header ausgeblendet
  if (isLandscape) {
    const localCamTrack = getCameraTrack(localIdentity)
    return (
      <div className="fixed inset-0 bg-black" style={{ zIndex: 100 }}>
        {/* Eigenes Kamerabild als Vollbild-Hintergrund */}
        {isRealTrack(localCamTrack) ? (
          <VideoTrack
            trackRef={localCamTrack}
            className="w-full h-full object-cover"
            style={mirrorOwnVideo && facingMode === 'user' ? { transform: 'scaleX(-1)' } : undefined}
          />
        ) : (
          <div className="w-full h-full bg-gray-950 flex items-center justify-center">
            {(() => {
              const me = participants.find(p => p.identity === localIdentity)
              if (!me) return null
              return (
                <ParticipantTile
                  participant={me}
                  cameraTrack={undefined}
                  localIdentity={localIdentity}
                  localAvatarUrl={localAvatarUrl}
                  size="lg"
                  mirrorVideo={false}
                  isFlipping={isFlipping} // FIX-23: Kamera-Wechsel Platzhalter
                />
              )
            })()}
          </div>
        )}

        {/* Andere Teilnehmer als kleine Kacheln oben rechts */}
        {participants.filter(p => p.identity !== localIdentity).length > 0 && (
          <div className="absolute top-3 right-3 flex flex-col gap-2" style={{ zIndex: 101 }}>
            {participants.filter(p => p.identity !== localIdentity).map(p => (
              <ParticipantTile
                key={p.identity}
                participant={p}
                cameraTrack={getCameraTrack(p.identity)}
                localIdentity={localIdentity}
                localAvatarUrl={localAvatarUrl}
                raisedHand={raisedHands.has(p.identity)}
                size="sm"
                onClick={() => { setPinnedIdentity(p.identity); setManualPin(true) }}
                mirrorVideo={false}
              />
            ))}
          </div>
        )}

        {/* Audio-Renderer */}
        <RoomAudioRenderer muted={speakerMuted} volume={Math.min(volume, 1)} />

        {/* Reaktionen */}
        <div className="fixed inset-0 pointer-events-none" style={{ zIndex: 10002 }}>
          {reactions.map(r => (
            <div
              key={r.id}
              className="absolute bottom-32 left-1/2 -translate-x-1/2 text-5xl animate-[lk-float_3s_ease-out_forwards]"
              style={{ left: `${40 + (r.id * 17) % 30}%` }}
            >
              {r.emoji}
            </div>
          ))}
        </div>

        <style>{`
          .lk-start-audio-button{display:none!important}
          @keyframes lk-wave {
            0%   { transform: scale(1);    opacity: 0.8; }
            80%  { transform: scale(1.35); opacity: 0;   }
            100% { transform: scale(1.35); opacity: 0;   }
          }
          @keyframes lk-float {
            0%   { transform: translateY(0) scale(0.5); opacity: 0; }
            15%  { transform: translateY(-30px) scale(1.2); opacity: 1; }
            100% { transform: translateY(-360px) scale(0.8); opacity: 0; }
          }
          [data-lk-facing-mode=user] .lk-participant-media-video[data-lk-local-participant=true][data-lk-source=camera],
          video[data-lk-local-participant=true] {
            transform: none !important;
          }
        `}</style>

        {typeof document !== 'undefined' && createPortal(<>{controlsBar}{settingsPanel}{participantsPanel}</>, document.body)}
      </div>
    )
  }

  return (
    <div className={`flex h-full ${showChat ? 'flex-row' : 'flex-col'}`}>
      {/* Teilnehmer-Raster: lokaler User groß, andere klein darunter */}
      <div
        className="flex-1 flex flex-col items-center justify-center gap-8 p-6 overflow-hidden"
        style={{ paddingBottom: showChat ? '180px' : 'calc(180px + env(safe-area-inset-bottom, 0px))' }}
      >
        {/* Vollbild Screen-Share Overlay */}
        {fullscreenSharer && (() => {
          const shareTracks = screenTracks.filter(t => t.participant.identity === fullscreenSharer)
          if (!shareTracks.length) { setFullscreenSharer(null); return null }
          return (
            <div className="fixed inset-0 bg-black z-50 flex flex-col" onClick={() => setFullscreenSharer(null)}>
              <div className="absolute top-3 right-3 flex items-center gap-2 z-10" onClick={e => e.stopPropagation()}>
                <span className="text-white/60 text-xs">{shareTracks[0].participant.name} teilt Bildschirm</span>
                <button onClick={() => setFullscreenSharer(null)}
                  className="p-1.5 rounded-full bg-white/10 hover:bg-white/20 text-white transition-all">
                  <X className="w-4 h-4" />
                </button>
              </div>
              {isRealTrack(shareTracks[0]) && <VideoTrack trackRef={shareTracks[0]} className="w-full h-full object-contain" />}
            </div>
          )
        })()}

        {/* Laufende Bildschirmfreigaben — klickbar für Vollbild */}
        {screenTracks.length > 0 && !fullscreenSharer && (
          <div className="flex flex-wrap gap-3 justify-center mb-2">
            {screenTracks.map(t => (
              <div key={t.participant.identity}
                className="relative cursor-pointer group"
                onClick={() => setFullscreenSharer(t.participant.identity)}>
                {isRealTrack(t) && <VideoTrack trackRef={t} className="w-48 h-28 rounded-xl object-cover border border-white/10" />}
                <div className="absolute inset-0 bg-black/40 rounded-xl flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
                  <span className="text-white text-xs font-semibold">⛶ Vollbild</span>
                </div>
                <span className="absolute bottom-1 left-2 text-white/60 text-[10px]">{t.participant.name}</span>
              </div>
            ))}
          </div>
        )}

        {count === 0 ? (
          <p className="text-sm text-white/30 text-center">Warte auf Teilnehmer…</p>
        ) : (
          <>
            {pinnedIdentity && (
              <p className="text-[10px] text-white/30 text-center -mb-4">
                Tippe das große Bild um zurück zu wechseln
              </p>
            )}
            {/* Großer Teilnehmer: gepinnt oder lokaler User */}
            {(() => {
              const focusedId = pinnedIdentity ?? localIdentity
              const focused = participants.find(p => p.identity === focusedId)
              if (!focused) return null
              const isMe = focused.identity === localIdentity
              return (
                <ParticipantTile
                  participant={focused}
                  cameraTrack={getCameraTrack(focused.identity)}
                  localIdentity={localIdentity}
                  localAvatarUrl={localAvatarUrl}
                  raisedHand={isMe ? handRaised : raisedHands.has(focused.identity)}
                  size="lg"
                  onClick={pinnedIdentity ? () => { setPinnedIdentity(null); setManualPin(false) } : undefined}
                  mirrorVideo={isMe && mirrorOwnVideo && facingMode === 'user'}
                  isFlipping={isMe ? isFlipping : false} // FIX-23: Kamera-Wechsel Platzhalter
                />
              )
            })()}

            {/* Andere Teilnehmer klein in einer Reihe — antippen pinnt */}
            {count > 1 && (
              <div className="flex flex-wrap justify-center gap-4 max-w-md">
                {participants
                  .filter(p => p.identity !== (pinnedIdentity ?? localIdentity))
                  .map(p => {
                    const isMe = p.identity === localIdentity
                    return (
                      <ParticipantTile
                        key={p.identity}
                        participant={p}
                        cameraTrack={getCameraTrack(p.identity)}
                        localIdentity={localIdentity}
                        localAvatarUrl={localAvatarUrl}
                        raisedHand={isMe ? handRaised : raisedHands.has(p.identity)}
                        size="sm"
                        onClick={() => { setPinnedIdentity(p.identity); setManualPin(true) }}
                        mirrorVideo={isMe && mirrorOwnVideo && facingMode === 'user'}
                        isFlipping={isMe ? isFlipping : false} // FIX-23: Kamera-Wechsel Platzhalter
                      />
                    )
                  })}
              </div>
            )}
          </>
        )}
      </div>

      {/* Chat-Panel: fixed über der Steuerleiste, kein Überlappen */}
      {showChat && (
        <div
          className="fixed left-0 right-0 flex flex-col bg-gray-900/98 border-t border-white/10"
          style={{
            top: 0,
            bottom: 'calc(180px + env(safe-area-inset-bottom, 0px))',
            zIndex: 9995,
          }}
        >
          <div className="px-3 py-2.5 border-b border-white/10 flex items-center justify-between flex-shrink-0">
            <span className="text-white text-sm font-semibold">Live-Chat</span>
            <button onClick={() => setShowChat(false)} className="text-white/40 hover:text-white p-1">
              <X className="w-4 h-4" />
            </button>
          </div>
          <div
            ref={chatContainerRef}
            onScroll={() => {
              // FIX-27: Prüfe ob User nahe am Ende ist
              const el = chatContainerRef.current
              if (el) {
                isChatNearBottomRef.current =
                  el.scrollHeight - el.scrollTop - el.clientHeight < 60
              }
            }}
            className="flex-1 overflow-y-auto p-3 space-y-2 min-h-0"
          >
            {chatMessages.length === 0 && (
              <p className="text-white/30 text-xs text-center pt-4">Noch keine Nachrichten</p>
            )}
            {chatMessages.map(m => (
              <div key={m.id} className={m.sender === 'Du' ? 'text-right' : 'text-left'}>
                <p className="text-[10px] text-white/40 mb-0.5">{m.sender}</p>
                <span className={`inline-block px-2.5 py-1.5 rounded-xl text-xs max-w-[80%] text-left break-words ${m.sender === 'Du' ? 'bg-primary-600 text-white' : 'bg-white/10 text-white'}`}>
                  {m.text}
                </span>
              </div>
            ))}
            <div ref={chatEndRef} />
          </div>
          <div className="px-3 py-2.5 border-t border-white/10 flex-shrink-0">
            <div className="flex gap-2">
              <input
                value={chatInput}
                onChange={e => setChatInput(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); sendChatMessage() } }}
                placeholder="Nachricht…"
                className="flex-1 bg-white/10 border border-white/10 rounded-xl px-3 py-2 text-white text-sm placeholder-white/30 outline-none focus:border-primary-500/60"
              />
              <button
                onClick={sendChatMessage}
                disabled={!chatInput.trim()}
                className="px-3 py-2 rounded-xl bg-primary-600 hover:bg-primary-700 text-white disabled:opacity-40 transition-all flex-shrink-0"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Audio-Renderer (muted-Prop steuert Lautsprecher direkt) */}
      <RoomAudioRenderer muted={speakerMuted} volume={Math.min(volume, 1)} />

      {/* LiveKit-Button verstecken + Sprech-Animation + Mirror-Effekt entfernen */}
      <style>{`
        .lk-start-audio-button{display:none!important}
        @keyframes lk-wave {
          0%   { transform: scale(1);    opacity: 0.8; }
          80%  { transform: scale(1.35); opacity: 0;   }
          100% { transform: scale(1.35); opacity: 0;   }
        }
        @keyframes lk-float {
          0%   { transform: translateY(0) scale(0.5); opacity: 0; }
          15%  { transform: translateY(-30px) scale(1.2); opacity: 1; }
          100% { transform: translateY(-360px) scale(0.8); opacity: 0; }
        }
        /* Vertikales Drehen der eigenen Kamera entfernen (LiveKit spiegelt sonst rotateY 180deg) */
        [data-lk-facing-mode=user] .lk-participant-media-video[data-lk-local-participant=true][data-lk-source=camera],
        video[data-lk-local-participant=true] {
          transform: none !important;
        }
      `}</style>

      {/* Controls außerhalb des LiveKit-Containers via Portal an document.body
          → garantiert keine Überlagerung durch <video>, lk-* Overlays usw. */}
      {/* Schwebende Reaktionen */}
      <div className="fixed inset-0 pointer-events-none" style={{ zIndex: 10002 }}>
        {reactions.map(r => (
          <div
            key={r.id}
            className="absolute bottom-32 left-1/2 -translate-x-1/2 text-5xl animate-[lk-float_3s_ease-out_forwards]"
            style={{ left: `${40 + (r.id * 17) % 30}%` }}
          >
            {r.emoji}
          </div>
        ))}
      </div>

      {typeof document !== 'undefined' && createPortal(<>{controlsBar}{settingsPanel}{participantsPanel}</>, document.body)}
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
  preToken,
  preUrl,
  dmCallId,
  answeredAt,
  onRemoteJoined,
}: LiveRoomModalProps) {
  const [token, setToken]           = useState(preToken ?? '')           // FIX-73: preToken/preUrl DM-Call Durchreichung
  const [serverUrl, setServerUrl]   = useState(preUrl ?? LIVEKIT_CLOUD_URL) // FIX-73: preToken/preUrl DM-Call Durchreichung
  const [fetchError, setFetchError] = useState(false)
  const [visible, setVisible]       = useState(false)
  const [isCloudFallback, setIsCloudFallback] = useState(false)
  const [viewerMode, setViewerMode] = useState(false)
  const [isLandscape, setIsLandscape] = useState(false)
  const setIsInCall = useNavigationStore(s => s.setIsInCall)
  const cleanedUp   = useRef(false) // Tracking für isInCall-Flip (Store-Side-Effect)
  const endPosted   = useRef(false) // Tracking für /api/dm-calls/end POST — getrennt!
  const currentUrl  = useRef(LIVEKIT_CLOUD_URL)

  useModalDismiss(onClose)

  useEffect(() => {
    if (typeof window === 'undefined') return
    const mq = window.matchMedia('(orientation: landscape)')
    const handler = (e: MediaQueryListEvent) => setIsLandscape(e.matches)
    setIsLandscape(mq.matches)
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  useEffect(() => {
    setIsInCall(true)
    cleanedUp.current = false
    endPosted.current = false
    return () => {
      if (!cleanedUp.current) {
        setIsInCall(false)
        cleanedUp.current = true
      }
      // Sicherheitsnetz: Wenn der Modal abrupt unmountet (Navigation, Tab-Close,
      // App-Background) ohne dass /end gepostet wurde, holen wir das hier nach.
      // Sonst bleibt die dm_calls-Row 'active' und blockiert den nächsten Anruf.
      if (!endPosted.current && dmCallId) {
        endPosted.current = true
        // sendBeacon ist unmount-fest (browser garantiert Zustellung), Fallback auf fetch.
        try {
          const blob = new Blob([JSON.stringify({ callId: dmCallId })], { type: 'application/json' })
          if (typeof navigator !== 'undefined' && 'sendBeacon' in navigator) {
            navigator.sendBeacon('/api/dm-calls/end', blob)
          } else {
            void fetch('/api/dm-calls/end', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ callId: dmCallId }),
              keepalive: true,
            }).catch(() => {})
          }
        } catch {
          /* best effort */
        }
      }
    }
  }, [setIsInCall, dmCallId])

  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  // Native predictive-back: NativeBridge dispatches `modal-close` on the
  // top-most `[data-modal-open="true"]` element when the hardware-back button
  // is pressed. We listen on window so the modal closes from anywhere.
  useEffect(() => {
    const onModalClose = (): void => { onClose() }
    window.addEventListener('modal-close', onModalClose)
    return () => window.removeEventListener('modal-close', onModalClose)
  }, [onClose])

  const loadToken = useCallback(async (forceCloud = false) => {
    setFetchError(false)
    setToken('')
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
        body: JSON.stringify({ roomName, displayName: userName, forceCloud }),
      })
      if (!r.ok) throw new Error(`HTTP ${r.status}`)
      const { token: t, url } = await r.json()
      setToken(t)
      if (url) { setServerUrl(url); currentUrl.current = url }
    } catch {
      setFetchError(true)
    }
  }, [roomName, userName])

  useEffect(() => {
    // FIX-73: preToken/preUrl DM-Call Durchreichung
    if (dmCallId && preToken && preUrl) {
      setToken(preToken); setServerUrl(preUrl); return
    }
    loadToken()
  }, [loadToken, preToken, preUrl, dmCallId])

  // FIX-73: preToken/preUrl DM-Call Durchreichung – sync bei Reconnect
  useEffect(() => {
    if (dmCallId && preToken) setToken(preToken)
    if (dmCallId && preUrl) setServerUrl(preUrl)
  }, [dmCallId, preToken, preUrl])

  // Hilfsfunktion: /api/dm-calls/end POST, idempotent, höchstens einmal pro Modal.
  // endPosted-Ref ist absichtlich GETRENNT von cleanedUp — vorher hat der Cleanup-
  // Effect cleanedUp=true gesetzt, woraufhin handleDisconnected den /end-POST
  // übersprungen hat → Row blieb 'active' → nächster Anruf blockiert.
  const postEndOnce = useCallback(() => {
    if (endPosted.current || !dmCallId) return
    endPosted.current = true
    void fetch('/api/dm-calls/end', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callId: dmCallId }),
      keepalive: true, // damit der POST auch bei Unmount/Navigation durchgeht
    }).catch(() => { /* /start räumt stale Rows ohnehin auf */ })
  }, [dmCallId])

  // Expliziter Close (Schließen-Button, "Zurück zum Chat" usw.).
  // Beendet auch den DM-Call serverseitig.
  const handleClose = useCallback(() => {
    if (!cleanedUp.current) {
      setIsInCall(false)
      cleanedUp.current = true
    }
    postEndOnce()
    onClose()
  }, [onClose, setIsInCall, postEndOnce])

  // Wird von LiveKit's onDisconnected aufgerufen.
  // - CLIENT_INITIATED → User hat selbst aufgelegt
  // - SERVER_SHUTDOWN/UNKNOWN → transienter Netz-Drop, NICHT den DM-Call beenden,
  //   sonst killt jeder kurze Disconnect den Anruf für beide Seiten.
  const handleDisconnected = useCallback((reason?: unknown) => {
    // LiveKit DisconnectReason enum: CLIENT_INITIATED = 1
    const isClientInitiated =
      reason === 1 || (typeof reason === 'string' && reason === 'CLIENT_INITIATED')
    if (isClientInitiated) {
      postEndOnce()
      onClose()
      return
    }
    // Transienter Drop – LiveKit reconnected ohnehin selbst.
    // Modal offen lassen, damit beide Seiten weiterverbinden können.
  }, [onClose, postEndOnce])

  const handleError = useCallback((error: Error) => {
    if (currentUrl.current !== LIVEKIT_CLOUD_URL && !isCloudFallback) {
      setIsCloudFallback(true)
      toast('VPN nicht erreichbar – wechsle zu Cloud…', { icon: '☁️' })
      loadToken(true)
      return
    }
    // Fataler Fehler nach Cloud-Fallback → Anruf sauber beenden statt das
    // Modal in einem toten Zustand stehen zu lassen (sonst hängt isInCall=true
    // und der Bot bleibt versteckt, plus dm_calls-Row bleibt 'active').
    toast.error('Verbindungsfehler: ' + error.message)
    postEndOnce()
    onClose()
  }, [isCloudFallback, loadToken, postEndOnce, onClose])

  const handleMediaDeviceFailure = useCallback(
    (failure?: MediaDeviceFailure, kind?: MediaDeviceKind) => {
      if (kind === 'audioinput') toast.error('Mikrofon nicht erreichbar')
      else if (kind === 'videoinput') toast.error('Kamera nicht erreichbar')
      else toast.error('Mediengerät nicht verfügbar')
    },
    [],
  )

  return (
    <div
      data-modal-open="true"
      className={[
        'fixed inset-0 z-[9999] flex flex-col bg-gray-950',
        'transition-opacity duration-300',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      {/* Header — im Landscape-Modus ausgeblendet */}
      <div className={`flex-shrink-0 relative flex items-center justify-center px-12 py-3 border-b border-white/[0.06] ${isLandscape ? 'hidden' : ''}`}>
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
              Live{isCloudFallback && <span className="text-white/30 normal-case font-normal ml-1">(Cloud)</span>}
            </span>
            <CallTimer answeredAt={answeredAt} />
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
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
            <p className="text-sm text-white/40">Verbinde…</p>
            {/* Viewer mode option while loading */}
            <button
              onClick={() => setViewerMode(v => !v)}
              className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-medium transition-all ${
                viewerMode
                  ? 'bg-amber-500/20 text-amber-300 border border-amber-500/40'
                  : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10 hover:text-white/60'
              }`}
            >
              {viewerMode ? '👁 Zuschauer-Modus aktiv' : '👁 Als Zuschauer beitreten'}
            </button>
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
              onClick={() => loadToken()}
              className="px-6 py-2.5 rounded-full bg-primary-500 hover:bg-primary-600 text-white text-sm font-medium transition-colors"
            >
              Erneut versuchen
            </button>
            <button
              onClick={handleClose}
              className="px-6 py-2.5 rounded-full bg-white/10 hover:bg-white/15 text-white text-sm font-medium transition-colors"
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
            audio={!viewerMode}
            onDisconnected={handleDisconnected}
            onError={handleError}
            onMediaDeviceFailure={handleMediaDeviceFailure}
            // FIX-77: Robuste Reconnect-Strategie + kein Disconnect bei Page-Leave
            options={{
              reconnectPolicy: {
                nextRetryDelayInMs: (ctx) =>
                  ctx.retryCount >= 20
                    ? null
                    : Math.min(300 * Math.pow(2, ctx.retryCount), 30000),
              },
              disconnectOnPageLeave: false,
              adaptiveStream: true,
              dynacast: true,
            }}
            style={{ height: '100%', width: '100%', background: 'transparent' }}
          >
            <InnerRoom onClose={handleClose} localAvatarUrl={userAvatar} viewerMode={viewerMode} roomName={roomName} isLandscape={isLandscape} dmCallId={dmCallId} isDMCall={!!dmCallId} onRemoteJoined={onRemoteJoined} />
          </LiveKitRoom>
        )}
      </div>
    </div>
  )
}
