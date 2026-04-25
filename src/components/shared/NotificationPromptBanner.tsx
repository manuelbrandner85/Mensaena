'use client'

import { useState, useEffect } from 'react'
import { Bell, X } from 'lucide-react'
import { usePushNotifications } from '@/hooks/usePushNotifications'

const SNOOZE_KEY = 'mensaena_push_prompt_snoozed'
const SNOOZE_MS = 7 * 24 * 60 * 60 * 1000

function isSnoozed(): boolean {
  try {
    const stored = localStorage.getItem(SNOOZE_KEY)
    if (!stored) return false
    return Date.now() - parseInt(stored, 10) < SNOOZE_MS
  } catch {
    return false
  }
}

function isNativeApp(): boolean {
  if (typeof window === 'undefined') return false
  return /\bCapacitorBridge\b|mensaena-android/i.test(navigator.userAgent)
}

export default function NotificationPromptBanner({ userId }: { userId: string }) {
  const [visible, setVisible] = useState(false)
  const { permission, subscribe, loading } = usePushNotifications()

  useEffect(() => {
    if (typeof window === 'undefined') return
    if (!('Notification' in window)) return
    if (isNativeApp()) return
    if (Notification.permission !== 'default') return
    if (isSnoozed()) return

    const timer = setTimeout(() => setVisible(true), 5000)
    return () => clearTimeout(timer)
  }, [])

  useEffect(() => {
    if (permission !== 'default') setVisible(false)
  }, [permission])

  if (!visible) return null

  function snooze() {
    try { localStorage.setItem(SNOOZE_KEY, String(Date.now())) } catch {}
    setVisible(false)
  }

  async function activate() {
    await subscribe(userId)
    setVisible(false)
  }

  return (
    <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-50 w-full max-w-sm px-4 animate-slide-up">
      <div className="bg-white rounded-2xl shadow-card border border-primary-100 overflow-hidden">
        <div className="h-1 bg-gradient-to-r from-primary-400 to-primary-600" />
        <div className="p-4">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary-50 flex items-center justify-center flex-shrink-0">
              <Bell className="w-5 h-5 text-primary-600" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-gray-900">Bleib in der Nähe</p>
              <p className="text-xs text-gray-500 mt-0.5 leading-relaxed">
                Bekomme sofort eine Nachricht, wenn Nachbarn Hilfe brauchen oder auf deine Anfragen antworten.
              </p>
            </div>
            <button onClick={snooze} className="text-gray-400 hover:text-gray-600 flex-shrink-0 -mt-0.5" aria-label="Schließen">
              <X className="w-4 h-4" />
            </button>
          </div>

          <div className="mt-3">
            <button
              onClick={activate}
              disabled={loading}
              className="w-full btn-primary text-sm py-2"
            >
              {loading ? 'Wird aktiviert…' : 'Aktivieren'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
