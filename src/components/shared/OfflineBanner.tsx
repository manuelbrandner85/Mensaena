'use client'

/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Offline Banner
   Fixed top banner that shows when navigator.onLine === false.
   Auto-dismisses when connection returns.
   ═══════════════════════════════════════════════════════════════════════ */

import { useEffect, useState } from 'react'
import { WifiOff, Wifi } from 'lucide-react'

export default function OfflineBanner() {
  const [mounted, setMounted] = useState(false)
  const [online, setOnline] = useState(true)
  const [showReconnected, setShowReconnected] = useState(false)

  useEffect(() => {
    setMounted(true)
    if (typeof navigator !== 'undefined') {
      setOnline(navigator.onLine)
    }

    const goOffline = () => {
      setOnline(false)
      setShowReconnected(false)
    }
    const goOnline = () => {
      setOnline(true)
      setShowReconnected(true)
      window.setTimeout(() => setShowReconnected(false), 3000)
    }

    window.addEventListener('offline', goOffline)
    window.addEventListener('online', goOnline)
    return () => {
      window.removeEventListener('offline', goOffline)
      window.removeEventListener('online', goOnline)
    }
  }, [])

  if (!mounted) return null
  if (online && !showReconnected) return null

  const isReconnected = online && showReconnected

  return (
    <div
      className="fixed top-0 left-0 right-0 z-[90] pointer-events-none safe-area-top"
      role="status"
      aria-live="polite"
    >
      <div
        className={`mx-auto max-w-md mt-2 pointer-events-auto rounded-2xl shadow-lg border px-4 py-2.5 flex items-center gap-3 backdrop-blur-md animate-slide-down ${
          isReconnected
            ? 'bg-primary-50/95 border-primary-200 text-primary-600'
            : 'bg-amber-50/95 border-amber-200 text-amber-900'
        }`}
      >
        <span
          className={`w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 ${
            isReconnected ? 'bg-primary-50 text-primary-600' : 'bg-amber-100 text-amber-700'
          }`}
        >
          {isReconnected ? <Wifi className="w-4 h-4" /> : <WifiOff className="w-4 h-4" />}
        </span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium leading-tight">
            {isReconnected ? 'Wieder online' : 'Keine Internetverbindung'}
          </p>
          <p className="text-xs opacity-80 leading-snug">
            {isReconnected
              ? 'Deine Verbindung ist zurück.'
              : 'Einige Funktionen sind vorübergehend nicht verfügbar.'}
          </p>
        </div>
      </div>
    </div>
  )
}
