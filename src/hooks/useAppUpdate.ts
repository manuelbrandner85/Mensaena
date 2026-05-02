'use client'

// UPDATE-SYSTEM: Zentrale Update-Erkennung für Web-OTA und APK-Updates
import { useState, useEffect, useCallback, useRef } from 'react'
import { useAppContext } from './useAppContext'

export interface Feature {
  emoji: string
  title: string
  description: string
}

export interface ReleaseNotes {
  headline: string
  subtitle: string
  features: Feature[]
  footer: string
}

export interface ApkReleaseNotes {
  headline: string
  subtitle: string
  reason: string
  steps: string[]
  footer: string
}

interface VersionManifest {
  webVersion: string
  webBuildId: string
  apkVersion: string
  apkBuildCode: number
  apkUrl: string
  apkSize: string
  apkRequired: boolean
  apkMinVersion: string
  releasedAt: string
  releaseNotes: ReleaseNotes
  apkReleaseNotes: ApkReleaseNotes
}

export interface UpdateState {
  // Web-Update (nur für Browser/PWA, nicht Capacitor)
  webUpdateAvailable: boolean
  currentWebVersion: string
  newWebVersion: string | null
  releaseNotes: ReleaseNotes | null
  isUpdatingWeb: boolean
  applyWebUpdate: () => void
  dismissWebUpdate: () => void
  webDismissed: boolean

  // APK-Update (nur für Capacitor-Runtime)
  apkUpdateAvailable: boolean
  apkUpdateRequired: boolean
  currentApkVersion: string | null
  newApkVersion: string | null
  apkReleaseNotes: ApkReleaseNotes | null
  apkUrl: string | null
  apkSize: string | null
  isDownloadingApk: boolean
  apkDownloadProgress: number
  downloadApk: () => void

  // Kombiniert
  updateType: 'none' | 'web' | 'apk' | 'both'
  appLocked: boolean
}

const WEB_VERSION_KEY = 'mensaena_web_version'

function compareSemver(a: string, b: string): -1 | 0 | 1 {
  const normalize = (v: string) => v.replace(/[^0-9.]/g, '')
  const pa = normalize(a).split('.').map(Number)
  const pb = normalize(b).split('.').map(Number)
  for (let i = 0; i < 3; i++) {
    const va = pa[i] ?? 0
    const vb = pb[i] ?? 0
    if (va > vb) return 1
    if (va < vb) return -1
  }
  return 0
}

export function useAppUpdate(): UpdateState {
  const appContext = useAppContext()

  const [manifest, setManifest] = useState<VersionManifest | null>(null)
  const [webUpdateAvailable, setWebUpdateAvailable] = useState(false)
  const [webDismissed, setWebDismissed] = useState(false)
  const [isUpdatingWeb, setIsUpdatingWeb] = useState(false)
  const [isDownloadingApk, setIsDownloadingApk] = useState(false)
  const [apkDownloadProgress, setApkDownloadProgress] = useState(0)
  const progressTimerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const currentWebVersion =
    typeof window !== 'undefined'
      ? (localStorage.getItem(WEB_VERSION_KEY) ?? null)
      : null

  const fetchManifest = useCallback(async () => {
    try {
      const res = await fetch(`/version.json?t=${Date.now()}`)
      if (!res.ok) return
      const data: VersionManifest = await res.json()
      setManifest(data)

      // Web-Update prüfen.
      // null → "0.0.0": Kein gespeicherter Wert bedeutet veralteter Stand
      // (JSON war früher kaputt → nie gesetzt). Jede echte Version ist größer
      // als 0.0.0, sodass der Update-Screen zuverlässig erscheint.
      const storedVersion = localStorage.getItem(WEB_VERSION_KEY) ?? '0.0.0'
      if (compareSemver(data.webVersion, storedVersion) > 0) {
        setWebUpdateAvailable(true)
      }
    } catch {}
  }, [])

  useEffect(() => {
    fetchManifest()

    // Sehr kurzer Polling-Intervall, damit ein Deploy nahezu sofort erkannt wird.
    // version.json ist winzig (~1 KB) und wird via Cloudflare ausgeliefert — billig.
    const interval = setInterval(fetchManifest, 60 * 1000)

    function handleVisibility() {
      if (document.visibilityState === 'visible') fetchManifest()
    }
    function handleFocus() {
      fetchManifest()
    }
    function handleOnline() {
      fetchManifest()
    }
    function handleSwMessage(e: MessageEvent) {
      // Service Worker meldet sich nach Aktivierung → neuer Build ist live
      if (e.data?.type === 'SW_ACTIVATED') fetchManifest()
    }

    document.addEventListener('visibilitychange', handleVisibility)
    window.addEventListener('focus', handleFocus)
    window.addEventListener('online', handleOnline)
    if (typeof navigator !== 'undefined' && navigator.serviceWorker) {
      navigator.serviceWorker.addEventListener('message', handleSwMessage)
      navigator.serviceWorker.addEventListener('controllerchange', fetchManifest)
    }

    return () => {
      clearInterval(interval)
      document.removeEventListener('visibilitychange', handleVisibility)
      window.removeEventListener('focus', handleFocus)
      window.removeEventListener('online', handleOnline)
      if (typeof navigator !== 'undefined' && navigator.serviceWorker) {
        navigator.serviceWorker.removeEventListener('message', handleSwMessage)
        navigator.serviceWorker.removeEventListener('controllerchange', fetchManifest)
      }
    }
  }, [fetchManifest])

  const applyWebUpdate = useCallback(() => {
    if (!manifest) return
    setIsUpdatingWeb(true)
    localStorage.setItem(WEB_VERSION_KEY, manifest.webVersion)
    // SW zum Aktivieren auffordern
    if (typeof navigator !== 'undefined' && navigator.serviceWorker?.controller) {
      navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' })
    }
    setTimeout(() => window.location.reload(), 400)
  }, [manifest])

  const dismissWebUpdate = useCallback(() => {
    // Version in localStorage speichern, damit der Screen nach einem Reload
    // nicht erneut erscheint — erst wieder bei einer wirklich neuen Version.
    if (manifest) localStorage.setItem(WEB_VERSION_KEY, manifest.webVersion)
    setWebDismissed(true)
  }, [manifest])

  const downloadApk = useCallback(() => {
    if (!manifest?.apkUrl || isDownloadingApk) return
    setIsDownloadingApk(true)
    setApkDownloadProgress(0)

    if (typeof window === 'undefined') return

    // FIX-82: Web-Version markieren, damit nach APK-Install nicht nochmal
    // ein Web-Update-Dialog erscheint (User stimmt nur einmal zu).
    try { localStorage.setItem(WEB_VERSION_KEY, manifest.webVersion) } catch {}

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = window as any

    // Callback that Java calls back with progress (0-100) or -1 on error
    w.onApkProgress = (pct: number) => {
      if (pct < 0) {
        setIsDownloadingApk(false)
        setApkDownloadProgress(0)
      } else if (pct >= 100) {
        setApkDownloadProgress(100)
        setTimeout(() => setIsDownloadingApk(false), 2000)
      } else {
        setApkDownloadProgress(Math.round(pct))
      }
    }

    if (w.MensaenaAPK) {
      // Neue APK: JavascriptInterface → DownloadManager in MainActivity
      w.MensaenaAPK.download(manifest.apkUrl)
    } else {
      // Fallback: window.location.href triggert WebView's setDownloadListener
      // → Android DownloadManager (kein Chrome, kein externer Browser)
      window.location.href = manifest.apkUrl
    }
    // Fortschritts-Simulation bis onApkProgress(100) vom BroadcastReceiver kommt
    let pct = 5
    // FIX-115: Vorherigen Interval clearen falls downloadApk doppelt aufgerufen wird
    if (progressTimerRef.current) clearInterval(progressTimerRef.current)
    progressTimerRef.current = setInterval(() => {
      pct = Math.min(95, pct + 1.5)
      setApkDownloadProgress(Math.round(pct))
    }, 1000)
  }, [manifest, isDownloadingApk])

  useEffect(() => {
    return () => {
      if (progressTimerRef.current) clearInterval(progressTimerRef.current)
    }
  }, [])

  // APK-Update berechnen
  const isCapacitor = appContext.runtime === 'capacitor'
  const installedVersion = appContext.installedApkVersion

  let apkUpdateAvailable = false
  let apkUpdateRequired = false

  if (isCapacitor && installedVersion && manifest) {
    apkUpdateAvailable = compareSemver(manifest.apkVersion, installedVersion) > 0
    if (apkUpdateAvailable) {
      // FIX-82: Auf Capacitor IMMER als Pflicht-Update behandeln, sodass nur
      // ein Dialog erscheint (mit Web-Features integriert). Optionale Web-Updates
      // verschwinden hinter dem APK-Screen — User stimmt nur einmal zu.
      apkUpdateRequired = true
    }
  }

  // Web-Updates erscheinen auf allen Runtimes (Browser, PWA, Capacitor-WebView).
  // Der WebView lädt www.mensaena.de — Content-Updates gelten dort genauso.
  // APK-Updates (für native Shell-Änderungen) zeigen wir zusätzlich an, wenn
  // sich apkVersion unterscheidet.
  const showWebUpdate = webUpdateAvailable

  const updateType = ((): 'none' | 'web' | 'apk' | 'both' => {
    if (apkUpdateAvailable && showWebUpdate) return 'both'
    if (apkUpdateAvailable) return 'apk'
    if (showWebUpdate) return 'web'
    return 'none'
  })()

  return {
    webUpdateAvailable: showWebUpdate,
    currentWebVersion: currentWebVersion ?? '0.0.0',
    newWebVersion: manifest?.webVersion ?? null,
    releaseNotes: manifest?.releaseNotes ?? null,
    isUpdatingWeb,
    applyWebUpdate,
    dismissWebUpdate,
    webDismissed,

    apkUpdateAvailable,
    apkUpdateRequired,
    currentApkVersion: installedVersion,
    newApkVersion: manifest?.apkVersion ?? null,
    apkReleaseNotes: manifest?.apkReleaseNotes ?? null,
    apkUrl: manifest?.apkUrl ?? null,
    apkSize: manifest?.apkSize ?? null,
    isDownloadingApk,
    apkDownloadProgress,
    downloadApk,

    updateType,
    appLocked: apkUpdateRequired,
  }
}
