'use client'

import { useEffect } from 'react'

// Initialisiert Capacitor-spezifisches Verhalten:
//  - setzt 'is-native' auf <html>, damit CSS native Layouts anwenden kann
//  - blendet den Splash-Screen nach dem ersten Laden aus
//  - konfiguriert Statusbar und Keyboard
// Auf Web passiert nichts (Capacitor.isNativePlatform() === false).
export default function NativeBridge() {
  useEffect(() => {
    let cancelled = false

    ;(async () => {
      try {
        const { Capacitor } = await import('@capacitor/core')
        if (!Capacitor.isNativePlatform()) return
        if (cancelled) return

        document.documentElement.classList.add('is-native')
        document.documentElement.classList.add(`is-${Capacitor.getPlatform()}`)

        const { StatusBar, Style } = await import('@capacitor/status-bar')
        await StatusBar.setOverlaysWebView({ overlay: true })
        await StatusBar.setStyle({ style: Style.Light })

        // Splash Screen nach kurzem Delay ausblenden (App ist geladen)
        const { SplashScreen } = await import('@capacitor/splash-screen')
        if (!cancelled) {
          await SplashScreen.hide({ fadeOutDuration: 400 })
        }
      } catch {
        // Auf Web nicht verfügbar -> stillschweigend ignorieren
      }
    })()

    return () => {
      cancelled = true
    }
  }, [])

  return null
}
