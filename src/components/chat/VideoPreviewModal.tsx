'use client'

// FEATURE: Video-Preview vor Anruf

import { useEffect, useRef, useState } from 'react'
import { Video, X, Loader2 } from 'lucide-react'

interface VideoPreviewModalProps {
  partnerName: string
  onConfirm: () => void
  onCancel: () => void
}

export default function VideoPreviewModal({
  partnerName,
  onConfirm,
  onCancel,
}: VideoPreviewModalProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    navigator.mediaDevices.getUserMedia({ video: true, audio: false })
      .then(stream => {
        if (cancelled) { stream.getTracks().forEach(t => t.stop()); return }
        streamRef.current = stream
        if (videoRef.current) {
          videoRef.current.srcObject = stream
        }
        setLoading(false)
      })
      .catch(() => {
        if (!cancelled) {
          setError('Kamera konnte nicht geöffnet werden')
          setLoading(false)
        }
      })
    return () => {
      cancelled = true
      streamRef.current?.getTracks().forEach(t => t.stop())
    }
  }, [])

  const handleConfirm = () => {
    streamRef.current?.getTracks().forEach(t => t.stop())
    onConfirm()
  }

  const handleCancel = () => {
    streamRef.current?.getTracks().forEach(t => t.stop())
    onCancel()
  }

  return (
    <div
      className="fixed inset-0 z-[200] bg-black/60 backdrop-blur-sm flex items-center justify-center p-6"
      role="dialog"
      aria-modal="true"
      aria-label="Video-Vorschau"
      onClick={(e) => { if (e.target === e.currentTarget) handleCancel() }}
    >
      <div className="bg-white rounded-2xl p-5 max-w-sm w-full shadow-xl animate-scale-in">
        <div className="flex items-center justify-between mb-4">
          <p className="text-gray-900 font-semibold text-lg">
            📹 {partnerName} videoanrufen
          </p>
          <button
            onClick={handleCancel}
            className="p-2 rounded-full hover:bg-gray-100 min-w-[44px] min-h-[44px] flex items-center justify-center"
            aria-label="Abbrechen"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Kamera-Vorschau */}
        <div className="relative w-full aspect-[4/3] rounded-2xl overflow-hidden bg-gray-900 mb-4">
          {loading && (
            <div className="absolute inset-0 flex items-center justify-center">
              <Loader2 className="w-8 h-8 text-white/50 animate-spin" />
            </div>
          )}
          {error ? (
            <div className="absolute inset-0 flex items-center justify-center">
              <p className="text-white/60 text-sm text-center px-4">{error}</p>
            </div>
          ) : (
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              className="w-full h-full object-cover"
              style={{ transform: 'scaleX(-1)' }}
            />
          )}
        </div>

        <p className="text-gray-400 text-xs text-center mb-4">
          So sehen dich andere Teilnehmer
        </p>

        {/* Buttons */}
        <div className="flex gap-3">
          <button
            onClick={handleCancel}
            className="flex-1 py-3 rounded-xl bg-gray-100 text-gray-600 font-medium active:scale-95 transition-transform min-h-[44px]"
          >
            Abbrechen
          </button>
          <button
            onClick={handleConfirm}
            disabled={!!error}
            className="flex-1 py-3 rounded-xl bg-primary-500 text-white font-semibold shadow-glow active:scale-95 transition-transform min-h-[44px] disabled:opacity-40 flex items-center justify-center gap-2"
          >
            <Video className="w-4 h-4" />
            Anrufen
          </button>
        </div>
      </div>
    </div>
  )
}
