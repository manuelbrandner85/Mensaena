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
  ArrowLeft,
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
      color: { dark: '#0a1420', light: '#ece5d6' },
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
    <main
      className="relative min-h-dvh py-8 sm:py-16 px-4 overflow-hidden"
      style={{ background: '#0a1420', color: '#ece5d6' }}
    >
      {/* Ambient depth orbs */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
        <div className="absolute rounded-full" style={{ top: '-15%', left: '-10%', width: '55vw', height: '55vw', background: 'radial-gradient(circle, rgba(199,147,99,0.12) 0%, transparent 70%)', filter: 'blur(80px)' }} />
        <div className="absolute rounded-full" style={{ bottom: '-10%', right: '-10%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(43,86,99,0.15) 0%, transparent 70%)', filter: 'blur(90px)' }} />
      </div>

      <div className="relative max-w-3xl mx-auto">
        {/* Back link */}
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-sm font-medium mb-8 transition-opacity hover:opacity-70"
          style={{ color: '#94A3B8' }}
        >
          <ArrowLeft className="w-4 h-4" />
          Zur Startseite
        </Link>

        {/* Main card */}
        <div
          className="rounded-3xl overflow-hidden"
          style={{
            background: 'linear-gradient(150deg, rgba(22,32,53,0.90) 0%, rgba(15,22,40,0.95) 100%)',
            border: '1px solid rgba(199,147,99,0.15)',
            boxShadow: '0 0 0 0.5px rgba(199,147,99,0.08), 0 8px 16px rgba(0,0,0,0.30), 0 32px 80px rgba(0,0,0,0.40)',
          }}
        >
          {/* Hero banner */}
          <div
            className="relative overflow-hidden px-6 sm:px-10 py-10 sm:py-14 text-center"
            style={{ background: 'linear-gradient(135deg, rgba(199,147,99,0.22) 0%, rgba(43,86,99,0.25) 100%)', borderBottom: '1px solid rgba(199,147,99,0.15)' }}
          >
            <div className="pointer-events-none absolute inset-0" style={{ background: 'radial-gradient(ellipse at 30% 20%, rgba(199,147,99,0.10) 0%, transparent 60%)' }} aria-hidden="true" />
            <div className="relative">
              <div className="inline-block rounded-3xl p-3 mb-4" style={{ background: 'rgba(199,147,99,0.15)', border: '1px solid rgba(199,147,99,0.25)', boxShadow: '0 0 40px rgba(199,147,99,0.15)' }}>
                <Image
                  src="/icons/icon-512x512.png"
                  alt="Mensaena App Icon"
                  width={88}
                  height={88}
                  className="rounded-2xl"
                  priority
                />
              </div>
              <h1 className="text-3xl sm:text-4xl font-medium tracking-tight" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>
                Mensaena als <em style={{ color: '#c79363', fontStyle: 'italic' }}>App</em>
              </h1>
              <p className="mt-3 text-base sm:text-lg max-w-md mx-auto" style={{ color: '#94A3B8' }}>
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
                    className="rounded-2xl p-4 w-[260px] h-[260px] flex items-center justify-center"
                    style={{ background: 'rgba(15,22,40,0.80)', border: '2px solid rgba(199,147,99,0.25)' }}
                    dangerouslySetInnerHTML={{ __html: qrSvg }}
                  />
                ) : (
                  <div
                    aria-label="QR-Code wird geladen"
                    className="rounded-2xl p-4 w-[260px] h-[260px] flex items-center justify-center"
                    style={{ background: 'rgba(15,22,40,0.80)', border: '2px solid rgba(199,147,99,0.25)' }}
                  >
                    <div className="w-[230px] h-[230px] rounded-lg animate-pulse" style={{ background: 'rgba(22,32,53,0.80)' }} />
                  </div>
                )}
                <p className="text-xs mt-3 text-center max-w-[260px]" style={{ color: '#64748B' }}>
                  QR-Code mit der Kamera des Handys scannen
                </p>
              </div>

              {/* Direct download */}
              <div className="text-center sm:text-left">
                <p className="text-sm font-semibold uppercase tracking-wider mb-2" style={{ color: '#64748B' }}>
                  Oder direkt
                </p>
                <h2 className="text-xl font-medium mb-4" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>
                  APK herunterladen
                </h2>
                <a
                  href={APK_URL}
                  download={APK_FILENAME}
                  rel="noopener"
                  onClick={triggerDownload}
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3.5 text-base rounded-full font-medium transition-all hover:opacity-90"
                  style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)', color: '#0a1420' }}
                >
                  <Download className="w-5 h-5" aria-hidden="true" />
                  Mensaena.apk laden
                </a>
                <p className="text-xs mt-3" style={{ color: '#64748B' }}>
                  Aktueller Build aus{' '}
                  <code className="text-[11px] px-1 rounded" style={{ background: 'rgba(22,32,53,0.80)', color: '#94A3B8' }}>main</code>{' '}
                  – signiert &amp; sicher
                </p>
              </div>
            </div>

            {/* Trust badges */}
            <div className="mt-10 grid grid-cols-1 sm:grid-cols-3 gap-3">
              <TrustBadge icon={<ShieldCheck className="w-4 h-4" />}>
                Konsistent signiert
              </TrustBadge>
              <TrustBadge icon={<RefreshCw className="w-4 h-4" />}>
                Updates ohne Neuinstallation
              </TrustBadge>
              <TrustBadge icon={<Smartphone className="w-4 h-4" />}>
                Funktioniert auf Android 7+
              </TrustBadge>
            </div>

            {/* Install steps */}
            <section className="mt-10 rounded-2xl p-6" style={{ background: 'rgba(15,22,40,0.60)', border: '1px solid rgba(199,147,99,0.10)' }}>
              <h3 className="font-medium mb-3" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>
                Installation in 3 Schritten
              </h3>
              <ol className="space-y-2 text-sm" style={{ color: '#94A3B8' }}>
                <li className="flex gap-3">
                  <StepDot n="1" />
                  <span>APK herunterladen (Button oben oder QR-Code scannen)</span>
                </li>
                <li className="flex gap-3">
                  <StepDot n="2" />
                  <span>
                    In den Downloads auf <em style={{ color: '#ece5d6' }}>mensaena-release.apk</em> tippen
                  </span>
                </li>
                <li className="flex gap-3">
                  <StepDot n="3" />
                  <span>
                    Android fragt einmalig nach Erlaubnis – &quot;Installieren&quot; tippen, fertig
                  </span>
                </li>
              </ol>
            </section>

            {/* GitHub Release info */}
            <div className="mt-6 px-5 py-4 rounded-xl text-sm text-center" style={{ background: 'rgba(22,32,53,0.60)', border: '1px solid rgba(255,255,255,0.05)', color: '#64748B' }}>
              Direkt von GitHub · Open Source · kein App-Store nötig
            </div>
          </div>
        </div>

        {/* Privacy note */}
        <p className="text-xs text-center mt-6 max-w-md mx-auto" style={{ color: '#64748B' }}>
          Open Source · keine Tracker · DSGVO-konform · Quellcode auf{' '}
          <a
            href="https://github.com/manuelbrandner85/Mensaena"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: '#c79363' }}
            className="underline hover:opacity-80"
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

function TrustBadge({
  icon,
  children,
}: {
  icon: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div
      className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-xs font-medium"
      style={{ background: 'rgba(22,32,53,0.70)', border: '1px solid rgba(199,147,99,0.15)', color: '#c79363' }}
    >
      {icon}
      <span>{children}</span>
    </div>
  )
}

function StepDot({ n }: { n: string }) {
  return (
    <span
      className="flex-shrink-0 w-6 h-6 rounded-full text-xs font-bold flex items-center justify-center"
      style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 100%)', color: '#0a1420' }}
    >
      {n}
    </span>
  )
}
