'use client'

import { useEffect } from 'react'

// Sanfter Begrüßungs-Chime (C-Dur-Arpeggio) via Web Audio API.
// Kein Audio-File nötig – vollständig synthetisiert.
function playSplashSound(): void {
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

/**
 * Polls until `#main-content` has children (i.e. React has rendered into it)
 * or `timeoutMs` elapses, whichever comes first. Used to delay the splash
 * fade until the app actually has something to show.
 */
function waitForContent(timeoutMs = 4000): Promise<void> {
  return new Promise<void>((resolve) => {
    const start = Date.now()
    const check = (): void => {
      const el = document.getElementById('main-content')
      if (el && el.children.length > 0) { resolve(); return }
      if (Date.now() - start >= timeoutMs) { resolve(); return }
      requestAnimationFrame(check)
    }
    check()
  })
}

/**
 * Initialisiert Capacitor-spezifisches Verhalten. Auf Web ist die
 * Komponente ein Noop (Capacitor.isNativePlatform() === false).
 *
 * Verantwortlichkeiten:
 *  - setzt `is-native` (+ Plattform-Klasse) auf `<html>`
 *  - registriert Deep-Link Handler (appUrlOpen)
 *  - konfiguriert StatusBar (Light/Dark) und folgt System-Theme
 *  - meldet Keyboard-Höhe via CSS-Variable + `keyboard-open` Klasse
 *  - blendet Splash-Screen nach erstem Render aus
 *  - implementiert "predictive" Hardware-Back-Button-Kette
 */
export default function NativeBridge() {
  useEffect(() => {
    let cancelled = false
    /** Aufräum-Funktionen für Listener etc., die wir asynchron aufgesetzt haben. */
    const cleanups: Array<() => void> = []

    ;(async () => {
      try {
        const { Capacitor } = await import('@capacitor/core')
        if (!Capacitor.isNativePlatform()) return
        if (cancelled) return

        document.documentElement.classList.add('is-native')
        document.documentElement.classList.add(`is-${Capacitor.getPlatform()}`)

        // ── Deep-link handler ZUERST registrieren (vor Splash) ──────────────
        const { App } = await import('@capacitor/app')
        const navigateToDashboard = (raw: string): void => {
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
        const urlOpenHandle = await App.addListener('appUrlOpen', (event: { url: string }) => {
          if (cancelled) return
          navigateToDashboard(event.url)
        })
        cleanups.push(() => { void urlOpenHandle.remove() })

        const launchData = await App.getLaunchUrl().catch(() => null)
        if (launchData?.url && !cancelled) {
          navigateToDashboard(launchData.url)
        }

        // ── StatusBar: folge System-Theme ───────────────────────────────────
        const { StatusBar, Style } = await import('@capacitor/status-bar')
        await StatusBar.setOverlaysWebView({ overlay: true })

        const applyTheme = async (_isDark: boolean): Promise<void> => {
          // Dark mode deaktiviert bis Tailwind dark:-Varianten implementiert sind.
          // App bleibt immer im Light Mode.
          document.documentElement.classList.remove('dark')
          try { await StatusBar.setStyle({ style: Style.Light }) } catch { /* ignore */ }
          try { await StatusBar.setBackgroundColor({ color: '#EEF9F9' }) } catch { /* ignore */ }
        }
        const mq = window.matchMedia('(prefers-color-scheme: dark)')
        await applyTheme(mq.matches)
        const onSchemeChange = (e: MediaQueryListEvent): void => { void applyTheme(e.matches) }
        mq.addEventListener('change', onSchemeChange)
        cleanups.push(() => mq.removeEventListener('change', onSchemeChange))

        // ── Keyboard: CSS-Variable + Klasse für sanfte Eingabefeld-Animation ─
        try {
          const { Keyboard } = await import('@capacitor/keyboard')
          const showHandle = await Keyboard.addListener('keyboardWillShow', (info) => {
            document.documentElement.style.setProperty('--keyboard-height', `${info.keyboardHeight}px`)
            document.documentElement.classList.add('keyboard-open')
          })
          const hideHandle = await Keyboard.addListener('keyboardWillHide', () => {
            document.documentElement.style.setProperty('--keyboard-height', '0px')
            document.documentElement.classList.remove('keyboard-open')
          })
          cleanups.push(() => { void showHandle.remove() })
          cleanups.push(() => { void hideHandle.remove() })
        } catch { /* keyboard plugin not available */ }

        // Begrüßungs-Sound während Splash sichtbar ist
        playSplashSound()

        // ── Splash-Übergang: warten bis #main-content gerendert ist ─────────
        await waitForContent(4000)
        await new Promise<void>(resolve => setTimeout(resolve, 300))

        const { SplashScreen } = await import('@capacitor/splash-screen')
        if (!cancelled) {
          await SplashScreen.hide({ fadeOutDuration: 400 })
        }
      } catch {
        // Auf Web nicht verfügbar -> stillschweigend ignorieren
      }
    })()

    /**
     * "Predictive" Hardware-Back: priorisiert offene UI-Schichten vor der
     * Browser-History. Die einzelnen Komponenten markieren sich selbst per
     * `data-modal-open` / `data-sidebar-open` / `data-chat-back`.
     */
    function handleBackButton(e: Event): void {
      const modal = document.querySelector('[data-modal-open="true"]')
      if (modal) {
        e.preventDefault()
        modal.dispatchEvent(new CustomEvent('modal-close', { bubbles: true }))
        window.dispatchEvent(new CustomEvent('modal-close'))
        return
      }
      const sidebar = document.querySelector('[data-sidebar-open="true"]')
      if (sidebar) {
        e.preventDefault()
        sidebar.dispatchEvent(new CustomEvent('sidebar-close', { bubbles: true }))
        window.dispatchEvent(new CustomEvent('sidebar-close'))
        return
      }
      const chatBack = document.querySelector<HTMLElement>('[data-chat-back="true"]')
      if (chatBack) {
        e.preventDefault()
        chatBack.click()
        return
      }
      if (window.history.length > 1) {
        e.preventDefault()
        window.history.back()
        return
      }
      // Fallthrough → Default Capacitor (App minimieren).
    }
    document.addEventListener('backbutton', handleBackButton, false)

    return () => {
      cancelled = true
      document.removeEventListener('backbutton', handleBackButton, false)
      for (const fn of cleanups) {
        try { fn() } catch { /* ignore */ }
      }
    }
  }, [])

  return null
}
