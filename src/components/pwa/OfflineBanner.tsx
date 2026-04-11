'use client'

import { useState, useEffect } from 'react'
import { WifiOff, Wifi, RefreshCw } from 'lucide-react'
import { useOnlineStatus } from '@/hooks/useOnlineStatus'
import { syncQueuedActions } from '@/lib/pwa/offline-storage'
import toast from 'react-hot-toast'

/**
 * Shows a banner when offline and a green "reconnected" banner when back online.
 * Also triggers a sync of queued actions when reconnecting.
 */
export default function OfflineBanner() {
  const { isOnline, wasOffline } = useOnlineStatus()
  const [showReconnect, setShowReconnect] = useState(false)
  const [syncing, setSyncing] = useState(false)

  // When we come back online after being offline, show reconnect banner & sync
  useEffect(() => {
    if (isOnline && wasOffline) {
      setShowReconnect(true)

      // Try to sync queued actions
      setSyncing(true)
      syncQueuedActions()
        .then(({ synced, failed }) => {
          if (synced > 0) {
            toast.success(`${synced} Aktion${synced > 1 ? 'en' : ''} synchronisiert`)
          }
          if (failed > 0) {
            toast.error(`${failed} Aktion${failed > 1 ? 'en' : ''} fehlgeschlagen`)
          }
        })
        .catch(() => {})
        .finally(() => setSyncing(false))

      const timer = setTimeout(() => setShowReconnect(false), 4000)
      return () => clearTimeout(timer)
    }
  }, [isOnline, wasOffline])

  // Nothing to show
  if (isOnline && !showReconnect) return null

  return (
    <div
      className={`fixed bottom-6 lg:bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 px-4 py-2.5 rounded-2xl shadow-xl text-sm font-medium transition-all duration-300 animate-fade-in ${
        isOnline ? 'bg-emerald-600 text-white' : 'bg-gray-800 text-white'
      }`}
    >
      {isOnline ? (
        <>
          {syncing ? (
            <RefreshCw className="w-4 h-4 animate-spin" />
          ) : (
            <Wifi className="w-4 h-4" />
          )}
          <span>Wieder online!</span>
        </>
      ) : (
        <>
          <WifiOff className="w-4 h-4" />
          <span>Kein Internet – App läuft im Offline-Modus</span>
        </>
      )}
    </div>
  )
}
