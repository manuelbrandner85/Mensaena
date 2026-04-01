'use client'

import { useState, useEffect } from 'react'
import { WifiOff, Wifi } from 'lucide-react'

export default function OfflineIndicator() {
  const [isOnline, setIsOnline] = useState(true)
  const [wasOffline, setWasOffline] = useState(false)
  const [showBack, setShowBack] = useState(false)

  useEffect(() => {
    setIsOnline(navigator.onLine)

    const handleOnline = () => {
      setIsOnline(true)
      if (wasOffline) {
        setShowBack(true)
        setTimeout(() => setShowBack(false), 3000)
      }
    }
    const handleOffline = () => {
      setIsOnline(false)
      setWasOffline(true)
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)
    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [wasOffline])

  if (isOnline && !showBack) return null

  return (
    <div className={`fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-2 px-4 py-2.5 rounded-2xl shadow-xl text-sm font-medium transition-all animate-fade-in ${
      isOnline
        ? 'bg-green-600 text-white'
        : 'bg-gray-800 text-white'
    }`}>
      {isOnline
        ? <><Wifi className="w-4 h-4" /> Wieder online!</>
        : <><WifiOff className="w-4 h-4" /> Kein Internet – App läuft im Offline-Modus</>
      }
    </div>
  )
}
