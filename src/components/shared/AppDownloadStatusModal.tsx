'use client'

import { useEffect, useState } from 'react'
import { X, Download, CheckCircle2 } from 'lucide-react'
import { APK_URL, APK_FILENAME, MOTIVATIONAL_MESSAGES } from '@/lib/app-download'

const ROTATION_MS = 3200

type Props = {
  onClose: () => void
}

// Vollbild-Overlay, das nach einem Klick auf den Download-Button angezeigt wird.
// Rotiert alle paar Sekunden motivierende Sätze durch, zeigt Install-Schritte
// und bietet einen Fallback-Link falls der Browser-Download nicht startet.
// Schließt sich nicht automatisch – der Nutzer entscheidet.
export default function AppDownloadStatusModal({ onClose }: Props) {
  const [messageIndex, setMessageIndex] = useState(0)
  const [fade, setFade] = useState(true)
  const [downloadStarted, setDownloadStarted] = useState(false)

  // Rotation der Motivationssätze mit sanftem Fade-Effekt
  useEffect(() => {
    const id = setInterval(() => {
      setFade(false)
      // Nach kurzer Fade-Out-Pause zum nächsten Satz wechseln + fade-in
      setTimeout(() => {
        setMessageIndex((i) => (i + 1) % MOTIVATIONAL_MESSAGES.length)
        setFade(true)
      }, 250)
    }, ROTATION_MS)
    return () => clearInterval(id)
  }, [])

  // ESC schließt das Modal
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  // Body-Scroll sperren, solange Modal offen ist
  useEffect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [])

  const currentMessage = MOTIVATIONAL_MESSAGES[messageIndex]

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="app-download-status-title"
      className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-ink-900/70 backdrop-blur-sm animate-fade-in"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-md bg-mn-elevated rounded-3xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close */}
        <button
          type="button"
          onClick={onClose}
          aria-label="Schließen"
          className="absolute top-4 right-4 z-10 w-9 h-9 flex items-center justify-center rounded-full hover:bg-mn-elevated/5 text-mn-mute"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Top: gradient header */}
        <div className="bg-gradient-to-br from-primary-600 to-mn-teal-soft/8 text-white px-8 pt-10 pb-8 text-center">
          <div className="relative inline-flex items-center justify-center mb-4">
            <span className="absolute inset-0 rounded-full bg-mn-elevated/30 animate-ping" aria-hidden="true" />
            <span className="relative w-16 h-16 rounded-full bg-mn-elevated/20 flex items-center justify-center">
              <Download className="w-8 h-8" aria-hidden="true" />
            </span>
          </div>
          <h2
            id="app-download-status-title"
            className="text-2xl font-bold tracking-tight"
          >
            Download läuft …
          </h2>
          <p className="text-white/80 text-sm mt-1">{APK_FILENAME}</p>
        </div>

        {/* Rotating motivational message */}
        <div
          aria-live="polite"
          className="px-8 py-7 min-h-[84px] flex items-center justify-center text-center bg-mn-bronze/5/60"
        >
          <p
            className={`text-base sm:text-lg font-medium text-primary-900 transition-opacity duration-200 ${fade ? 'opacity-100' : 'opacity-0'}`}
          >
            {currentMessage}
          </p>
        </div>

        {/* Install steps */}
        <div className="px-8 py-6">
          {/* Chrome download bar mockup – animated hint */}
          <div className="mb-5 rounded-2xl overflow-hidden border border-white/5 shadow-sm">
            {/* Bar label */}
            <div className="bg-mn-elevated px-3 py-1.5 flex items-center gap-2 border-b border-white/5">
              <div className="flex gap-1">
                <span className="w-2.5 h-2.5 rounded-full bg-red-400" />
                <span className="w-2.5 h-2.5 rounded-full bg-yellow-400" />
                <span className="w-2.5 h-2.5 rounded-full bg-green-400" />
              </div>
              <span className="text-[10px] text-mn-mute font-medium tracking-wide">Chrome Download-Leiste</span>
            </div>
            {/* Simulated download bar at bottom */}
            <div className="bg-[#3c4043] px-4 py-2.5 flex items-center gap-3">
              <div className="flex-1 min-w-0">
                <p className="text-[11px] text-white/90 font-medium truncate">{APK_FILENAME}</p>
                <div className="mt-1 h-1 bg-mn-elevated/20 rounded-full overflow-hidden">
                  <div className="h-full bg-[#8ab4f8] rounded-full animate-[downloadBar_2s_ease-in-out_infinite]" style={{ width: '100%', transformOrigin: 'left' }} />
                </div>
              </div>
              {/* Pulsing "Öffnen" button */}
              <button
                type="button"
                tabIndex={-1}
                aria-hidden="true"
                className="flex-shrink-0 px-3 py-1.5 bg-[#8ab4f8] text-[#202124] text-xs font-bold rounded animate-pulse"
              >
                Öffnen
              </button>
            </div>
            <div className="bg-mn-bronze/5 px-4 py-2.5 flex items-center gap-2">
              <span className="text-mn-bronze text-base leading-none" aria-hidden="true">👆</span>
              <p className="text-xs text-primary-800 font-semibold">
                Tippe unten auf <strong>„Öffnen"</strong> sobald der Download fertig ist
              </p>
            </div>
          </div>

          {/* Unbekannte Quellen Hinweis */}
          <div className="mb-5 flex gap-3 rounded-2xl bg-amber-50 border border-amber-200 px-4 py-3">
            <span className="text-amber-500 text-lg leading-none mt-0.5" aria-hidden="true">⚠️</span>
            <p className="text-xs text-amber-800 leading-relaxed">
              <strong>Kurzer Hinweis:</strong> Android fragt beim ersten Mal nach der Erlaubnis,
              Apps aus unbekannten Quellen zu installieren. Einfach <strong>„Erlauben"</strong> tippen –
              das ist normal und sicher.
            </p>
          </div>

          <h3 className="text-sm font-semibold text-mn-ink mb-4">
            So geht&apos;s weiter:
          </h3>
          <ol className="space-y-3">
            <StepItem number={1} done={downloadStarted}>
              APK wird heruntergeladen
            </StepItem>
            <StepItem number={2}>
              Unten in der Leiste auf <strong>„Öffnen"</strong> tippen
            </StepItem>
            <StepItem number={3}>
              Bei Nachfrage <q>Aus dieser Quelle erlauben</q> antippen
            </StepItem>
            <StepItem number={4}>
              <q>Installieren</q> bestätigen – fertig!
            </StepItem>
          </ol>

          <div className="mt-6 flex flex-col gap-2">
            <button
              type="button"
              onClick={onClose}
              className="btn-primary w-full py-3"
            >
              Alles klar
            </button>
            <a
              href={APK_URL}
              download={APK_FILENAME}
              rel="noopener"
              className="text-center text-xs text-mn-mute hover:text-mn-bronze underline py-2"
              onClick={() => setDownloadStarted(true)}
            >
              Download startet nicht? APK direkt laden
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}

type StepProps = { number: number; done?: boolean; children: React.ReactNode }
function StepItem({ number, done, children }: StepProps) {
  return (
    <li className="flex items-start gap-3">
      <span
        className={`flex-shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${
          done
            ? 'bg-mn-bronze text-white'
            : 'bg-mn-elevated text-mn-mute'
        }`}
        aria-hidden="true"
      >
        {done ? <CheckCircle2 className="w-4 h-4" /> : number}
      </span>
      <span className="text-sm text-mn-ink-soft leading-relaxed pt-0.5">
        {children}
      </span>
    </li>
  )
}
