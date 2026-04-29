'use client'

import { useEffect } from 'react'

// Sanfter Begrüßungs-Chime (C-Dur-Arpeggio) via Web Audio API.
// Kein Audio-File nötig – vollständig synthetisiert.
function playSplashSound() {
  try {
    const ctx = new (window.AudioContext || (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext)()
    if (!ctx) return

    // Cold-start: AudioContext startet meist 'suspended' bis es einen User-
    // Gesture gab. Auf nativem Android (WebView) erlauben wir Auto-Play, daher
    // resume() versuchen — sonst bleibt der Splash-Chime stumm.
    if (ctx.state === 'suspended') {
      try { ctx.resume() } catch { /* policy-block — silent */ }
    }

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

        // ── Deep-link handler ZUERST registrieren (vor Splash) ──────────────
        // appUrlOpen feuert wenn MainActivity einen Intent-URL bekommt – z.B.
        // wenn der User "Annehmen" auf der nativen IncomingCallService-Notification
        // tippt. Wir navigieren den WebView dann direkt zur Anruf-Seite.
        const { App } = await import('@capacitor/app')
        const navigateToDashboard = (raw: string) => {
          try {
            const url = new URL(raw)
            if (
              url.hostname.endsWith('mensaena.de') &&
              url.pathname.startsWith('/dashboard')
            ) {
              // Race-Vermeidung: User steckt noch im Auth-Flow → Deep-Link
              // jetzt würde Login abbrechen. Auth-Redirect übernimmt nach
              // erfolgreichem Login die Navigation zum Dashboard ohnehin.
              if (
                typeof window !== 'undefined' &&
                window.location.pathname.startsWith('/auth')
              ) {
                return
              }
              window.location.href = url.pathname + url.search
            }
          } catch { /* invalid URL */ }
        }
        App.addListener('appUrlOpen', (event) => {
          if (cancelled) return
          navigateToDashboard(event.url)
        })
        // Cold-start: App war komplett beendet, Intent-URL aus Launch lesen.
        const launchData = await App.getLaunchUrl().catch(() => null)
        if (launchData?.url && !cancelled) {
          navigateToDashboard(launchData.url)
        }

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
