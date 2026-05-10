'use client'
// v2 – re-deploy trigger
// WICHTIG: Diese Seite ist bewusst als komplett CLIENT Component implementiert.
//
// Grund: Server Components lösen im Cloudflare Workers Runtime oft
// BAILOUT_TO_CLIENT_SIDE_RENDERING aus (Root Layout nutzt next-intl/server,
// dadurch rendert der Server für /app nur ein leeres Skelett). Der Server-
// gerenderte Inhalt landet dann NICHT im Client-Bundle – die Seite bleibt
// auf der Live-Site komplett leer und für Nutzer bleibt nur die Fallback-
// Navigation sichtbar, was so aussieht als würde man umgeleitet.
//
// Alle Komponenten (QR-Code, Download-Button, Native-Redirect) werden hier
// inline gerendert, damit der Content garantiert im /app JS-Bundle landet.

import { useEffect, useState } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import QRCode from 'qrcode'
import {
  Download,
  Smartphone,
  ShieldCheck,
  RefreshCw,
} from 'lucide-react'
import {
  APK_URL,
  APK_FILENAME,
  APK_DOWNLOAD_ENABLED,
} from '@/lib/app-download'
import AppDownloadStatusModal from '@/components/shared/AppDownloadStatusModal'

export default function AppDownloadPage() {
  const router = useRouter()
  const [qrSvg, setQrSvg] = useState<string | null>(null)
  const [showStatus, setShowStatus] = useState(false)

  // Master-Schalter aus: Seite ist offline → Redirect zur Startseite
  useEffect(() => {
    if (!APK_DOWNLOAD_ENABLED) {
      router.replace('/')
      return
    }
    // In der nativen APK ergibt die Download-Seite keinen Sinn – auf Dashboard umleiten.
    if (document.documentElement.classList.contains('is-native')) {
      router.replace('/dashboard')
      return
    }
    // Auf Android: Modal sofort zeigen, dann nach kurzer Pause Download starten.
    // window.location.href statt a.click() — Chrome blockt programmatische
    // Downloads ohne User-Geste, behandelt aber .apk-Navigationen als Download.
    const ua = navigator.userAgent
    if (/Android/i.test(ua)) {
      setShowStatus(true)
      setTimeout(() => {
        window.location.href = APK_URL
      }, 800)
    }
  }, [router])

  // Wenn Master-Schalter aus: nichts rendern, Redirect übernimmt
  if (!APK_DOWNLOAD_ENABLED) return null

  // QR-Code client-seitig generieren
  useEffect(() => {
    let cancelled = false
    QRCode.toString(APK_URL, {
      type: 'svg',
      margin: 1,
      width: 280,
      color: { dark: '#0E1A19', light: '#FFFFFF' },
      errorCorrectionLevel: 'M',
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

  const triggerDownload = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault()
    const trigger = document.createElement('a')
    trigger.href = APK_URL
    trigger.download = APK_FILENAME
    trigger.rel = 'noopener'
    document.body.appendChild(trigger)
    trigger.click()
    trigger.remove()
    setShowStatus(true)
  }

  return (
    <main className="cta-app-download relative min-h-dvh py-8 sm:py-16 px-4 overflow-hidden" style={{ background: 'linear-gradient(180deg, #EEF9F9 0%, #F4FEFE 60%, #FAFAF7 100%)' }}>
      {/* Ambient orbs */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
        <div className="absolute rounded-full" style={{ top: '-15%', left: '-10%', width: '55vw', height: '55vw', background: 'radial-gradient(circle, rgba(30,170,166,0.18) 0%, transparent 70%)', filter: 'blur(80px)', animation: 'ambientBreath1 24s ease-in-out infinite' }} />
        <div className="absolute rounded-full" style={{ bottom: '-10%', right: '-10%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(79,109,138,0.10) 0%, transparent 70%)', filter: 'blur(90px)', animation: 'ambientBreath2 30s ease-in-out infinite' }} />
      </div>

      <div className="relative max-w-3xl mx-auto">
        {/* Back link */}
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-sm text-ink-600 hover:text-primary-700 mb-6 font-medium"
        >
          ← Zur Startseite
        </Link>

        <div
          className="rounded-3xl overflow-hidden"
          style={{
            background: 'linear-gradient(150deg, rgba(255,255,255,1) 0%, rgba(250,250,247,0.97) 100%)',
            border: '1px solid rgba(208,245,243,0.85)',
            boxShadow: '0 0 0 0.5px rgba(30,170,166,0.12), 0 8px 16px rgba(15,23,42,0.08), 0 32px 80px rgba(15,23,42,0.14), 0 0 64px rgba(30,170,166,0.12), inset 0 1px 0 rgba(255,255,255,1)',
          }}
        >
          {/* Hero */}
          <div className="relative overflow-hidden px-6 sm:px-10 py-10 sm:py-14 text-center" style={{ background: 'linear-gradient(135deg, #147170 0%, #1EAAA6 50%, #0e8f8b 100%)' }}>
            <div className="pointer-events-none absolute inset-0" style={{ background: 'radial-gradient(ellipse at 30% 20%, rgba(255,255,255,0.15) 0%, transparent 60%)' }} aria-hidden="true" />
            <div className="relative">
              <div className="inline-block bg-white/15 backdrop-blur-sm rounded-3xl p-3 mb-4 shadow-[0_0_40px_rgba(255,255,255,0.15)]">
                <Image
                  src="/icons/icon-512x512.png"
                  alt="Mensaena App Icon"
                  width={88}
                  height={88}
                  className="rounded-2xl"
                  priority
                />
              </div>
              <h1 className="text-3xl sm:text-4xl font-bold tracking-tight text-white">
                Mensaena als App
              </h1>
              <p className="mt-3 text-white/85 text-base sm:text-lg max-w-md mx-auto">
                Nachbarschaftshilfe direkt am Handy – kostenlos für Android
              </p>
            </div>
          </div>

          {/* Body */}
          <div className="p-6 sm:p-10">
            <div className="grid sm:grid-cols-[auto_1fr] gap-8 items-center">
              {/* QR code */}
              <div className="flex flex-col items-center">
                {qrSvg ? (
                  <div
                    role="img"
                    aria-label="QR-Code zum APK-Download"
                    className="bg-white rounded-2xl border-2 border-primary-100 p-4 w-[260px] h-[260px] flex items-center justify-center"
                    dangerouslySetInnerHTML={{ __html: qrSvg }}
                  />
                ) : (
                  <div
                    aria-label="QR-Code wird geladen"
                    className="bg-white rounded-2xl border-2 border-primary-100 p-4 w-[260px] h-[260px] flex items-center justify-center"
                  >
                    <div className="w-[230px] h-[230px] bg-stone-100 rounded-lg animate-pulse" />
                  </div>
                )}
                <p className="text-xs text-ink-500 mt-3 text-center max-w-[260px]">
                  QR-Code mit der Kamera des Handys scannen
                </p>
              </div>

              {/* Direct download */}
              <div className="text-center sm:text-left">
                <p className="text-sm font-semibold text-ink-500 uppercase tracking-wider mb-2">
                  Oder direkt
                </p>
                <h2 className="text-xl font-bold text-ink-900 mb-4">
                  APK herunterladen
                </h2>
                <a
                  href={APK_URL}
                  download={APK_FILENAME}
                  rel="noopener"
                  onClick={triggerDownload}
                  className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3.5 text-base"
                >
                  <Download className="w-5 h-5" aria-hidden="true" />
                  Mensaena.apk laden
                </a>
                <p className="text-xs text-ink-500 mt-3">
                  Aktueller Build aus{' '}
                  <code className="text-[11px] bg-stone-100 px-1 rounded">main</code>{' '}
                  – signiert &amp; sicher
                </p>
              </div>
            </div>

            {/* Trust badges */}
            <div className="mt-10 grid grid-cols-1 sm:grid-cols-3 gap-3">
              <Badge icon={<ShieldCheck className="w-4 h-4" />}>
                Konsistent signiert
              </Badge>
              <Badge icon={<RefreshCw className="w-4 h-4" />}>
                Updates ohne Neuinstallation
              </Badge>
              <Badge icon={<Smartphone className="w-4 h-4" />}>
                Funktioniert auf Android 7+
              </Badge>
            </div>

            {/* Install steps */}
            <section className="mt-10 bg-primary-50/50 rounded-2xl p-6">
              <h3 className="font-bold text-ink-900 mb-3">
                Installation in 3 Schritten
              </h3>
              <ol className="space-y-2 text-sm text-ink-700">
                <li className="flex gap-3">
                  <Step n="1" />
                  <span>APK herunterladen (Button oben oder QR-Code scannen)</span>
                </li>
                <li className="flex gap-3">
                  <Step n="2" />
                  <span>
                    In den Downloads auf <em>mensaena-release.apk</em> tippen
                  </span>
                </li>
                <li className="flex gap-3">
                  <Step n="3" />
                  <span>
                    Android fragt einmalig nach Erlaubnis – &quot;Installieren&quot; tippen, fertig
                  </span>
                </li>
              </ol>
            </section>

            {/* GitHub Release info */}
            <div className="mt-6 px-5 py-4 bg-stone-50 border border-stone-200 rounded-xl text-sm text-ink-600 text-center">
              Direkt von GitHub · Open Source · kein App-Store nötig
            </div>
          </div>
        </div>

        {/* Privacy note */}
        <p className="text-xs text-ink-500 text-center mt-6 max-w-md mx-auto">
          Open Source · keine Tracker · DSGVO-konform · Quellcode auf{' '}
          <a
            href="https://github.com/manuelbrandner85/Mensaena"
            target="_blank"
            rel="noopener noreferrer"
            className="text-primary-700 underline"
          >
            GitHub
          </a>
        </p>
      </div>

      {showStatus && (
        <AppDownloadStatusModal onClose={() => setShowStatus(false)} />
      )}
    </main>
  )
}

function Badge({
  icon,
  children,
}: {
  icon: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div className="flex items-center justify-center gap-2 px-4 py-2.5 bg-primary-50 rounded-xl border border-primary-100/60 text-primary-800 text-xs font-medium">
      {icon}
      <span>{children}</span>
    </div>
  )
}

function Step({ n }: { n: string }) {
  return (
    <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">
      {n}
    </span>
  )
}
