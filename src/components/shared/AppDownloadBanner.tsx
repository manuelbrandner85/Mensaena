'use client'

import { useEffect, useState } from 'react'
import { X, Smartphone, Bell, Zap, WifiOff } from 'lucide-react'

const STORAGE_KEY = 'mensaena_app_banner_dismissed'

export default function AppDownloadBanner() {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    // Never show in native Capacitor app
    if (document.documentElement.classList.contains('is-native')) return

    // Only show on mobile-sized screens (where an app would make sense)
    if (window.innerWidth >= 1024) return

    // Don't show if dismissed in this session
    try {
      if (sessionStorage.getItem(STORAGE_KEY)) return
    } catch {
      // ignore
    }

    // Small delay so the page settles first
    const t = setTimeout(() => setVisible(true), 1500)
    return () => clearTimeout(t)
  }, [])

  const dismiss = () => {
    setVisible(false)
    try { sessionStorage.setItem(STORAGE_KEY, '1') } catch { /* ignore */ }
  }

  if (!visible) return null

  return (
    <div className="fixed bottom-[72px] left-3 right-3 z-50 animate-slide-up">
      <div className="bg-gradient-to-br from-primary-600 to-teal-600 rounded-2xl shadow-glow-teal text-white p-4 relative overflow-hidden">
        <div className="absolute inset-0 bg-noise opacity-10 pointer-events-none" />
        <div className="absolute -top-4 -right-4 w-20 h-20 rounded-full bg-white/10 blur-xl pointer-events-none" />

        <button
          onClick={dismiss}
          className="absolute top-3 right-3 p-1 rounded-full hover:bg-white/20 transition-colors"
          aria-label="Schließen"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="flex items-start gap-3 pr-6">
          <div className="flex-shrink-0 w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
            <Smartphone className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <p className="font-bold text-sm">Mensaena App – bald verfügbar!</p>
            <p className="text-xs text-white/75 mt-0.5 leading-relaxed">
              Die native App bringt Vorteile gegenüber dem Browser:
            </p>
            <ul className="mt-2 space-y-1">
              {[
                { icon: Bell,   text: 'Echtzeit-Push-Benachrichtigungen' },
                { icon: Zap,    text: 'Schnellere Ladezeiten' },
                { icon: WifiOff,text: 'Teils offline nutzbar' },
              ].map(({ icon: Icon, text }) => (
                <li key={text} className="flex items-center gap-1.5 text-[11px] text-white/90">
                  <Icon className="w-3 h-3 flex-shrink-0 text-white/70" />
                  {text}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
