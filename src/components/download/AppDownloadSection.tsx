'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import QRCode from 'qrcode'
import {
  APK_URL,
  APK_FILENAME,
  FDROID_DEEPLINK,
  FDROID_QR_CONTENT,
  FDROID_CLIENT_APK_URL,
} from '@/lib/app-download'
import DownloadProgressBar from './DownloadProgressBar'
import ConfettiEffect from './ConfettiEffect'

type Platform =
  | 'android'
  | 'ios'
  | 'desktop'
  | 'unknown'

type DownloadState =
  | 'idle'
  | 'connecting'
  | 'success'
  | 'no-fdroid'
  | 'downloading-fdroid'
  | 'downloading-apk'
  | 'apk-done'

function detectPlatform(): Platform {
  if (typeof navigator === 'undefined') return 'unknown'
  const ua = navigator.userAgent
  if (/Android/i.test(ua)) return 'android'
  if (/iPhone|iPad|iPod/i.test(ua)) return 'ios'
  return 'desktop'
}

export default function AppDownloadSection() {
  const [platform, setPlatform] = useState<Platform>('unknown')
  const [downloadState, setDownloadState] = useState<DownloadState>('idle')
  const [progress, setProgress] = useState(0)
  const [qrSvg, setQrSvg] = useState<string | null>(null)

  const connectingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const connectingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const apkIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const apkTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Plattform-Erkennung nach Hydration
  useEffect(() => {
    setPlatform(detectPlatform())
  }, [])

  // QR-Code client-seitig generieren (in ALL-CAPS für kompakteren Code)
  useEffect(() => {
    let cancelled = false
    QRCode.toString(FDROID_QR_CONTENT, {
      type: 'svg',
      margin: 1,
      width: 280,
      color: { dark: '#0E1A19', light: '#FFFFFF' },
      errorCorrectionLevel: 'H',
    })
      .then((svg) => {
        if (!cancelled) setQrSvg(svg)
      })
      .catch(() => {
        if (!cancelled) setQrSvg(null)
      })
    return () => {
      cancelled = true
    }
  }, [])

  // Cleanup Timer/Intervals bei Unmount
  useEffect(() => {
    return () => {
      if (connectingIntervalRef.current) clearInterval(connectingIntervalRef.current)
      if (connectingTimeoutRef.current) clearTimeout(connectingTimeoutRef.current)
      if (apkIntervalRef.current) clearInterval(apkIntervalRef.current)
      if (apkTimeoutRef.current) clearTimeout(apkTimeoutRef.current)
    }
  }, [])

  // ─── Handlers ─────────────────────────────────────────────────────────────
  const handleFdroidInstall = useCallback(() => {
    setDownloadState('connecting')
    setProgress(0)

    // Fake-Progress 0 → 30% über 1.5s
    connectingIntervalRef.current = setInterval(() => {
      setProgress((prev) => Math.min(prev + 2, 30))
    }, 100)

    // F-Droid Deep-Link triggern
    window.location.href = FDROID_DEEPLINK

    // Nach 1.5s prüfen: Tab versteckt → F-Droid geöffnet, sonst nicht installiert
    connectingTimeoutRef.current = setTimeout(() => {
      if (connectingIntervalRef.current) clearInterval(connectingIntervalRef.current)
      if (document.hidden) {
        setProgress(100)
        setDownloadState('success')
      } else {
        setProgress(0)
        setDownloadState('no-fdroid')
      }
    }, 1500)
  }, [])

  const handleFdroidDownload = useCallback(() => {
    setDownloadState('downloading-fdroid')
    window.location.href = FDROID_CLIENT_APK_URL
  }, [])

  const handleApkDownload = useCallback(() => {
    setDownloadState('downloading-apk')
    setProgress(0)

    // Unsichtbares <a download> programmatisch klicken
    const a = document.createElement('a')
    a.href = APK_URL
    a.download = APK_FILENAME
    a.rel = 'noopener'
    document.body.appendChild(a)
    a.click()
    a.remove()

    // Fake-Progress 0 → 90% über 3s (echte Download-Größe unbekannt)
    apkIntervalRef.current = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 90) {
          if (apkIntervalRef.current) clearInterval(apkIntervalRef.current)
          return 90
        }
        return prev + 3
      })
    }, 100)

    apkTimeoutRef.current = setTimeout(() => {
      if (apkIntervalRef.current) clearInterval(apkIntervalRef.current)
      setProgress(100)
      setDownloadState('apk-done')
    }, 3000)
  }, [])

  const handleReset = useCallback(() => {
    setDownloadState('idle')
    setProgress(0)
  }, [])

  // ─── Platform-spezifische Inhalte ─────────────────────────────────────────
  const isAndroid = platform === 'android'
  const isIos = platform === 'ios'
  const isDesktop = platform === 'desktop' || platform === 'unknown'

  const qrSize = isDesktop ? 280 : 180

  return (
    <section
      id="app-download"
      className="relative py-20 md:py-28 px-4 overflow-hidden cta-app-download"
      aria-labelledby="app-download-heading"
    >
      {/* Subtle gradient background (primary/teal instead of emerald) */}
      <div
        className="absolute inset-0 bg-gradient-to-br from-primary-50 via-warm-100 to-primary-100 -z-10"
        aria-hidden="true"
      />
      <div
        className="absolute inset-0 opacity-30 mix-blend-multiply -z-10"
        style={{
          backgroundImage:
            'radial-gradient(circle at 20% 10%, rgba(30,170,166,0.18) 0%, transparent 50%), ' +
            'radial-gradient(circle at 80% 90%, rgba(30,170,166,0.12) 0%, transparent 50%)',
        }}
        aria-hidden="true"
      />

      <div className="relative max-w-4xl mx-auto">
        <div className="bg-white/90 backdrop-blur-md rounded-3xl shadow-card border border-primary-100/60 overflow-hidden">
          {/* Header with floating smartphone icon */}
          <div className="text-center pt-10 md:pt-14 px-6 md:px-10">
            <div
              className="inline-flex items-center justify-center w-20 h-20 rounded-3xl bg-gradient-to-br from-primary-500 to-primary-700 text-white shadow-glow-teal mb-6 animate-float"
              aria-hidden="true"
            >
              <SmartphoneIcon />
            </div>

            <h2
              id="app-download-heading"
              className="font-display text-3xl md:text-5xl font-medium tracking-tight bg-gradient-to-r from-primary-700 via-primary-600 to-primary-500 bg-clip-text text-transparent"
            >
              Mensaena App herunterladen
            </h2>
            <p className="mt-4 text-ink-500 text-base md:text-lg max-w-md mx-auto">
              Ein Tipp. Automatisch. Ohne Kopieren.
            </p>
          </div>

          {/* Platform-specific content */}
          <div className="p-6 md:p-10">
            {isIos && <IosView qrSvg={qrSvg} qrSize={qrSize} />}
            {isAndroid && (
              <AndroidView
                qrSvg={qrSvg}
                qrSize={qrSize}
                downloadState={downloadState}
                progress={progress}
                onFdroidInstall={handleFdroidInstall}
                onFdroidDownload={handleFdroidDownload}
                onApkDownload={handleApkDownload}
                onReset={handleReset}
              />
            )}
            {isDesktop && (
              <DesktopView
                qrSvg={qrSvg}
                qrSize={qrSize}
                downloadState={downloadState}
                progress={progress}
                onApkDownload={handleApkDownload}
                onReset={handleReset}
              />
            )}

            {/* "So funktioniert's" - gemeinsam für alle Plattformen */}
            <HowItWorksAccordion />
          </div>
        </div>
      </div>

      <ConfettiEffect active={downloadState === 'success'} />
    </section>
  )
}

// ─── Sub-components ─────────────────────────────────────────────────────────

function SmartphoneIcon() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="w-10 h-10"
      aria-hidden="true"
    >
      <rect x="6" y="2" width="12" height="20" rx="2.5" ry="2.5" />
      <line x1="11" y1="18" x2="13" y2="18" />
    </svg>
  )
}

function AndroidRobotIcon({ className = 'w-5 h-5' }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      className={className}
      aria-hidden="true"
    >
      <path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24c-2.86-1.21-6.08-1.21-8.94 0L5.65 5.67c-.19-.29-.58-.38-.87-.2-.28.18-.37.54-.22.83L6.4 9.48C3.3 11.25 1.28 14.44 1 18h22c-.28-3.56-2.3-6.75-5.4-8.52zM7 15.25a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm10 0a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5z" />
    </svg>
  )
}

function QrCodeFrame({ qrSvg, size }: { qrSvg: string | null; size: number }) {
  return (
    <div className="flex flex-col items-center">
      <div
        className="bg-white rounded-2xl border-2 border-primary-200 p-4 shadow-soft flex items-center justify-center"
        style={{ width: size, height: size }}
      >
        {qrSvg ? (
          <div
            role="img"
            aria-label="QR-Code zum F-Droid-Repository von Mensaena"
            className="w-full h-full"
            dangerouslySetInnerHTML={{ __html: qrSvg }}
          />
        ) : (
          <div className="w-full h-full bg-stone-100 rounded-lg animate-pulse" />
        )}
      </div>
      <p className="text-xs text-ink-500 mt-3 text-center max-w-[220px]">
        Scanne mit deinem Handy
      </p>
    </div>
  )
}

// ─── Android View ───────────────────────────────────────────────────────────
function AndroidView({
  qrSvg,
  qrSize,
  downloadState,
  progress,
  onFdroidInstall,
  onFdroidDownload,
  onApkDownload,
  onReset,
}: {
  qrSvg: string | null
  qrSize: number
  downloadState: DownloadState
  progress: number
  onFdroidInstall: () => void
  onFdroidDownload: () => void
  onApkDownload: () => void
  onReset: () => void
}) {
  const isConnecting = downloadState === 'connecting'
  const isSuccess = downloadState === 'success'
  const isNoFdroid = downloadState === 'no-fdroid'
  const isDownloadingFdroid = downloadState === 'downloading-fdroid'
  const isDownloadingApk = downloadState === 'downloading-apk'
  const isApkDone = downloadState === 'apk-done'
  const isButtonBusy = isConnecting || isDownloadingFdroid || isDownloadingApk

  return (
    <div className="space-y-8">
      {/* Main F-Droid install button */}
      <div className="flex flex-col items-center gap-5">
        {downloadState === 'idle' && (
          <button
            onClick={onFdroidInstall}
            className="group w-full sm:w-auto inline-flex items-center justify-center gap-3 px-8 py-4 rounded-full bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-700 hover:to-primary-600 text-white text-base font-semibold shadow-glow-teal transition-all duration-300 hover:scale-105 active:scale-95"
            aria-label="App mit F-Droid installieren"
          >
            <AndroidRobotIcon className="w-5 h-5" />
            App mit F-Droid installieren
          </button>
        )}

        {isConnecting && (
          <div className="w-full max-w-md">
            <DownloadProgressBar
              progress={progress}
              status="loading"
              label="Verbinde mit F-Droid..."
              sublabel="F-Droid-App wird geöffnet"
            />
          </div>
        )}

        {isSuccess && (
          <div className="w-full max-w-md animate-bounce-in">
            <DownloadProgressBar
              progress={100}
              status="success"
              label="F-Droid wurde geöffnet! ✓"
              sublabel="Tippe dort auf 'Installieren' – fertig!"
            />
            <button
              onClick={onReset}
              className="mt-4 w-full text-sm text-primary-700 hover:text-primary-800 underline"
            >
              Erneut öffnen
            </button>
          </div>
        )}

        {isNoFdroid && (
          <div className="w-full max-w-md space-y-4 animate-fade-in">
            <DownloadProgressBar
              progress={100}
              status="error"
              label="F-Droid ist noch nicht installiert"
              sublabel="Lade F-Droid jetzt herunter, dann tippe erneut auf den grünen Button."
            />
            <button
              onClick={onFdroidDownload}
              className="w-full inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full bg-amber-600 hover:bg-amber-700 text-white text-sm font-semibold transition-all duration-300 hover:scale-[1.02] active:scale-95"
            >
              <DownloadIcon className="w-4 h-4" />
              F-Droid jetzt herunterladen
            </button>
            <p className="text-xs text-ink-500 text-center">
              Danach tippe erneut auf den grünen Button oben
            </p>
            <button
              onClick={onReset}
              className="w-full text-xs text-ink-400 hover:text-ink-700 underline"
            >
              Abbrechen
            </button>
          </div>
        )}

        {isDownloadingFdroid && (
          <div className="w-full max-w-md">
            <DownloadProgressBar
              progress={50}
              status="loading"
              label="F-Droid wird heruntergeladen..."
              sublabel="Installiere F-Droid, dann komm zurück"
            />
          </div>
        )}

        {isDownloadingApk && (
          <div className="w-full max-w-md">
            <div className="flex items-center justify-center mb-3">
              <ArrowDownIcon className="w-6 h-6 text-primary-600 animate-arrow-bounce" />
            </div>
            <DownloadProgressBar
              progress={progress}
              status="loading"
              label="Mensaena wird heruntergeladen..."
              sublabel="Eventuell musst du 'Aus unbekannten Quellen installieren' erlauben"
            />
          </div>
        )}

        {isApkDone && (
          <div className="w-full max-w-md animate-bounce-in">
            <DownloadProgressBar
              progress={100}
              status="success"
              label="Download gestartet! ✓"
              sublabel="Öffne die Datei in deinen Downloads, um zu installieren"
            />
            <button
              onClick={onReset}
              className="mt-4 w-full text-sm text-primary-700 hover:text-primary-800 underline"
            >
              Zurück
            </button>
          </div>
        )}
      </div>

      {/* QR code + direct APK link (always visible) */}
      {!isButtonBusy && (
        <div className="grid sm:grid-cols-[auto_1fr] gap-6 items-center pt-6 border-t border-stone-200">
          <QrCodeFrame qrSvg={qrSvg} size={qrSize} />
          <div className="text-center sm:text-left space-y-2">
            <p className="text-xs font-semibold text-ink-400 uppercase tracking-wider">
              Oder alternativ
            </p>
            <p className="text-sm text-ink-700">
              QR-Code scannen oder APK direkt laden
            </p>
            <button
              onClick={onApkDownload}
              className="text-sm text-primary-700 hover:text-primary-800 underline underline-offset-4"
            >
              APK direkt herunterladen
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── iOS View ───────────────────────────────────────────────────────────────
function IosView({ qrSvg, qrSize }: { qrSvg: string | null; qrSize: number }) {
  return (
    <div className="space-y-6">
      <div className="bg-trust-50 border border-trust-200 rounded-2xl p-6 text-center">
        <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-trust-100 text-trust-500 mb-3" aria-hidden="true">
          ℹ️
        </div>
        <h3 className="font-display text-xl text-ink-800 mb-2">
          Mensaena ist aktuell nur für Android verfügbar
        </h3>
        <p className="text-sm text-ink-500 max-w-md mx-auto">
          Du kannst Mensaena aber jetzt schon als Web-App auf deinem Startbildschirm
          nutzen – ganz ohne App-Store.
        </p>
      </div>

      <details className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <summary className="cursor-pointer flex items-center justify-between px-5 py-4 hover:bg-stone-50 transition-colors">
          <span className="text-sm font-semibold text-ink-700">
            Als Web-App hinzufügen
          </span>
          <span className="text-ink-400" aria-hidden="true">▾</span>
        </summary>
        <ol className="px-5 pb-5 pt-2 space-y-2 text-sm text-ink-700 list-decimal list-inside">
          <li>Tippe unten im Browser auf <strong>Teilen</strong> (Quadrat mit Pfeil)</li>
          <li>Scrolle und wähle <strong>„Zum Home-Bildschirm"</strong></li>
          <li>Bestätige mit <strong>„Hinzufügen"</strong> – fertig!</li>
        </ol>
      </details>

      <div className="pt-6 border-t border-stone-200 text-center space-y-4">
        <p className="text-sm text-ink-500">
          Hast du auch ein Android-Gerät? Scanne den Code dort:
        </p>
        <div className="flex justify-center">
          <QrCodeFrame qrSvg={qrSvg} size={qrSize} />
        </div>
      </div>
    </div>
  )
}

// ─── Desktop View ───────────────────────────────────────────────────────────
function DesktopView({
  qrSvg,
  qrSize,
  downloadState,
  progress,
  onApkDownload,
  onReset,
}: {
  qrSvg: string | null
  qrSize: number
  downloadState: DownloadState
  progress: number
  onApkDownload: () => void
  onReset: () => void
}) {
  const isDownloadingApk = downloadState === 'downloading-apk'
  const isApkDone = downloadState === 'apk-done'

  return (
    <div className="space-y-8">
      <div className="flex flex-col items-center gap-5">
        <QrCodeFrame qrSvg={qrSvg} size={qrSize} />
        <div className="text-center max-w-sm">
          <p className="text-lg font-medium text-ink-800">
            Scanne diesen Code mit deinem Android-Handy
          </p>
          <p className="text-sm text-ink-500 mt-2">
            F-Droid öffnet sich automatisch mit vorausgefülltem Repo –
            du musst nichts kopieren.
          </p>
        </div>
      </div>

      <div className="pt-6 border-t border-stone-200 text-center space-y-3">
        {downloadState === 'idle' && (
          <>
            <p className="text-xs font-semibold text-ink-400 uppercase tracking-wider">
              Oder
            </p>
            <button
              onClick={onApkDownload}
              className="text-sm text-primary-700 hover:text-primary-800 underline underline-offset-4 inline-flex items-center gap-2"
            >
              <DownloadIcon className="w-4 h-4" />
              APK direkt herunterladen
            </button>
            <p className="text-xs text-ink-400 max-w-sm mx-auto">
              Nur empfohlen, wenn du genau weißt, was du tust. Empfehlung: QR-Code scannen.
            </p>
          </>
        )}

        {isDownloadingApk && (
          <div className="w-full max-w-md mx-auto">
            <div className="flex items-center justify-center mb-3">
              <ArrowDownIcon className="w-6 h-6 text-primary-600 animate-arrow-bounce" />
            </div>
            <DownloadProgressBar
              progress={progress}
              status="loading"
              label="Mensaena wird heruntergeladen..."
            />
          </div>
        )}

        {isApkDone && (
          <div className="w-full max-w-md mx-auto animate-bounce-in">
            <DownloadProgressBar
              progress={100}
              status="success"
              label="Download gestartet! ✓"
              sublabel="Öffne die Datei, um zu installieren"
            />
            <button
              onClick={onReset}
              className="mt-4 text-sm text-primary-700 hover:text-primary-800 underline"
            >
              Zurück
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

// ─── How it works accordion ────────────────────────────────────────────────
function HowItWorksAccordion() {
  return (
    <details className="mt-8 group">
      <summary className="cursor-pointer flex items-center justify-between gap-3 px-5 py-4 bg-stone-50 hover:bg-stone-100 rounded-xl transition-colors">
        <span className="font-semibold text-ink-700 text-sm">
          So funktioniert's
        </span>
        <span
          className="text-ink-400 transition-transform group-open:rotate-180"
          aria-hidden="true"
        >
          ▾
        </span>
      </summary>
      <ol className="mt-4 px-5 py-4 bg-white border border-stone-200 rounded-xl space-y-4 text-sm text-ink-700">
        <Step n={1} title="Tippe auf den Button oder scanne den QR-Code">
          Dein Handy erkennt automatisch, dass du F-Droid verwenden möchtest.
        </Step>
        <Step n={2} title="F-Droid öffnet sich mit dem Mensaena-Repo">
          Bestätige einmalig mit &quot;OK&quot; – das Repository wird hinzugefügt.
        </Step>
        <Step n={3} title="Installieren tippen – fertig!">
          Mensaena landet in deinem App-Drawer und bekommt automatisch Updates.
        </Step>
      </ol>
    </details>
  )
}

function Step({
  n,
  title,
  children,
}: {
  n: number
  title: string
  children: React.ReactNode
}) {
  return (
    <li className="flex gap-3">
      <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">
        {n}
      </span>
      <div className="flex-1">
        <div className="font-semibold text-ink-800">{title}</div>
        <div className="text-ink-500 text-xs mt-1">{children}</div>
      </div>
    </li>
  )
}

// ─── Small icon components ─────────────────────────────────────────────────
function DownloadIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  )
}

function ArrowDownIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <line x1="12" y1="5" x2="12" y2="19" />
      <polyline points="19 12 12 19 5 12" />
    </svg>
  )
}
