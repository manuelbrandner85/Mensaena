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
        className="relative w-full max-w-md bg-white rounded-3xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close */}
        <button
          type="button"
          onClick={onClose}
          aria-label="Schließen"
          className="absolute top-4 right-4 z-10 w-9 h-9 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-500"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Top: gradient header */}
        <div className="bg-gradient-to-br from-primary-600 to-teal-700 text-white px-8 pt-10 pb-8 text-center">
          <div className="relative inline-flex items-center justify-center mb-4">
            <span className="absolute inset-0 rounded-full bg-white/30 animate-ping" aria-hidden="true" />
            <span className="relative w-16 h-16 rounded-full bg-white/20 flex items-center justify-center">
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
          className="px-8 py-7 min-h-[84px] flex items-center justify-center text-center bg-primary-50/60"
        >
          <p
            className={`text-base sm:text-lg font-medium text-primary-900 transition-opacity duration-200 ${fade ? 'opacity-100' : 'opacity-0'}`}
          >
            {currentMessage}
          </p>
        </div>

        {/* Install steps */}
        <div className="px-8 py-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">
            So geht&apos;s weiter:
          </h3>
          <ol className="space-y-3">
            <StepItem number={1} done>
              APK wird heruntergeladen
            </StepItem>
            <StepItem number={2}>
              In den Downloads auf <em>{APK_FILENAME}</em> tippen
            </StepItem>
            <StepItem number={3}>
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
              className="text-center text-xs text-gray-500 hover:text-primary-700 underline py-2"
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
            ? 'bg-primary-600 text-white'
            : 'bg-gray-100 text-gray-500'
        }`}
        aria-hidden="true"
      >
        {done ? <CheckCircle2 className="w-4 h-4" /> : number}
      </span>
      <span className="text-sm text-gray-700 leading-relaxed pt-0.5">
        {children}
      </span>
    </li>
  )
}
