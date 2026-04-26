'use client'

import { useEffect } from 'react'

// Sanfter Begrüßungs-Chime (C-Dur-Arpeggio) via Web Audio API.
// Kein Audio-File nötig – vollständig synthetisiert.
function playSplashSound() {
  try {
    const ctx = new (window.AudioContext || (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext)()
    if (!ctx) return

    // C major arpeggio: C5 → E5 → G5 → C6, sanft und warm
    const notes = [
      { freq: 523.25, start: 0.0,  dur: 0.55 },
      { freq: 659.25, start: 0.14, dur: 0.55 },
      { freq: 783.99, start: 0.28, dur: 0.65 },
      { freq: 1046.5, start: 0.46, dur: 0.9  },
    ]

    for (const note of notes) {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.type = 'sine'
      osc.frequency.setValueAtTime(note.freq, ctx.currentTime + note.start)

      const t0 = ctx.currentTime + note.start
      gain.gain.setValueAtTime(0, t0)
      gain.gain.linearRampToValueAtTime(0.18, t0 + 0.03)       // soft attack
      gain.gain.exponentialRampToValueAtTime(0.001, t0 + note.dur)  // natural decay

      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.start(t0)
      osc.stop(t0 + note.dur)
    }

    // Context nach dem letzten Ton schließen
    setTimeout(() => ctx.close().catch(() => {}), 1600)
  } catch {
    // Web Audio nicht verfügbar (z.B. Policy-Block) → still ignorieren
  }
}

// Initialisiert Capacitor-spezifisches Verhalten:
//  - setzt 'is-native' auf <html>, damit CSS native Layouts anwenden kann
//  - blendet den Splash-Screen nach dem ersten Laden aus
//  - konfiguriert Statusbar und Keyboard
//  - registriert Android Hardware-Back-Button Handler
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

        // Begrüßungs-Sound während Splash sichtbar ist
        playSplashSound()

        // Splash Screen erst nach 2 weiteren Sekunden ausblenden
        await new Promise<void>((resolve) => setTimeout(resolve, 2000))

        const { SplashScreen } = await import('@capacitor/splash-screen')
        if (!cancelled) {
          await SplashScreen.hide({ fadeOutDuration: 500 })
        }
      } catch {
        // Auf Web nicht verfügbar -> stillschweigend ignorieren
      }
    })()

    // Android Hardware-Back-Button: navigiere zurück oder ignoriere
    // (Capacitor injiziert das 'backbutton'-Event ohne eigenes Plugin)
    function handleBackButton(e: Event) {
      e.preventDefault()
      if (window.history.length > 1) {
        window.history.back()
      }
      // Kein history mehr → default Capacitor-Verhalten (App minimieren)
    }
    document.addEventListener('backbutton', handleBackButton, false)

    return () => {
      cancelled = true
      document.removeEventListener('backbutton', handleBackButton, false)
    }
  }, [])

  return null
}
