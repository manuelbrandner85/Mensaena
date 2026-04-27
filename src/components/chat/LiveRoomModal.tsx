'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { X, Video, VideoOff, MicOff, Users, ExternalLink, Loader2, Maximize2, Minimize2, RefreshCw, AlertTriangle } from 'lucide-react'
import { useModalDismiss } from '@/hooks/useModalDismiss'

/**
 * Jitsi-Domains in Reihenfolge der Bevorzugung.
 * Alle ohne Moderator-Auth-Pflicht. Bei iframe-Blockierung
 * (X-Frame-Options) rotiert das Modal automatisch zur nächsten.
 */
const JITSI_DOMAINS = [
  'meet.ffmuc.net',
  'jitsi.rocks',
  'meet.chaosdata.de',
  'meet.golem.de',
] as const

/** Nach dieser Zeit ohne onLoad gilt Domain als blockiert/unerreichbar */
const LOAD_TIMEOUT_MS = 10_000

interface LiveRoomModalProps {
  roomName: string
  channelLabel: string
  userName: string
  userAvatar?: string | null
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
  const [domainIndex, setDomainIndex] = useState(0)
  const [exhausted, setExhausted] = useState(false)

  useModalDismiss(onClose)

  const currentDomain = JITSI_DOMAINS[domainIndex] ?? JITSI_DOMAINS[0]

  /** Build Jitsi URL with config params passed as fragment */
  const jitsiUrl = useMemo(() => {
    const base = `https://${currentDomain}/${encodeURIComponent(roomName)}`
    const config = [
      'config.startWithVideoMuted=true',
      'config.startWithAudioMuted=true',
      'config.prejoinPageEnabled=false',
      'config.enableWelcomePage=false',
      'config.enableClosePage=false',
      `userInfo.displayName=${encodeURIComponent(userName)}`,
      'config.readOnlyName=true',
      ...(userAvatar ? [`userInfo.avatarURL=${encodeURIComponent(userAvatar)}`] : []),
      `config.subject=${encodeURIComponent('Mensaena · ' + channelLabel)}`,
      'config.hideConferenceSubject=false',
      'config.disableDeepLinking=true',
      'config.disableInviteFunctions=true',
      'config.disableThirdPartyRequests=true',
      'config.toolbarButtons=["microphone","camera","chat","participants-pane","tileview","fullscreen","hangup"]',
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
      'interfaceConfig.DEFAULT_REMOTE_DISPLAY_NAME=Mitglied',
      'interfaceConfig.TOOLBAR_ALWAYS_VISIBLE=false',
      'interfaceConfig.MOBILE_APP_PROMO=false',
      'interfaceConfig.HIDE_INVITE_MORE_HEADER=true',
    ]
    return `${base}#${config.join('&')}`
  }, [currentDomain, roomName, userName, userAvatar, channelLabel])

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

  // Sync fullscreen state (z.B. wenn User per ESC aussteigt)
  useEffect(() => {
    const handler = () => setIsFullscreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', handler)
    return () => document.removeEventListener('fullscreenchange', handler)
  }, [])

  // Auto-Rotation: wenn iframe innerhalb LOAD_TIMEOUT_MS nicht lädt → nächste Domain
  useEffect(() => {
    if (loaded || exhausted) return
    const timer = setTimeout(() => {
      if (domainIndex < JITSI_DOMAINS.length - 1) {
        setDomainIndex(i => i + 1)
      } else {
        setExhausted(true)
      }
    }, LOAD_TIMEOUT_MS)
    return () => clearTimeout(timer)
  }, [domainIndex, loaded, exhausted])

  // Reset loaded state on domain change
  useEffect(() => { setLoaded(false) }, [domainIndex])

  /** Manueller Skip zum nächsten Server */
  const skipToNextDomain = useCallback(() => {
    if (domainIndex < JITSI_DOMAINS.length - 1) {
      setDomainIndex(i => i + 1)
    } else {
      setExhausted(true)
    }
  }, [domainIndex])

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

      {/* Iframe / Fallback container */}
      <div className="flex-1 relative min-h-[60vh] sm:min-h-0">
        {exhausted ? (
          // ── Alle Server fehlgeschlagen → Tab-Fallback ────────
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-5 px-6 bg-gradient-to-b from-primary-900/95 to-ink-950/95">
            <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-400/30 flex items-center justify-center shadow-lg shadow-amber-500/10">
              <AlertTriangle className="w-10 h-10 text-amber-300" />
            </div>
            <div className="text-center max-w-md">
              <p className="text-white font-bold text-lg mb-2">Live-Raum lässt sich nicht einbetten</p>
              <p className="text-white/60 text-sm leading-relaxed">
                Die verfügbaren Jitsi-Server erlauben keine Einbettung mehr in andere Webseiten.
                Du kannst den Raum aber direkt in einem neuen Tab öffnen – Name und Avatar werden mit übernommen.
              </p>
            </div>
            <a
              href={jitsiUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 px-6 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/30 transition-all min-h-[48px]"
            >
              <ExternalLink className="w-4 h-4" />
              Live-Raum in neuem Tab öffnen
            </a>
            <button
              onClick={() => { setDomainIndex(0); setExhausted(false) }}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-white/60 hover:text-white text-xs font-medium transition-all"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              Erneut versuchen
            </button>
          </div>
        ) : (
          <>
            {!loaded && (
              <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-gradient-to-b from-primary-900/95 to-ink-950/95 z-10">
                <div className="w-20 h-20 rounded-3xl bg-primary-500/20 border border-primary-400/30 flex items-center justify-center shadow-lg shadow-primary-500/10">
                  <Video className="w-10 h-10 text-primary-400" />
                </div>
                <div className="text-center">
                  <p className="text-white font-bold text-lg mb-1">Live-Raum wird geladen…</p>
                  <p className="text-white/50 text-sm max-w-xs text-center">
                    Server <span className="font-mono text-primary-300">{currentDomain}</span>
                    {domainIndex > 0 && <span className="text-white/40"> · Versuch {domainIndex + 1}/{JITSI_DOMAINS.length}</span>}
                  </p>
                </div>
                <Loader2 className="w-6 h-6 text-primary-400 animate-spin" />
                <button
                  onClick={skipToNextDomain}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/60 hover:text-white text-xs font-medium transition-all"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                  {domainIndex < JITSI_DOMAINS.length - 1 ? 'Anderen Server probieren' : 'Im neuen Tab öffnen'}
                </button>
              </div>
            )}
            <iframe
              ref={iframeRef}
              key={currentDomain}
              src={jitsiUrl}
              allow="camera; microphone; fullscreen; display-capture; autoplay"
              className="w-full h-full border-none rounded-none"
              onLoad={() => setLoaded(true)}
              title="Live-Raum"
            />
          </>
        )}
      </div>

      {/* Bottom hint (only shown while loading and not exhausted) */}
      {!loaded && !exhausted && (
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
