'use client'

import { RefreshCw, X } from 'lucide-react'
import { usePWA } from '@/hooks/usePWA'
import { useState } from 'react'

/**
 * Shows a banner when a new service worker version is available.
 * The user can choose to reload immediately or dismiss.
 */
export default function UpdateAvailable() {
  const { isUpdateAvailable, applyUpdate } = usePWA()
  const [dismissed, setDismissed] = useState(false)

  if (!isUpdateAvailable || dismissed) return null

  return (
    <div className="fixed top-16 lg:top-4 left-1/2 -translate-x-1/2 z-50 animate-slide-down">
      <div className="bg-blue-600 text-white rounded-2xl shadow-2xl px-4 py-3 flex items-center gap-3 max-w-sm">
        <RefreshCw className="w-5 h-5 flex-shrink-0" />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold">Neue Version verfügbar</p>
          <p className="text-xs text-blue-100">Lade die Seite neu, um die neueste Version zu erhalten.</p>
        </div>
        <div className="flex items-center gap-1 flex-shrink-0">
          <button
            onClick={applyUpdate}
            className="bg-white text-blue-600 text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-blue-50 transition-colors"
          >
            Aktualisieren
          </button>
          <button
            onClick={() => setDismissed(true)}
            className="p-1 rounded-lg hover:bg-white/20 text-white/70 hover:text-white transition-all"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  )
}
