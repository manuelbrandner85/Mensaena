'use client'

import { useEffect, useRef, useState } from 'react'
import { X, Video, VideoOff, Mic, MicOff, Users, ExternalLink, Loader2 } from 'lucide-react'
import { useModalDismiss } from '@/hooks/useModalDismiss'

interface LiveRoomModalProps {
  roomName: string      // e.g. "mensaena-community-general"
  channelLabel: string  // displayed in header, e.g. "# allgemein"
  userName: string
  userAvatar?: string | null
  onClose: () => void
}

export default function LiveRoomModal({
  roomName,
  channelLabel,
  userName,
  onClose,
}: LiveRoomModalProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const [loaded, setLoaded] = useState(false)
  const [participantCount, setParticipantCount] = useState<number | null>(null)

  useModalDismiss(onClose)

  // Build Jitsi URL with config params passed as fragment
  const jitsiUrl = (() => {
    const base = `https://meet.jit.si/${encodeURIComponent(roomName)}`
    const config = [
      'config.startWithVideoMuted=true',
      'config.startWithAudioMuted=true',
      'config.prejoinPageEnabled=false',
      `config.subject=${encodeURIComponent('Mensaena · ' + channelLabel)}`,
      'config.disableDeepLinking=true',
      'config.toolbarButtons=["microphone","camera","chat","participants-pane","tileview","hangup"]',
      'config.hideConferenceSubject=false',
      'config.disableInviteFunctions=true',
      `userInfo.displayName=${encodeURIComponent(userName)}`,
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
      'interfaceConfig.DEFAULT_REMOTE_DISPLAY_NAME=Nutzer',
      'interfaceConfig.TOOLBAR_ALWAYS_VISIBLE=false',
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
    <div className="fixed inset-0 z-[70] bg-black/90 flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-ink-900 border-b border-white/10 flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-primary-500/20 border border-primary-400/30 flex items-center justify-center">
            <Video className="w-4 h-4 text-primary-400" />
          </div>
          <div>
            <p className="text-sm font-semibold text-white">Live-Raum</p>
            <p className="text-xs text-white/50">{channelLabel}</p>
          </div>
          {participantCount !== null && participantCount > 0 && (
            <div className="flex items-center gap-1.5 px-2.5 py-1 bg-primary-500/20 border border-primary-400/30 rounded-full">
              <div className="w-1.5 h-1.5 rounded-full bg-primary-400 animate-pulse" />
              <Users className="w-3 h-3 text-primary-300" />
              <span className="text-xs font-semibold text-primary-300">{participantCount}</span>
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          <a
            href={jitsiUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white/70 hover:text-white text-xs font-medium transition-all"
            title="In neuem Tab öffnen"
          >
            <ExternalLink className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Im Browser öffnen</span>
          </a>
          <button
            onClick={onClose}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-500/20 hover:bg-red-500/30 text-red-400 hover:text-red-300 text-xs font-semibold transition-all border border-red-500/20"
          >
            <X className="w-3.5 h-3.5" />
            Verlassen
          </button>
        </div>
      </div>

      {/* Iframe container */}
      <div className="flex-1 relative">
        {!loaded && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-ink-900">
            <div className="w-16 h-16 rounded-2xl bg-primary-500/20 border border-primary-400/30 flex items-center justify-center">
              <Video className="w-8 h-8 text-primary-400" />
            </div>
            <div className="text-center">
              <p className="text-white font-semibold mb-1">Live-Raum wird geladen…</p>
              <p className="text-white/40 text-sm">Der Browser fragt gleich nach Kamera & Mikrofon-Zugriff</p>
            </div>
            <Loader2 className="w-5 h-5 text-primary-400 animate-spin" />
          </div>
        )}
        <iframe
          ref={iframeRef}
          src={jitsiUrl}
          allow="camera; microphone; fullscreen; display-capture; autoplay"
          className="w-full h-full border-none"
          onLoad={() => setLoaded(true)}
          title="Live-Raum"
        />
      </div>

      {/* Bottom hint (only shown while loading) */}
      {!loaded && (
        <div className="flex items-center justify-center gap-6 px-4 py-3 bg-ink-900 border-t border-white/10 flex-shrink-0">
          <div className="flex items-center gap-2 text-xs text-white/40">
            <VideoOff className="w-3.5 h-3.5" />
            Kamera startet stumm
          </div>
          <div className="flex items-center gap-2 text-xs text-white/40">
            <MicOff className="w-3.5 h-3.5" />
            Mikrofon startet stumm
          </div>
          <div className="flex items-center gap-2 text-xs text-white/40">
            <Users className="w-3.5 h-3.5" />
            Powered by Jitsi Meet
          </div>
        </div>
      )}
    </div>
  )
}
