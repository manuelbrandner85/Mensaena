'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { X, Video, VideoOff, MicOff, Users, ExternalLink, Loader2, Maximize2, Minimize2 } from 'lucide-react'
import { useModalDismiss } from '@/hooks/useModalDismiss'

/** Primärer Jitsi-Server – kein Login für Moderatoren nötig */
const JITSI_DOMAIN = 'meet.init7.net'

/**
 * Fallback-Domains falls Primärserver nicht erreichbar.
 * Alle ohne Moderator-Auth-Pflicht.
 */
const JITSI_FALLBACK_DOMAINS = [
  'jitsi.rocks',
  'meet.chaosdata.de',
] as const

interface LiveRoomModalProps {
  roomName: string      // e.g. "mensaena-community-general"
  channelLabel: string  // displayed in header, e.g. "# allgemein"
  userName: string
  userAvatar?: string | null  // Avatar-URL aus Mensaena-Profil
  onClose: () => void
}

export default function LiveRoomModal({
  roomName,
  channelLabel,
  userName,
  userAvatar,
  onClose,
}: LiveRoomModalProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [loaded, setLoaded] = useState(false)
  const [participantCount, setParticipantCount] = useState<number | null>(null)
  const [isFullscreen, setIsFullscreen] = useState(false)

  useModalDismiss(onClose)

  /** Fullscreen-Toggle */
  const toggleFullscreen = useCallback(async () => {
    try {
      if (!document.fullscreenElement) {
        await containerRef.current?.requestFullscreen()
        setIsFullscreen(true)
      } else {
        await document.exitFullscreen()
        setIsFullscreen(false)
      }
    } catch { /* Fullscreen nicht unterstützt – ignorieren */ }
  }, [])

  // Fullscreen-Change-Event synchronisieren (z.B. wenn User per ESC aussteigt)
  useEffect(() => {
    const handler = () => setIsFullscreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', handler)
    return () => document.removeEventListener('fullscreenchange', handler)
  }, [])

  /** Build Jitsi URL with config params passed as fragment */
  const jitsiUrl = (() => {
    const base = `https://${JITSI_DOMAIN}/${encodeURIComponent(roomName)}`
    const config = [
      // ── Audio/Video ────────────────────────────
      'config.startWithVideoMuted=true',
      'config.startWithAudioMuted=true',

      // ── Kein Login, kein Prejoin ───────────────
      'config.prejoinPageEnabled=false',
      'config.enableWelcomePage=false',
      'config.enableClosePage=false',

      // ── Profil-Name fest aus Mensaena ──────────
      `userInfo.displayName=${encodeURIComponent(userName)}`,
      'config.readOnlyName=true',

      // ── Avatar aus Mensaena-Profil ─────────────
      ...(userAvatar ? [`userInfo.avatarURL=${encodeURIComponent(userAvatar)}`] : []),

      // ── Raum-Konfiguration ─────────────────────
      `config.subject=${encodeURIComponent('Mensaena · ' + channelLabel)}`,
      'config.hideConferenceSubject=false',
      'config.disableDeepLinking=true',
      'config.disableInviteFunctions=true',
      'config.disableThirdPartyRequests=true',

      // ── Toolbar: nur relevante Buttons ─────────
      'config.toolbarButtons=["microphone","camera","chat","participants-pane","tileview","fullscreen","hangup"]',

      // ── Interface-Overrides ────────────────────
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
      'interfaceConfig.DEFAULT_REMOTE_DISPLAY_NAME=Mitglied',
      'interfaceConfig.TOOLBAR_ALWAYS_VISIBLE=false',
      'interfaceConfig.MOBILE_APP_PROMO=false',
      'interfaceConfig.HIDE_INVITE_MORE_HEADER=true',
    ]
    return `${base}#${config.join('&')}`
  })()

  // Listen for Jitsi postMessage events (participant count)
  useEffect(() => {
    const handleMessage = (e: MessageEvent) => {
      if (!e.data || typeof e.data !== 'object') return
      if (e.data.event === 'participantCountChanged') {
        setParticipantCount(e.data.count ?? null)
      }
    }
    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [])

  return (
    <div ref={containerRef} className="fixed inset-0 z-[70] bg-black/80 backdrop-blur-sm flex flex-col pb-[env(safe-area-inset-bottom)]">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-2 px-4 py-3 bg-gradient-to-r from-primary-600 to-primary-500 border-b border-primary-400/20 flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-white/20 border border-white/20 flex items-center justify-center">
            <Video className="w-4 h-4 text-white" />
          </div>
          <div>
            <p className="text-sm font-bold text-white">Live-Raum</p>
            <p className="text-xs text-white/70">{channelLabel}</p>
          </div>
          {participantCount !== null && participantCount > 0 && (
            <div className="flex items-center gap-1.5 px-2.5 py-1 bg-white/20 border border-white/20 rounded-full">
              <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
              <Users className="w-3.5 h-3.5 text-white/80" />
              <span className="text-xs font-semibold text-white">{participantCount}</span>
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          <a
            href={jitsiUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white/80 hover:text-white text-xs font-medium transition-all min-h-[44px] min-w-[44px] justify-center"
            title="In neuem Tab öffnen"
          >
            <ExternalLink className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Im Browser öffnen</span>
          </a>
          <button
            onClick={toggleFullscreen}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white/80 hover:text-white text-xs font-medium transition-all min-h-[44px] min-w-[44px] justify-center"
            title={isFullscreen ? 'Vollbild beenden' : 'Vollbild'}
          >
            {isFullscreen
              ? <Minimize2 className="w-3.5 h-3.5" />
              : <Maximize2 className="w-3.5 h-3.5" />}
            <span className="hidden sm:inline">
              {isFullscreen ? 'Verkleinern' : 'Vollbild'}
            </span>
          </button>
          <button
            onClick={onClose}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-red-500/20 hover:bg-red-500/30 text-red-200 hover:text-red-100 text-xs font-semibold transition-all border border-red-400/20 min-h-[44px] min-w-[44px] justify-center"
          >
            <X className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Verlassen</span>
          </button>
        </div>
      </div>

      {/* Iframe container */}
      <div className="flex-1 relative min-h-[60vh] sm:min-h-0">
        {!loaded && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-gradient-to-b from-primary-900/95 to-ink-950/95">
            <div className="w-20 h-20 rounded-3xl bg-primary-500/20 border border-primary-400/30 flex items-center justify-center shadow-lg shadow-primary-500/10">
              <Video className="w-10 h-10 text-primary-400" />
            </div>
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">Live-Raum wird geladen…</p>
              <p className="text-white/50 text-sm max-w-xs text-center">Der Browser fragt gleich nach Kamera & Mikrofon-Zugriff</p>
            </div>
            <Loader2 className="w-6 h-6 text-primary-400 animate-spin" />
          </div>
        )}
        <iframe
          ref={iframeRef}
          src={jitsiUrl}
          allow="camera; microphone; fullscreen; display-capture; autoplay"
          className="w-full h-full border-none rounded-none"
          onLoad={() => setLoaded(true)}
          title="Live-Raum"
        />
      </div>

      {/* Bottom hint (only shown while loading) */}
      {!loaded && (
        <div className="flex items-center justify-center flex-wrap gap-3 sm:gap-6 px-4 py-3 bg-gradient-to-t from-primary-900/50 to-transparent border-t border-white/5 flex-shrink-0">
          <div className="flex items-center gap-2 text-xs text-white/40">
            <VideoOff className="w-3.5 h-3.5 text-primary-300/60" />
            Kamera startet stumm
          </div>
          <div className="flex items-center gap-2 text-xs text-white/40">
            <MicOff className="w-3.5 h-3.5 text-primary-300/60" />
            Mikrofon startet stumm
          </div>
          <div className="flex items-center gap-2 text-xs text-white/40">
            <Video className="w-3.5 h-3.5 text-primary-300/60" />
            Powered by Jitsi Meet
          </div>
          <div className="flex items-center gap-2 text-xs text-white/40">
            <Users className="w-3.5 h-3.5 text-primary-300/60" />
            Nur für Mensaena-Mitglieder
          </div>
        </div>
      )}
    </div>
  )
}
