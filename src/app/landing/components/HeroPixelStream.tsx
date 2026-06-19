'use client'

import { useCallback, useEffect, useRef, useState } from 'react'

/**
 * HeroPixelStream — Unreal-Engine-Pixel-Streaming für die Landing/Hero.
 *
 * Bewusst iframe-basiert: der schwere WebRTC-Player wird vom Signalling-/GPU-
 * Server ausgeliefert (Epic "Pixel Streaming Infrastructure"), NICHT in die
 * Marketing-Seite gebündelt → kein Cloudflare/OpenNext-Build-Risiko, keine
 * neue npm-Dependency. Setup-Anleitung: docs/PIXEL_STREAMING.md
 *
 * Kostenlogik: Eine GPU-Session ist teuer und pro gleichzeitigem Nutzer
 * gebunden. Deshalb startet der Stream NIE automatisch — erst auf Klick
 * ("3D live erleben") und endet beim Schließen wieder, damit die GPU frei wird.
 *
 * Aktivierung: NEXT_PUBLIC_PIXELSTREAM_URL auf die Player-URL des Signalling-
 * Servers setzen (z. B. https://stream.mensaena.de). Ohne diese Variable
 * rendert die Komponente nichts → der bestehende Cinematic-Hero bleibt.
 */

const STREAM_URL = process.env.NEXT_PUBLIC_PIXELSTREAM_URL?.trim() || ''

type Phase = 'idle' | 'connecting' | 'live' | 'error'

/** Nur auf Geräten anbieten, die ein flüssiges WebRTC-3D-Erlebnis tragen. */
function deviceCanStream(): boolean {
  if (typeof window === 'undefined') return false
  // WebRTC vorhanden?
  if (typeof window.RTCPeerConnection === 'undefined') return false
  // Reduzierte Bewegung respektieren
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return false
  // Datensparmodus respektieren
  const conn = (navigator as unknown as { connection?: { saveData?: boolean } }).connection
  if (conn?.saveData) return false
  // Grobe Zeiger (Touch-only) → eher Mobil, Pixel-Streaming lohnt selten
  const coarseOnly =
    window.matchMedia?.('(pointer: coarse)').matches &&
    !window.matchMedia?.('(pointer: fine)').matches
  if (coarseOnly) return false
  // Genug Platz für ein Erlebnis
  if (window.innerWidth < 900) return false
  return true
}

export default function HeroPixelStream() {
  const [supported, setSupported] = useState(false)
  const [open, setOpen] = useState(false)
  const [phase, setPhase] = useState<Phase>('idle')
  const loadTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (!STREAM_URL) return
    setSupported(deviceCanStream())
  }, [])

  const close = useCallback(() => {
    if (loadTimer.current) clearTimeout(loadTimer.current)
    loadTimer.current = null
    setOpen(false)
    setPhase('idle')
  }, [])

  const start = useCallback(() => {
    setOpen(true)
    setPhase('connecting')
    // Sicherheitsnetz: bleibt der Player zu lange stumm, Fehlerhinweis zeigen.
    if (loadTimer.current) clearTimeout(loadTimer.current)
    loadTimer.current = setTimeout(() => {
      setPhase((p) => (p === 'connecting' ? 'error' : p))
    }, 25000)
  }, [])

  // ESC schließt das Overlay
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    // Scroll der Seite sperren, solange der Stream offen ist
    const prevOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prevOverflow
    }
  }, [open, close])

  // Wird der iframe geladen → "live" (der Player baut dann selbst WebRTC auf)
  const onFrameLoad = useCallback(() => {
    if (loadTimer.current) clearTimeout(loadTimer.current)
    loadTimer.current = null
    setPhase('live')
  }, [])

  if (!STREAM_URL || !supported) return null

  return (
    <>
      <button type="button" className="cin-btn ghost cin-ps-trigger" onClick={start}>
        <span className="cin-ps-dot" aria-hidden="true" />
        3D live erleben
      </button>

      {open && (
        <div
          className="cin-ps-overlay"
          role="dialog"
          aria-modal="true"
          aria-label="Mensaena in 3D — Unreal Engine Live-Stream"
        >
          <div className="cin-ps-stage">
            <iframe
              key={STREAM_URL}
              className="cin-ps-frame"
              src={STREAM_URL}
              title="Mensaena 3D (Unreal Engine Pixel Streaming)"
              onLoad={onFrameLoad}
              allow="autoplay; fullscreen; gamepad; xr-spatial-tracking; clipboard-write"
              sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-fullscreen"
            />

            {phase !== 'live' && (
              <div className="cin-ps-state" aria-live="polite">
                {phase === 'error' ? (
                  <>
                    <p className="cin-ps-state-title">Stream gerade nicht verfügbar</p>
                    <p className="cin-ps-state-sub">
                      Alle 3D-Plätze sind belegt oder der Render-Server ist offline.
                      Bitte später erneut versuchen.
                    </p>
                    <button type="button" className="cin-btn ghost" onClick={close}>
                      Schließen
                    </button>
                  </>
                ) : (
                  <>
                    <span className="cin-ps-spinner" aria-hidden="true" />
                    <p className="cin-ps-state-title">Verbinde mit dem Render-Server …</p>
                    <p className="cin-ps-state-sub">Hyperrealistische 3D-Welt wird gestreamt</p>
                  </>
                )}
              </div>
            )}

            <button
              type="button"
              className="cin-ps-close"
              onClick={close}
              aria-label="3D-Stream schließen"
            >
              ✕ Schließen
            </button>
            <div className="cin-ps-badge" aria-hidden="true">
              <span className="cin-ps-dot live" /> LIVE · Unreal Engine
            </div>
          </div>
        </div>
      )}
    </>
  )
}
