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
  ChevronDown,
} from 'lucide-react'
import {
  APK_URL,
  APK_FILENAME,
  FDROID_DEEPLINK,
} from '@/lib/app-download'
import AppDownloadStatusModal from '@/components/shared/AppDownloadStatusModal'

export default function AppDownloadPage() {
  const router = useRouter()
  const [qrSvg, setQrSvg] = useState<string | null>(null)
  const [showStatus, setShowStatus] = useState(false)

  // In der nativen APK ergibt die Download-Seite keinen Sinn – auf Dashboard umleiten.
  useEffect(() => {
    if (document.documentElement.classList.contains('is-native')) {
      router.replace('/dashboard')
    }
  }, [router])

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
    <main className="cta-app-download min-h-dvh bg-gradient-to-br from-primary-50 via-white to-teal-50 py-8 sm:py-16 px-4">
      <div className="max-w-3xl mx-auto">
        {/* Back link */}
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-primary-700 mb-6 font-medium"
        >
          ← Zur Startseite
        </Link>

        <div className="bg-white rounded-3xl shadow-glow-teal/30 border border-primary-100/50 overflow-hidden">
          {/* Hero */}
          <div className="bg-gradient-to-br from-primary-600 to-teal-700 text-white px-6 sm:px-10 py-10 sm:py-14 text-center">
            <div className="inline-block bg-white/15 backdrop-blur-sm rounded-3xl p-3 mb-4">
              <Image
                src="/icons/icon-512x512.png"
                alt="Mensaena App Icon"
                width={88}
                height={88}
                className="rounded-2xl"
                priority
              />
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold tracking-tight">
              Mensaena als App
            </h1>
            <p className="mt-3 text-white/90 text-base sm:text-lg max-w-md mx-auto">
              Nachbarschaftshilfe direkt am Handy – kostenlos für Android
            </p>
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
                    <div className="w-[230px] h-[230px] bg-gray-100 rounded-lg animate-pulse" />
                  </div>
                )}
                <p className="text-xs text-gray-500 mt-3 text-center max-w-[260px]">
                  QR-Code mit der Kamera des Handys scannen
                </p>
              </div>

              {/* Direct download */}
              <div className="text-center sm:text-left">
                <p className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">
                  Oder direkt
                </p>
                <h2 className="text-xl font-bold text-gray-900 mb-4">
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
                <p className="text-xs text-gray-500 mt-3">
                  Aktueller Build aus{' '}
                  <code className="text-[11px] bg-gray-100 px-1 rounded">main</code>{' '}
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
              <h3 className="font-bold text-gray-900 mb-3">
                Installation in 3 Schritten
              </h3>
              <ol className="space-y-2 text-sm text-gray-700">
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

            {/* F-Droid (advanced) */}
            <details className="mt-6 group">
              <summary className="cursor-pointer flex items-center justify-between gap-3 px-5 py-4 bg-gray-50 hover:bg-gray-100 rounded-xl transition-colors">
                <span className="font-semibold text-gray-800 text-sm">
                  Erweitert: Per F-Droid installieren (automatische Updates)
                </span>
                <ChevronDown className="w-4 h-4 text-gray-500 transition-transform group-open:rotate-180" />
              </summary>
              <div className="mt-4 px-5 py-4 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 space-y-4">
                <p>
                  F-Droid ist ein freier App-Store. Damit erhältst du automatische
                  Updates, ohne Google Play Konto.
                </p>
                <ol className="list-decimal list-inside space-y-1 text-xs">
                  <li>
                    <a
                      href="https://f-droid.org"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-primary-700 underline"
                    >
                      F-Droid installieren
                    </a>{' '}
                    (kostenlos, sicher)
                  </li>
                  <li>Auf den Button unten tippen</li>
                  <li>Repo bestätigen → Mensaena suchen → Installieren</li>
                </ol>
                <a
                  href={FDROID_DEEPLINK}
                  className="btn-outline w-full inline-flex items-center justify-center gap-2"
                >
                  📦 F-Droid Repo hinzufügen
                </a>
              </div>
            </details>
          </div>
        </div>

        {/* Privacy note */}
        <p className="text-xs text-gray-500 text-center mt-6 max-w-md mx-auto">
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
