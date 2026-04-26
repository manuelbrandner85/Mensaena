'use client'

import { useState, useEffect } from 'react'
import { Bell, X, MapPin, Handshake, MessageCircle, CheckCircle } from 'lucide-react'
import { usePushNotifications } from '@/hooks/usePushNotifications'

const SNOOZE_KEY = 'mensaena_push_prompt_snoozed'
const SNOOZE_MS = 3 * 24 * 60 * 60 * 1000 // 3 days

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
  return !!(window as unknown as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor?.isNativePlatform?.()
}

const NOTIFICATION_EXAMPLES = [
  { icon: Handshake, color: 'text-primary-600', text: 'Hilfsanfragen & Antworten' },
  { icon: MapPin,    color: 'text-purple-600',  text: 'Neue Beiträge in deiner Nähe' },
  { icon: MessageCircle, color: 'text-blue-600', text: 'Nachrichten von Nachbarn' },
]

export default function NotificationPromptBanner({ userId }: { userId: string }) {
  const [visible, setVisible] = useState(false)
  const [done, setDone] = useState(false)
  const { permission, subscribe, loading } = usePushNotifications()

  useEffect(() => {
    if (typeof window === 'undefined') return
    if (!('Notification' in window)) return
    if (isNativeApp()) return
    if (Notification.permission !== 'default') return
    if (isSnoozed()) return

    const timer = setTimeout(() => setVisible(true), 6000)
    return () => clearTimeout(timer)
  }, [])

  useEffect(() => {
    if (permission !== 'default') setVisible(false)
  }, [permission])

  if (!visible || done) return null

  function snooze() {
    try { localStorage.setItem(SNOOZE_KEY, String(Date.now())) } catch {}
    setVisible(false)
  }

  async function activate() {
    await subscribe(userId)
    setDone(true)
    setTimeout(() => setVisible(false), 1800)
  }

  return (
    <div className="fixed bottom-24 md:bottom-6 left-1/2 -translate-x-1/2 z-50 w-full max-w-sm px-4 animate-slide-up">
      <div className="bg-white rounded-2xl shadow-glow border border-primary-100 overflow-hidden">
        {/* Color bar */}
        <div className="h-1 bg-gradient-to-r from-primary-400 via-primary-500 to-primary-600" />

        <div className="p-4">
          {done ? (
            <div className="flex items-center gap-3 py-1">
              <div className="w-10 h-10 rounded-xl bg-green-50 flex items-center justify-center flex-shrink-0">
                <CheckCircle className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <p className="text-sm font-semibold text-ink-900">Aktiviert!</p>
                <p className="text-xs text-ink-500">Du bekommst jetzt Benachrichtigungen.</p>
              </div>
            </div>
          ) : (
            <>
              {/* Header */}
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 rounded-xl bg-primary-50 flex items-center justify-center flex-shrink-0">
                  <Bell className="w-5 h-5 text-primary-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-ink-900">Benachrichtigungen aktivieren</p>
                  <p className="text-xs text-ink-500 mt-0.5 leading-relaxed">
                    Verpasse keine Hilfsanfragen und Nachrichten von deinen Nachbarn.
                  </p>
                </div>
                <button
                  onClick={snooze}
                  className="text-ink-400 hover:text-ink-600 flex-shrink-0 -mt-0.5 p-0.5"
                  aria-label="Schließen"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              {/* Examples */}
              <div className="mt-3 space-y-1.5">
                {NOTIFICATION_EXAMPLES.map(({ icon: Icon, color, text }) => (
                  <div key={text} className="flex items-center gap-2">
                    <Icon className={`w-3.5 h-3.5 flex-shrink-0 ${color}`} />
                    <span className="text-xs text-ink-600">{text}</span>
                  </div>
                ))}
              </div>

              {/* Actions */}
              <div className="mt-3 flex gap-2">
                <button
                  onClick={activate}
                  disabled={loading}
                  className="flex-1 btn-primary text-sm py-2"
                >
                  {loading ? 'Wird aktiviert…' : 'Jetzt aktivieren'}
                </button>
                <button
                  onClick={snooze}
                  className="px-3 py-2 text-sm text-ink-500 hover:text-ink-700 hover:bg-stone-100 rounded-xl transition-colors"
                >
                  Später
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
