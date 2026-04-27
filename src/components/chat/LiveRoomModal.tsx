'use client'

import { useEffect, useState } from 'react'
import { X, Video, Loader2, AlertTriangle } from 'lucide-react'
import {
  LiveKitRoom,
  VideoConference,
  RoomAudioRenderer,
} from '@livekit/components-react'
import '@livekit/components-styles'
import { useModalDismiss } from '@/hooks/useModalDismiss'

const LIVEKIT_CLOUD_URL = 'wss://mensaena-atyyhep6.livekit.cloud'

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
  onClose,
}: LiveRoomModalProps) {
  const [token, setToken]       = useState<string | null>(null)
  const [serverUrl, setServerUrl] = useState(LIVEKIT_CLOUD_URL)
  const [fetchError, setFetchError] = useState(false)
  const [visible, setVisible] = useState(false)

  useModalDismiss(onClose)

  // Entrance animation
  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  // Fetch LiveKit JWT token from our server
  useEffect(() => {
    fetch('/api/live-room/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ roomName, displayName: userName }),
    })
      .then(r => r.ok ? r.json() : Promise.reject())
      .then(({ token, url }) => { setToken(token); if (url) setServerUrl(url) })
      .catch(() => setFetchError(true))
  }, [roomName, userName])

  return (
    <div
      className={[
        'fixed inset-0 z-[70] flex flex-col bg-gray-950',
        'transition-opacity duration-200',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      {/* Mensaena header */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 py-3 bg-gradient-to-r from-primary-600 to-primary-500">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
            <Video className="w-5 h-5 text-white" />
          </div>
          <div>
            <p className="text-sm font-bold text-white leading-tight">Live-Raum</p>
            <p className="text-xs text-white/70">{channelLabel}</p>
          </div>
          {token && (
            <span className="flex items-center gap-1 ml-2 text-xs text-green-300 font-medium">
              <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
              Live
            </span>
          )}
        </div>
        <button
          onClick={onClose}
          className="w-9 h-9 flex items-center justify-center rounded-xl bg-white/15 hover:bg-white/25 text-white transition-all"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Video area */}
      <div className="flex-1 relative overflow-hidden">

        {/* Loading */}
        {!token && !fetchError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
            <p className="text-sm text-white/50">Verbinde…</p>
          </div>
        )}

        {/* Error */}
        {fetchError && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 px-6 text-center">
            <AlertTriangle className="w-10 h-10 text-amber-400" />
            <p className="text-white font-semibold">Verbindung fehlgeschlagen</p>
            <p className="text-sm text-white/50">Bitte versuche es erneut.</p>
            <button
              onClick={onClose}
              className="mt-2 px-5 py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white text-sm font-medium transition-all"
            >
              Zurück zum Chat
            </button>
          </div>
        )}

        {/* LiveKit conference — directly embedded, no popup, no browser */}
        {token && (
          <LiveKitRoom
            serverUrl={serverUrl}
            token={token}
            connect={true}
            video={false}
            audio={false}
            onDisconnected={onClose}
            style={{ height: '100%', width: '100%' }}
            data-lk-theme="default"
          >
            <VideoConference />
            <RoomAudioRenderer />
          </LiveKitRoom>
        )}
      </div>
    </div>
  )
}
