'use client'

import { useState, useEffect } from 'react'
import { Bell, X, BellOff } from 'lucide-react'
import { usePushNotifications } from '@/hooks/usePushNotifications'
import { isPushSupported } from '@/lib/pwa/pwa-utils'

const INTERACTION_KEY = 'mensaena-push-prompt-interactions'
const DISMISS_KEY = 'mensaena-push-prompt-dismissed'
const MIN_INTERACTIONS = 3
const DISMISS_COOLDOWN_MS = 14 * 24 * 60 * 60 * 1000 // 14 days

interface PushPermissionModalProps {
  userId?: string
}

/**
 * Shows a modal asking the user for push notification permission.
 * Only appears after the user has had a few positive interactions
 * with the app (e.g. viewed posts, sent messages).
 */
export default function PushPermissionModal({ userId }: PushPermissionModalProps) {
  const { permission, isSubscribed, loading, subscribe } = usePushNotifications()
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return
    if (!isPushSupported()) return

    // Already subscribed or denied
    if (isSubscribed || permission === 'granted' || permission === 'denied') return

    // Check dismiss cooldown
    const dismissedAt = localStorage.getItem(DISMISS_KEY)
    if (dismissedAt) {
      const elapsed = Date.now() - parseInt(dismissedAt, 10)
      if (elapsed < DISMISS_COOLDOWN_MS) return
    }

    // Track interactions (increment on mount – this component only mounts
    // inside the dashboard, so each page view counts as an interaction)
    const count = parseInt(localStorage.getItem(INTERACTION_KEY) || '0', 10) + 1
    localStorage.setItem(INTERACTION_KEY, String(count))

    if (count >= MIN_INTERACTIONS) {
      // Show after short delay
      const timer = setTimeout(() => setVisible(true), 2000)
      return () => clearTimeout(timer)
    }
  }, [isSubscribed, permission])

  if (!visible) return null

  const handleAllow = async () => {
    await subscribe(userId)
    setVisible(false)
  }

  const handleDismiss = () => {
    localStorage.setItem(DISMISS_KEY, String(Date.now()))
    setVisible(false)
  }

  const handleNever = () => {
    localStorage.setItem(DISMISS_KEY, String(Date.now() + 365 * 24 * 60 * 60 * 1000))
    setVisible(false)
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/40 backdrop-blur-sm"
        onClick={handleDismiss}
      />

      {/* Modal */}
      <div className="relative bg-white rounded-2xl shadow-2xl max-w-sm w-full overflow-hidden animate-scale-in">
        {/* Header */}
        <div className="bg-gradient-to-r from-emerald-600 to-teal-600 px-6 py-5 text-center">
          <div className="w-14 h-14 bg-white/20 rounded-2xl flex items-center justify-center mx-auto mb-3">
            <Bell className="w-7 h-7 text-white" />
          </div>
          <h3 className="text-lg font-bold text-white">Benachrichtigungen aktivieren?</h3>
        </div>

        {/* Close */}
        <button
          onClick={handleDismiss}
          className="absolute top-3 right-3 p-1.5 rounded-lg hover:bg-white/20 text-white/70 hover:text-white transition-all"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Body */}
        <div className="p-6">
          <p className="text-sm text-gray-600 text-center mb-5">
            Erhalte sofort Bescheid, wenn jemand auf deinen Beitrag antwortet oder dir eine Nachricht schreibt.
          </p>

          <div className="space-y-2">
            <button
              onClick={handleAllow}
              disabled={loading}
              className="w-full bg-emerald-600 hover:bg-emerald-700 disabled:opacity-60 text-white text-sm font-semibold py-3 px-4 rounded-xl transition-colors flex items-center justify-center gap-2"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <Bell className="w-4 h-4" />
              )}
              Ja, aktivieren
            </button>
            <button
              onClick={handleDismiss}
              className="w-full text-gray-500 hover:text-gray-700 text-sm py-2 px-4 rounded-xl transition-colors"
            >
              Später
            </button>
            <button
              onClick={handleNever}
              className="w-full text-gray-400 hover:text-gray-500 text-xs py-1 px-4 rounded-xl transition-colors flex items-center justify-center gap-1"
            >
              <BellOff className="w-3 h-3" />
              Nicht mehr fragen
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
