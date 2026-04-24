'use client'

import { useEffect } from 'react'

// Initialisiert Capacitor-spezifisches Verhalten:
//  - setzt 'is-native' auf <html>, damit CSS native Layouts anwenden kann
//  - konfiguriert Statusbar (overlay + light icons auf hellem Background)
//  - kein Resize beim Keyboard (body bleibt stabil, Input scrollt sich selbst)
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
