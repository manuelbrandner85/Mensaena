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

      // Web-Update prüfen
      const storedVersion = localStorage.getItem(WEB_VERSION_KEY)
      if (storedVersion === null) {
        // Erstbesuch: aktuelle Version speichern, kein Update anzeigen
        localStorage.setItem(WEB_VERSION_KEY, data.webVersion)
      } else if (compareSemver(data.webVersion, storedVersion) > 0) {
        setWebUpdateAvailable(true)
      }
    } catch {}
  }, [])

  useEffect(() => {
    fetchManifest()

    const interval = setInterval(fetchManifest, 30 * 60 * 1000)

    function handleVisibility() {
      if (document.visibilityState === 'visible') fetchManifest()
    }
    document.addEventListener('visibilitychange', handleVisibility)

    return () => {
      clearInterval(interval)
      document.removeEventListener('visibilitychange', handleVisibility)
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
    setWebDismissed(true)
  }, [])

  const downloadApk = useCallback(() => {
    if (!manifest?.apkUrl || isDownloadingApk) return
    setIsDownloadingApk(true)
    setApkDownloadProgress(0)

    // Android Download-Manager triggern
    window.open(manifest.apkUrl, '_blank')

    // Fortschritt simulieren (Download-Manager liefert keine Callbacks)
    let progress = 0
    progressTimerRef.current = setInterval(() => {
      progress += Math.random() * 12 + 3
      if (progress >= 100) {
        progress = 100
        if (progressTimerRef.current) {
          clearInterval(progressTimerRef.current)
          progressTimerRef.current = null
        }
      }
      setApkDownloadProgress(Math.min(Math.round(progress), 100))
    }, 600)
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
      apkUpdateRequired =
        manifest.apkRequired ||
        compareSemver(installedVersion, manifest.apkMinVersion) < 0
    }
  }

  // Web-Updates nur für Browser/PWA, nicht Capacitor (dort APK-Updates)
  const showWebUpdate = webUpdateAvailable && !isCapacitor

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
