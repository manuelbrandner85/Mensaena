'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Smartphone, Download, RefreshCw, Shield, CheckCircle, ExternalLink, QrCode, ChevronDown, ChevronUp, Zap, ArrowLeft } from 'lucide-react'

const FDROID_REPO_URL = 'https://www.mensaena.de/fdroid/repo'
const FDROID_FINGERPRINT = 'B1C5EDD7840D0E63A9E305D728A803C4A75C00C31A0CE158B40E9D97E6FB5D9B'
const FDROID_DEEP_LINK = `fdroidrepos://${FDROID_REPO_URL.replace('https://', '')}?fingerprint=${FDROID_FINGERPRINT}`
const APK_DIRECT_URL = 'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk'
const QR_API_URL = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent('https://www.mensaena.de/download')}&color=c79363&bgcolor=0a1420&format=svg`

function isAndroidDevice(): boolean {
  if (typeof navigator === 'undefined') return false
  return /android/i.test(navigator.userAgent)
}

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

export default function DownloadPage() {
  const [isAndroid, setIsAndroid] = useState(false)
  const [showFdroidInstructions, setShowFdroidInstructions] = useState(false)
  const [fdroidLinkAttempted, setFdroidLinkAttempted] = useState(false)
  const [pwaPrompt, setPwaPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [pwaInstalled, setPwaInstalled] = useState(false)
  const [apkVersion, setApkVersion] = useState<string | null>(null)

  useEffect(() => {
    setIsAndroid(isAndroidDevice())

    const handler = (e: Event) => {
      e.preventDefault()
      setPwaPrompt(e as BeforeInstallPromptEvent)
    }
    window.addEventListener('beforeinstallprompt', handler)

    if (window.matchMedia('(display-mode: standalone)').matches) {
      setPwaInstalled(true)
    }

    fetch('/version.json')
      .then((r) => r.json())
      .then((d) => setApkVersion(d.apkVersion))
      .catch(() => {})

    return () => window.removeEventListener('beforeinstallprompt', handler)
  }, [])

  async function handlePwaInstall() {
    if (!pwaPrompt) return
    await pwaPrompt.prompt()
    const { outcome } = await pwaPrompt.userChoice
    if (outcome === 'accepted') {
      setPwaInstalled(true)
      setPwaPrompt(null)
    }
  }

  function handleFdroidClick() {
    setFdroidLinkAttempted(true)
    window.location.href = FDROID_DEEP_LINK
  }

  return (
    <div
      className="min-h-dvh relative overflow-hidden"
      style={{ background: '#0a1420', color: '#ece5d6' }}
    >
      {/* Atmospheric depth */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{ top: '-18%', left: '-14%', width: '60vw', height: '60vw', background: 'radial-gradient(circle, rgba(199,147,99,0.09) 0%, transparent 65%)', filter: 'blur(80px)' }}
        aria-hidden="true"
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{ bottom: '-15%', right: '-10%', width: '50vw', height: '50vw', background: 'radial-gradient(circle, rgba(43,86,99,0.12) 0%, transparent 65%)', filter: 'blur(90px)' }}
        aria-hidden="true"
      />

      <div className="relative max-w-2xl mx-auto px-4 sm:px-6 py-12 md:py-20">

        {/* Logo + back */}
        <Link
          href="/"
          className="group inline-flex items-center gap-3 mb-14"
          aria-label="Zurück zur Startseite"
        >
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={72}
            height={48}
            className="h-12 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
            priority
          />
          <span
            className="text-2xl font-medium tracking-tight"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F1F5F9' }}
          >
            Mensaena<span style={{ color: '#c79363' }}>.</span>
          </span>
        </Link>

        {/* Editorial header */}
        <header className="mb-12">
          <div className="meta-label meta-label--subtle mb-5">§ 01 / App herunterladen</div>
          <h1
            className="text-4xl md:text-5xl font-medium leading-tight tracking-tight mb-4"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
          >
            Mensaena <em style={{ fontStyle: 'italic', color: '#c79363' }}>in deiner Tasche.</em>
          </h1>
          <p style={{ color: '#94A3B8', fontSize: '1rem', lineHeight: 1.6 }}>
            Kostenlos für Android — automatische Updates, kein Store-Konto nötig.
          </p>
          <div className="mt-6 h-px" style={{ background: 'linear-gradient(90deg, rgba(199,147,99,0.35) 0%, rgba(199,147,99,0.10) 50%, transparent 100%)' }} />
        </header>

        <div className="flex flex-col gap-4">

          {/* PWA option */}
          {(pwaPrompt || pwaInstalled) && (
            <div
              className="rounded-2xl p-6 flex flex-col gap-5"
              style={{
                background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
                border: '1px solid rgba(199,147,99,0.20)',
                boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
              }}
            >
              <div className="flex items-start gap-4">
                <div
                  className="flex-shrink-0 w-12 h-12 rounded-xl flex items-center justify-center"
                  style={{ background: 'rgba(199,147,99,0.12)', border: '1px solid rgba(199,147,99,0.25)' }}
                >
                  <Zap className="w-5 h-5" style={{ color: '#c79363' }} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h2 className="text-base font-semibold" style={{ color: '#F8FAFC' }}>Als App installieren</h2>
                    <span
                      className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
                      style={{ background: 'rgba(199,147,99,0.15)', color: '#c79363', border: '1px solid rgba(199,147,99,0.25)' }}
                    >
                      Empfohlen
                    </span>
                  </div>
                  <p className="text-sm" style={{ color: '#64748B' }}>
                    Ein Tipp — automatische Updates — kein Store nötig
                  </p>
                </div>
              </div>
              <ul className="flex flex-col gap-2 text-sm" style={{ color: '#94A3B8' }}>
                {[
                  'Direkt auf dem Startbildschirm — immer griffbereit',
                  'Automatische Updates ohne manuellen Download',
                  'Kein App-Store, keine Registrierung',
                ].map((item) => (
                  <li key={item} className="flex items-center gap-2.5">
                    <CheckCircle className="w-4 h-4 flex-shrink-0" style={{ color: '#c79363' }} />
                    {item}
                  </li>
                ))}
              </ul>
              {pwaInstalled ? (
                <div
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-semibold opacity-60 cursor-default"
                  style={{ background: 'rgba(199,147,99,0.08)', color: '#c79363', border: '1px solid rgba(199,147,99,0.15)' }}
                >
                  <CheckCircle className="w-4 h-4" />
                  Bereits installiert
                </div>
              ) : (
                <button
                  onClick={handlePwaInstall}
                  className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-semibold transition-all hover:scale-[1.01] active:scale-95"
                  style={{
                    background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)',
                    color: '#0a1420',
                    border: '1px solid rgba(212,164,114,0.40)',
                    boxShadow: '0 4px 16px rgba(199,147,99,0.30)',
                  }}
                >
                  <span>📲 Als App installieren</span>
                </button>
              )}
            </div>
          )}

          {/* F-Droid */}
          <div
            className="rounded-2xl p-6 flex flex-col gap-5"
            style={{
              background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
              border: '1px solid rgba(255,255,255,0.06)',
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
            }}
          >
            <div className="flex items-start gap-4">
              <div
                className="flex-shrink-0 w-12 h-12 rounded-xl flex items-center justify-center"
                style={{ background: 'rgba(14,165,233,0.10)', border: '1px solid rgba(14,165,233,0.20)' }}
              >
                <RefreshCw className="w-5 h-5" style={{ color: '#7DD3FC' }} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h2 className="text-base font-semibold" style={{ color: '#F8FAFC' }}>Via F-Droid installieren</h2>
                  <span
                    className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
                    style={{ background: 'rgba(100,116,139,0.15)', color: '#94A3B8', border: '1px solid rgba(100,116,139,0.20)' }}
                  >
                    {pwaPrompt ? 'Alternativ' : 'Empfohlen'}
                  </span>
                </div>
                <p className="text-sm" style={{ color: '#64748B' }}>
                  Automatische Updates, keine Registrierung, 100 % Open Source
                </p>
              </div>
            </div>

            <ul className="flex flex-col gap-2 text-sm" style={{ color: '#94A3B8' }}>
              {[
                'Einmal einrichten — Updates kommen automatisch',
                'Kein Google-Konto notwendig',
                'Datenschutzfreundlich & DSGVO-konform',
              ].map((item) => (
                <li key={item} className="flex items-center gap-2.5">
                  <CheckCircle className="w-4 h-4 flex-shrink-0" style={{ color: '#7DD3FC' }} />
                  {item}
                </li>
              ))}
            </ul>

            <button
              onClick={handleFdroidClick}
              className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-semibold transition-all hover:scale-[1.01] active:scale-95"
              style={{
                background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)',
                color: '#0a1420',
                border: '1px solid rgba(212,164,114,0.40)',
                boxShadow: '0 4px 16px rgba(199,147,99,0.30)',
              }}
            >
              <span>In F-Droid öffnen</span>
              <ExternalLink className="w-4 h-4" />
            </button>

            {fdroidLinkAttempted && (
              <div
                className="rounded-xl p-4 text-sm"
                style={{ background: 'rgba(15,22,40,0.70)', border: '1px solid rgba(255,255,255,0.06)', color: '#94A3B8' }}
              >
                <p className="font-medium mb-2" style={{ color: '#F8FAFC' }}>F-Droid nicht installiert?</p>
                <ol className="list-decimal list-inside space-y-1.5" style={{ color: '#94A3B8' }}>
                  <li>Lade F-Droid herunter: <a href="https://f-droid.org" target="_blank" rel="noopener noreferrer" style={{ color: '#c79363' }}>f-droid.org</a></li>
                  <li>Öffne F-Droid → Einstellungen → Repositories</li>
                  <li>Tippe auf „Neues Repository hinzufügen"</li>
                  <li>Füge diese URL ein: <code style={{ background: 'rgba(22,32,53,0.85)', padding: '1px 6px', borderRadius: 4, fontSize: '0.75rem', wordBreak: 'break-all', color: '#94A3B8' }}>{FDROID_REPO_URL}</code></li>
                  <li>Suche nach „Mensaena" und installiere die App</li>
                </ol>
                <button
                  onClick={() => setShowFdroidInstructions(!showFdroidInstructions)}
                  className="mt-3 flex items-center gap-1 text-xs font-medium transition-colors"
                  style={{ color: '#c79363' }}
                >
                  {showFdroidInstructions ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                  {showFdroidInstructions ? 'Weniger anzeigen' : 'Repository-Details anzeigen'}
                </button>
                {showFdroidInstructions && (
                  <div className="mt-2 space-y-1 text-xs" style={{ color: '#64748B' }}>
                    <p>Repository-URL:</p>
                    <code style={{ display: 'block', wordBreak: 'break-all', background: 'rgba(22,32,53,0.85)', padding: '4px 8px', borderRadius: 4 }}>{FDROID_REPO_URL}</code>
                    <p className="mt-1">Fingerprint:</p>
                    <code style={{ display: 'block', wordBreak: 'break-all', background: 'rgba(22,32,53,0.85)', padding: '4px 8px', borderRadius: 4 }}>{FDROID_FINGERPRINT}</code>
                  </div>
                )}
              </div>
            )}

            {!isAndroid && !fdroidLinkAttempted && (
              <button
                onClick={() => setShowFdroidInstructions(!showFdroidInstructions)}
                className="text-sm flex items-center gap-1 self-start transition-colors"
                style={{ color: '#64748B' }}
              >
                {showFdroidInstructions ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                Schritt-für-Schritt Anleitung
              </button>
            )}

            {showFdroidInstructions && !fdroidLinkAttempted && (
              <div
                className="rounded-xl p-4 text-sm"
                style={{ background: 'rgba(15,22,40,0.70)', border: '1px solid rgba(255,255,255,0.06)', color: '#94A3B8' }}
              >
                <ol className="list-decimal list-inside space-y-1.5">
                  <li>Lade F-Droid herunter: <a href="https://f-droid.org" target="_blank" rel="noopener noreferrer" style={{ color: '#c79363' }}>f-droid.org</a></li>
                  <li>Öffne F-Droid → Einstellungen → Repositories</li>
                  <li>Tippe auf „Neues Repository hinzufügen"</li>
                  <li>Füge diese URL ein: <code style={{ background: 'rgba(22,32,53,0.85)', padding: '1px 6px', borderRadius: 4, fontSize: '0.75rem', wordBreak: 'break-all' }}>{FDROID_REPO_URL}</code></li>
                  <li>Suche nach „Mensaena" und installiere die App</li>
                </ol>
              </div>
            )}
          </div>

          {/* Direct APK */}
          <div
            className="rounded-2xl p-5 flex flex-col gap-4"
            style={{
              background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
              border: '1px solid rgba(255,255,255,0.06)',
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
            }}
          >
            <div className="flex items-start gap-4">
              <div
                className="flex-shrink-0 w-11 h-11 rounded-xl flex items-center justify-center"
                style={{ background: 'rgba(100,116,139,0.12)', border: '1px solid rgba(100,116,139,0.18)' }}
              >
                <Download className="w-5 h-5" style={{ color: '#64748B' }} />
              </div>
              <div>
                <h2 className="text-base font-semibold mb-0.5" style={{ color: '#F8FAFC' }}>
                  Direkt als APK herunterladen
                </h2>
                <p className="text-sm" style={{ color: '#64748B' }}>
                  Manuell installieren — Updates müssen manuell heruntergeladen werden
                </p>
              </div>
            </div>

            <a
              href={APK_DIRECT_URL}
              className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium transition-all hover:scale-[1.01] active:scale-95"
              style={{
                background: 'transparent',
                color: '#c79363',
                border: '1px solid rgba(199,147,99,0.35)',
              }}
              rel="noopener"
            >
              <Download className="w-4 h-4" />
              APK herunterladen{apkVersion ? ` (v${apkVersion})` : ' (neueste Version)'}
            </a>

            <p className="text-xs flex items-center gap-1.5" style={{ color: '#64748B' }}>
              <Shield className="w-3.5 h-3.5 flex-shrink-0" />
              Signierte APK aus GitHub Releases — immer die neueste Version
            </p>
          </div>

          {/* Desktop: QR Code */}
          {!isAndroid && (
            <div
              className="rounded-2xl p-5 flex items-center gap-6"
              style={{
                background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
                border: '1px solid rgba(255,255,255,0.06)',
                boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
              }}
            >
              <div className="flex-shrink-0">
                <img
                  src={QR_API_URL}
                  alt="QR-Code für die Mensaena Download-Seite"
                  width={88}
                  height={88}
                  className="rounded-xl"
                  style={{ border: '1px solid rgba(199,147,99,0.25)' }}
                />
              </div>
              <div>
                <div className="flex items-center gap-2 mb-1.5">
                  <QrCode className="w-4 h-4" style={{ color: '#c79363' }} />
                  <span className="text-sm font-semibold" style={{ color: '#F8FAFC' }}>Am Handy öffnen</span>
                </div>
                <p className="text-sm" style={{ color: '#64748B' }}>
                  Scanne den QR-Code mit deinem Android-Gerät, um direkt zu dieser Seite zu gelangen.
                </p>
              </div>
            </div>
          )}

          <p className="text-center text-xs pb-2" style={{ color: '#64748B' }}>
            Mensaena ist aktuell nur für Android verfügbar. Eine iOS-Version ist in Planung.
          </p>
        </div>

        {/* Back link */}
        <div className="mt-12 text-center">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-xs font-semibold tracking-[0.14em] uppercase transition-colors"
            style={{ color: '#64748B' }}
          >
            <ArrowLeft className="w-3 h-3" />
            Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
