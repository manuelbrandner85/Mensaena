'use client'

import { useEffect, useState } from 'react'
import { X, Smartphone, Bell, Zap, WifiOff } from 'lucide-react'

const STORAGE_KEY = 'mensaena_app_banner_dismissed'
const FDROID_PAGE = 'https://manuelbrandner85.github.io/Mensaena/'
const FDROID_DEEPLINK =
  'fdroidrepos://manuelbrandner85.github.io/Mensaena' +
  '?fingerprint=C68487D0CF0F084959A01484326F04CEC541BB2E1B86D8171AA0F474356389F3'

export default function AppDownloadBanner() {
  const [visible, setVisible] = useState(false)
  const [isAndroid, setIsAndroid] = useState(false)

  useEffect(() => {
    if (document.documentElement.classList.contains('is-native')) return
    if (window.innerWidth >= 1024) return
    try { if (sessionStorage.getItem(STORAGE_KEY)) return } catch { /* ignore */ }
    setIsAndroid(/Android/i.test(navigator.userAgent))
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
          <div className="min-w-0 w-full">
            <p className="font-bold text-sm">Mensaena als App installieren</p>
            <ul className="mt-1.5 mb-3 space-y-1">
              {[
                { icon: Bell,    text: 'Push-Benachrichtigungen' },
                { icon: Zap,     text: 'Schnellere Ladezeiten' },
                { icon: WifiOff, text: 'Teils offline nutzbar' },
              ].map(({ icon: Icon, text }) => (
                <li key={text} className="flex items-center gap-1.5 text-[11px] text-white/90">
                  <Icon className="w-3 h-3 flex-shrink-0 text-white/70" />
                  {text}
                </li>
              ))}
            </ul>

            {/* Ein-Tipp-Install auf Android, sonst Link zur Installationsseite */}
            <a
              href={isAndroid ? FDROID_DEEPLINK : FDROID_PAGE}
              target={isAndroid ? undefined : '_blank'}
              rel="noopener noreferrer"
              onClick={dismiss}
              className="flex items-center justify-center gap-2 w-full py-2 bg-white text-primary-700 rounded-xl text-xs font-bold hover:bg-white/90 transition-colors"
            >
              <span>📦</span>
              {isAndroid ? 'Jetzt installieren (1 Tipp)' : 'App installieren →'}
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}
