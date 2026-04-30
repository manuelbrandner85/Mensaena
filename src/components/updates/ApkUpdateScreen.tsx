'use client'

// UPDATE-SYSTEM: Vollbild-Sperre für Pflicht-APK-Update – KEIN Schließen möglich
import { useEffect, useState } from 'react'
import Image from 'next/image'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import type { ApkReleaseNotes } from '@/hooks/useAppUpdate'

interface ApkUpdateScreenProps {
  apkReleaseNotes: ApkReleaseNotes
  newApkVersion: string
  currentApkVersion: string | null
  apkSize: string
  isDownloading: boolean
  downloadProgress: number
  onDownload: () => void
}

export default function ApkUpdateScreen({
  apkReleaseNotes,
  newApkVersion,
  currentApkVersion,
  apkSize,
  isDownloading,
  downloadProgress,
  onDownload,
}: ApkUpdateScreenProps) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const t = setTimeout(() => setVisible(true), 30)
    return () => clearTimeout(t)
  }, [])

  // Android Back-Button abfangen – App ist gesperrt
  useEffect(() => {
    const handleBackButton = (e: Event) => {
      e.preventDefault()
      e.stopPropagation()
    }
    document.addEventListener('backbutton', handleBackButton)

    let listenerHandle: { remove: () => void } | null = null
    if (Capacitor.isNativePlatform()) {
      App.addListener('backButton', () => {
        // Bewusst nichts tun – App ist gesperrt
      }).then((handle) => {
        listenerHandle = handle
      })
    }

    return () => {
      document.removeEventListener('backbutton', handleBackButton)
      listenerHandle?.remove()
    }
  }, [])

  const downloadDone = isDownloading && downloadProgress >= 100

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Pflicht-App-Update erforderlich"
      aria-live="assertive"
      className={[
        'fixed inset-0 z-[9999] overflow-y-auto',
        'bg-gradient-to-b from-[#EEF9F9] via-white to-[#EEF9F9]',
        'dark:from-stone-900 dark:via-stone-950 dark:to-stone-900',
        'transition-opacity duration-500',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      <div className="min-h-full flex flex-col items-center justify-start px-6 py-8 gap-5 max-w-md mx-auto">

        {/* Pflichtupdate-Banner */}
        <div
          className={[
            'w-full bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700',
            'rounded-xl p-3 transition-all duration-500 delay-0',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-2',
          ].join(' ')}
        >
          <p className="text-amber-800 dark:text-amber-300 text-sm font-medium text-center">
            ⚠️ Pflichtupdate — Bitte aktualisiere die App um Mensaena weiter nutzen zu können.
          </p>
        </div>

        {/* Logo mit Animationsring */}
        <div
          className={[
            'relative transition-all duration-500 delay-[50ms]',
            visible ? 'opacity-100 scale-100' : 'opacity-0 scale-90',
          ].join(' ')}
        >
          <div className="relative w-20 h-20">
            {/* Animierter Ring */}
            <div
              className="absolute inset-[-6px] rounded-full border-4 border-primary-200 dark:border-primary-800 border-t-primary-500 animate-spin"
              aria-hidden="true"
            />
            <div className="w-20 h-20 rounded-2xl ring-2 ring-primary-200 dark:ring-primary-800 overflow-hidden relative">
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                fill
                className="object-cover"
                priority
              />
            </div>
            {/* Download-Overlay-Icon */}
            <div
              className="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-primary-500 flex items-center justify-center shadow-md"
              aria-hidden="true"
            >
              <svg className="w-3.5 h-3.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          </div>
        </div>

        {/* Headline */}
        <div
          className={[
            'text-center transition-all duration-500 delay-100',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          <h1 className="text-2xl font-display font-bold text-ink-900 dark:text-stone-100 mb-1">
            📦 {apkReleaseNotes.headline}
          </h1>
          <p className="text-base text-ink-500 dark:text-stone-400">
            {apkReleaseNotes.subtitle}
          </p>
        </div>

        {/* Reason-Box */}
        <div
          className={[
            'w-full bg-primary-50 dark:bg-primary-900/20 rounded-2xl p-5',
            'transition-all duration-500 delay-[150ms]',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          <p className="text-sm text-ink-700 dark:text-primary-200 leading-relaxed">
            {apkReleaseNotes.reason}
          </p>
        </div>

        {/* Schritt-für-Schritt */}
        <div
          className={[
            'w-full transition-all duration-500 delay-200',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          <p className="text-sm font-semibold text-ink-700 dark:text-stone-300 mb-3">
            So einfach geht&rsquo;s:
          </p>
          <ol className="flex flex-col gap-2.5">
            {apkReleaseNotes.steps.map((step, idx) => (
              <li
                key={idx}
                className={[
                  'flex items-center gap-3 transition-all duration-500',
                  visible ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-3',
                ].join(' ')}
                style={{ transitionDelay: `${250 + idx * 60}ms` }}
              >
                <span
                  className="w-7 h-7 rounded-full bg-primary-100 dark:bg-primary-900/40 text-primary-700 dark:text-primary-300 font-bold text-sm flex items-center justify-center flex-shrink-0"
                  aria-hidden="true"
                >
                  {idx + 1}
                </span>
                <span className="text-sm text-ink-600 dark:text-stone-300">{step}</span>
              </li>
            ))}
          </ol>
        </div>

        {/* Datenschutz-Footer */}
        <div
          className={[
            'w-full bg-green-50 dark:bg-green-900/20 rounded-xl p-3',
            'transition-all duration-500 delay-[400ms]',
            visible ? 'opacity-100' : 'opacity-0',
          ].join(' ')}
        >
          <p className="text-green-700 dark:text-green-300 text-sm font-medium text-center">
            {apkReleaseNotes.footer}
          </p>
        </div>

        {/* Download-Button / Fortschritt */}
        <div
          className={[
            'w-full transition-all duration-500 delay-[500ms]',
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-3',
          ].join(' ')}
        >
          {!isDownloading ? (
            /* Zustand 1: Vor Download */
            <button
              onClick={onDownload}
              className={[
                'w-full py-4 rounded-2xl text-white font-bold shadow-glow text-lg',
                'bg-gradient-to-r from-primary-500 to-primary-600',
                'hover:scale-[1.02] active:scale-[0.98] transition-transform duration-150',
                'focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-400',
              ].join(' ')}
            >
              <span>📥 Jetzt herunterladen</span>
              <span className="block text-xs font-normal opacity-80 mt-0.5">
                {apkSize} · Version {newApkVersion}
              </span>
            </button>
          ) : downloadDone ? (
            /* Zustand 3: Fertig */
            <div className="w-full py-4 rounded-2xl bg-green-500 text-white font-bold text-center animate-pulse">
              <p>✅ Download abgeschlossen!</p>
              <p className="text-sm font-normal mt-1 opacity-90">
                Öffne die heruntergeladene Datei um zu installieren
              </p>
            </div>
          ) : (
            /* Zustand 2: Downloading */
            <div className="w-full h-16 bg-stone-100 dark:bg-stone-800 rounded-2xl overflow-hidden relative">
              <div
                className="absolute inset-y-0 left-0 bg-gradient-to-r from-primary-400 to-primary-500 transition-all duration-300 rounded-l-2xl"
                style={{ width: `${downloadProgress}%` }}
                role="progressbar"
                aria-valuenow={downloadProgress}
                aria-valuemin={0}
                aria-valuemax={100}
              />
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-sm font-bold text-ink-800 dark:text-stone-100 relative z-10">
                  {downloadProgress}%
                </span>
                <span className="text-xs text-ink-500 dark:text-stone-400 relative z-10">
                  Wird heruntergeladen…
                </span>
              </div>
            </div>
          )}

          {/* Versions-Info unter dem Button */}
          {currentApkVersion && (
            <p className="text-xs text-ink-400 dark:text-stone-500 text-center mt-2">
              v{currentApkVersion} → v{newApkVersion}
            </p>
          )}
        </div>

      </div>
    </div>
  )
}
