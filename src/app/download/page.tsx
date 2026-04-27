'use client'

import { useEffect, useState } from 'react'
import { Smartphone, Download, RefreshCw, Shield, CheckCircle, ExternalLink, QrCode, ChevronDown, ChevronUp } from 'lucide-react'
import Image from 'next/image'

const FDROID_REPO_URL = 'https://www.mensaena.de/fdroid/repo'
const FDROID_FINGERPRINT = 'B1C5EDD7840D0E63A9E305D728A803C4A75C00C31A0CE158B40E9D97E6FB5D9B'
const FDROID_DEEP_LINK = `fdroidrepos://${FDROID_REPO_URL.replace('https://', '')}?fingerprint=${FDROID_FINGERPRINT}`
const FDROID_APP_LINK = 'https://f-droid.org/en/packages/de.mensaena.app/'
const APK_DIRECT_URL = 'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk'
const QR_API_URL = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent('https://www.mensaena.de/download')}`

function isAndroidDevice(): boolean {
  if (typeof navigator === 'undefined') return false
  return /android/i.test(navigator.userAgent)
}

function hasFDroid(): boolean {
  // We can't detect F-Droid reliably from the browser, so we assume it might be installed
  return false
}

export default function DownloadPage() {
  const [isAndroid, setIsAndroid] = useState(false)
  const [showFdroidInstructions, setShowFdroidInstructions] = useState(false)
  const [fdroidLinkAttempted, setFdroidLinkAttempted] = useState(false)

  useEffect(() => {
    setIsAndroid(isAndroidDevice())
  }, [])

  function handleFdroidClick() {
    setFdroidLinkAttempted(true)
    window.location.href = FDROID_DEEP_LINK
  }

  return (
    <main className="min-h-screen bg-background flex flex-col items-center px-4 py-12">
      {/* Header */}
      <div className="text-center mb-10 max-w-xl">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary-500 shadow-glow mb-4">
          <Smartphone className="w-8 h-8 text-white" />
        </div>
        <h1 className="text-3xl font-display font-semibold text-ink-900 dark:text-stone-100 mb-2">
          Mensaena App
        </h1>
        <p className="text-ink-500 dark:text-stone-400 text-base">
          Kostenlos herunterladen — mit automatischen Updates
        </p>
      </div>

      <div className="w-full max-w-lg flex flex-col gap-4">

        {/* Primary: F-Droid */}
        <div className="card p-6 flex flex-col gap-4">
          <div className="flex items-start gap-3">
            <div className="flex-shrink-0 w-10 h-10 rounded-xl bg-primary-50 dark:bg-primary-500/10 flex items-center justify-center">
              <RefreshCw className="w-5 h-5 text-primary-600 dark:text-primary-400" />
            </div>
            <div>
              <div className="flex items-center gap-2 mb-0.5">
                <h2 className="text-base font-semibold text-ink-900 dark:text-stone-100">Via F-Droid installieren</h2>
                <span className="text-[10px] font-semibold uppercase tracking-wide bg-primary-500 text-white px-1.5 py-0.5 rounded-full">Empfohlen</span>
              </div>
              <p className="text-sm text-ink-500 dark:text-stone-400">
                Automatische Updates, keine Registrierung, 100 % Open Source
              </p>
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <ul className="flex flex-col gap-1.5 text-sm text-ink-600 dark:text-stone-300">
              {[
                'Einmal einrichten — Updates kommen automatisch',
                'Kein Google-Konto notwendig',
                'Datenschutzfreundlich & DSGVO-konform',
              ].map((item) => (
                <li key={item} className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-primary-500 flex-shrink-0" />
                  {item}
                </li>
              ))}
            </ul>
          </div>

          <button
            onClick={handleFdroidClick}
            className="btn-primary w-full flex items-center justify-center gap-2 py-3 text-base font-semibold"
          >
            <span>In F-Droid öffnen</span>
            <ExternalLink className="w-4 h-4" />
          </button>

          {/* Fallback: show instructions if deep-link might not have worked */}
          {fdroidLinkAttempted && (
            <div className="rounded-xl bg-stone-50 dark:bg-stone-800 border border-stone-200 dark:border-stone-700 p-4 text-sm text-ink-600 dark:text-stone-300">
              <p className="font-medium text-ink-800 dark:text-stone-200 mb-2">F-Droid nicht installiert?</p>
              <ol className="list-decimal list-inside space-y-1.5">
                <li>
                  Lade F-Droid herunter:{' '}
                  <a
                    href="https://f-droid.org"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary-600 dark:text-primary-400 underline"
                  >
                    f-droid.org
                  </a>
                </li>
                <li>Öffne F-Droid und gehe zu Einstellungen → Repositories</li>
                <li>Tippe auf „Neues Repository hinzufügen"</li>
                <li>
                  Füge diese URL ein:{' '}
                  <code className="bg-stone-100 dark:bg-stone-700 px-1 rounded text-xs break-all">
                    {FDROID_REPO_URL}
                  </code>
                </li>
                <li>Suche nach „Mensaena" und installiere die App</li>
              </ol>
              <button
                onClick={() => setShowFdroidInstructions(!showFdroidInstructions)}
                className="mt-3 flex items-center gap-1 text-primary-600 dark:text-primary-400 text-xs font-medium"
              >
                {showFdroidInstructions ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                {showFdroidInstructions ? 'Weniger anzeigen' : 'Repository-Details anzeigen'}
              </button>
              {showFdroidInstructions && (
                <div className="mt-2 space-y-1 text-xs text-ink-400 dark:text-stone-500">
                  <p>Repository-URL:</p>
                  <code className="block break-all bg-stone-100 dark:bg-stone-700 px-2 py-1 rounded">
                    {FDROID_REPO_URL}
                  </code>
                  <p className="mt-1">Fingerprint:</p>
                  <code className="block break-all bg-stone-100 dark:bg-stone-700 px-2 py-1 rounded">
                    {FDROID_FINGERPRINT}
                  </code>
                </div>
              )}
            </div>
          )}

          {/* Manual instructions toggle for non-android / desktop */}
          {!isAndroid && !fdroidLinkAttempted && (
            <button
              onClick={() => setShowFdroidInstructions(!showFdroidInstructions)}
              className="text-sm text-primary-600 dark:text-primary-400 flex items-center gap-1 self-start"
            >
              {showFdroidInstructions ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
              Schritt-für-Schritt Anleitung
            </button>
          )}

          {showFdroidInstructions && !fdroidLinkAttempted && (
            <div className="rounded-xl bg-stone-50 dark:bg-stone-800 border border-stone-200 dark:border-stone-700 p-4 text-sm text-ink-600 dark:text-stone-300">
              <ol className="list-decimal list-inside space-y-1.5">
                <li>
                  Lade F-Droid herunter:{' '}
                  <a
                    href="https://f-droid.org"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary-600 dark:text-primary-400 underline"
                  >
                    f-droid.org
                  </a>
                </li>
                <li>Öffne F-Droid und gehe zu Einstellungen → Repositories</li>
                <li>Tippe auf „Neues Repository hinzufügen"</li>
                <li>
                  Füge diese URL ein:{' '}
                  <code className="bg-stone-100 dark:bg-stone-700 px-1 rounded text-xs break-all">
                    {FDROID_REPO_URL}
                  </code>
                </li>
                <li>Suche nach „Mensaena" und installiere die App</li>
              </ol>
            </div>
          )}
        </div>

        {/* Secondary: Direct APK */}
        <div className="card p-5 flex flex-col gap-3">
          <div className="flex items-start gap-3">
            <div className="flex-shrink-0 w-10 h-10 rounded-xl bg-stone-100 dark:bg-stone-800 flex items-center justify-center">
              <Download className="w-5 h-5 text-ink-500 dark:text-stone-400" />
            </div>
            <div>
              <h2 className="text-base font-semibold text-ink-900 dark:text-stone-100 mb-0.5">
                Direkt als APK herunterladen
              </h2>
              <p className="text-sm text-ink-500 dark:text-stone-400">
                Manuell installieren — Updates müssen manuell heruntergeladen werden
              </p>
            </div>
          </div>

          <a
            href={APK_DIRECT_URL}
            className="btn-outline w-full flex items-center justify-center gap-2 py-2.5 text-sm font-medium"
            rel="noopener"
          >
            <Download className="w-4 h-4" />
            APK herunterladen (neueste Version)
          </a>

          <p className="text-xs text-ink-400 dark:text-stone-500 flex items-center gap-1">
            <Shield className="w-3.5 h-3.5 flex-shrink-0" />
            Signierte APK aus GitHub Releases — immer die neueste Version
          </p>
        </div>

        {/* Desktop: QR Code */}
        {!isAndroid && (
          <div className="card p-5 flex items-center gap-5">
            <div className="flex-shrink-0">
              {/* QR Code generated via public API — points to this /download page */}
              <img
                src={QR_API_URL}
                alt="QR-Code für die Mensaena Download-Seite"
                width={88}
                height={88}
                className="rounded-lg border border-stone-200 dark:border-stone-700"
              />
            </div>
            <div>
              <div className="flex items-center gap-2 mb-1">
                <QrCode className="w-4 h-4 text-ink-400 dark:text-stone-500" />
                <span className="text-sm font-semibold text-ink-800 dark:text-stone-200">Am Handy öffnen</span>
              </div>
              <p className="text-sm text-ink-500 dark:text-stone-400">
                Scanne den QR-Code mit deinem Android-Gerät, um direkt zu dieser Seite zu gelangen.
              </p>
            </div>
          </div>
        )}

        {/* Note: iOS */}
        <p className="text-center text-xs text-ink-400 dark:text-stone-500 px-2 pb-2">
          Mensaena ist aktuell nur für Android verfügbar. Eine iOS-Version ist in Planung.
        </p>
      </div>
    </main>
  )
}
