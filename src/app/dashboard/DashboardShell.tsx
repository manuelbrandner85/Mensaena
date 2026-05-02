'use client'

import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { usePathname } from 'next/navigation'
import dynamic from 'next/dynamic'
import toast from 'react-hot-toast'
import Image from 'next/image'
import Link from 'next/link'
import MensaenaBot from '@/components/bot/MensaenaBot'
import { formatRelativeTime, getNotificationCategoryLabel } from '@/lib/notifications'
import type { AppNotification } from '@/types'
import { createClient } from '@/lib/supabase/client'
import { NOTIFICATION_ACTIONS } from '@/lib/constants/notification-actions'
import { cn } from '@/lib/utils'
import LocationOnboardingModal from './components/LocationOnboardingModal'
import { playStartupMelody } from '@/lib/audio/startupMelody'
// UPDATE-SYSTEM: Update-Hooks und dynamische Update-Screen-Komponenten
import { useAppUpdate } from '@/hooks/useAppUpdate'
import { initCapacitor } from '@/lib/capacitor-init'

// ── Lazy-load components (client-only, no SSR) ──────────────────
const ZeitbankConfirmationBanner = dynamic(() => import('@/components/zeitbank/ZeitbankConfirmationBanner'), { ssr: false })
const RevealObserver = dynamic(() => import('@/app/landing/components/RevealObserver'), { ssr: false })
const OnboardingTour = dynamic(() => import('@/components/shared/OnboardingTour'), { ssr: false })
const NotificationPromptBanner = dynamic(() => import('@/components/shared/NotificationPromptBanner'), { ssr: false })
const GlobalCallListener = dynamic(() => import('@/components/chat/GlobalCallListener'), { ssr: false })
// UPDATE-SYSTEM: Update-Screens werden lazy geladen (nicht in initial bundle)
const WebUpdateScreen = dynamic(() => import('@/components/updates/WebUpdateScreen'), { ssr: false })
const ApkUpdateScreen = dynamic(() => import('@/components/updates/ApkUpdateScreen'), { ssr: false })

// ── Sound preference helpers ────────────────────────────────────────

/**
 * Read sound preference from localStorage (fast, no DB call).
 * The NotificationSettings component syncs this value when the user saves.
 */
function isSoundEnabled(): boolean {
  if (typeof window === 'undefined') return true
  const stored = localStorage.getItem('mensaena_notify_sound')
  return stored !== 'false' // default: enabled
}

/**
 * Determine if browser push should fire (tab not focused or minimized).
 */
function shouldShowBrowserPush(): boolean {
  if (typeof document === 'undefined') return false
  return document.hidden || document.visibilityState === 'hidden'
}

// ── Notification sound player ────────────────────────────────────────

let audioInstance: HTMLAudioElement | null = null

function playNotificationSound() {
  if (!isSoundEnabled()) return
  try {
    // Reuse audio instance for performance
    if (!audioInstance) {
      audioInstance = new Audio('/sounds/notification.mp3')
    }
    audioInstance.currentTime = 0
    audioInstance.volume = 0.3
    audioInstance.play().catch(() => {})
  } catch {
    // Sound file missing or blocked – ignore
  }
}

// ═══════════════════════════════════════════════════════════════════════

interface Profile { id: string; latitude: number | null; longitude: number | null }

// Module-level cache for the shell-profile (id + lat/lng).
// Only fetched once per session – avoids re-querying on every layout remount.
let _shellProfileCache: Profile | null = null

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const swRef = useRef<ServiceWorkerRegistration | null>(null)
  const [profile, setProfile] = useState<Profile | null>(_shellProfileCache)
  // UPDATE-SYSTEM: mounted-Flag für createPortal (document.body nur client-side verfügbar)
  const [mounted, setMounted] = useState(false)
  // UPDATE-SYSTEM: Update-State
  const update = useAppUpdate()

  useEffect(() => {
    if (_shellProfileCache) {
      setProfile(_shellProfileCache)
      return
    }
    let cancelled = false
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (cancelled || !user) return
      supabase
        .from('profiles')
        .select('id, latitude, longitude')
        .eq('id', user.id)
        .maybeSingle()
        .then(({ data }) => {
          if (cancelled || !data) return
          _shellProfileCache = data as Profile
          setProfile(data as Profile)
        })
        .catch((err) => {
          console.error('[DashboardShell] profile load failed:', err)
        })
    })
    return () => { cancelled = true }
  }, [])

  // FIX-118: Cache bei Auth-State-Change (Logout/Login) invalidieren.
  // Vorher: Modul-level _shellProfileCache hielt alte User-Daten nach Logout.
  // Bei User-Wechsel ohne Full-Reload würden alte ID/Koordinaten weiterleben.
  useEffect(() => {
    const supabase = createClient()
    const { data: subscription } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT' || (event === 'SIGNED_IN' && session?.user.id !== _shellProfileCache?.id)) {
        _shellProfileCache = null
        setProfile(null)
      }
    })
    return () => { subscription.subscription.unsubscribe() }
  }, [])

  // UPDATE-SYSTEM: Portal-Mount + Capacitor-Init
  useEffect(() => {
    setMounted(true)
    initCapacitor()
  }, [])

  // Cache SW registration for push notifications
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then(reg => { swRef.current = reg })
    }
  }, [])

  // Startup melody — plays once per session on first user interaction
  useEffect(() => {
    const trigger = () => {
      playStartupMelody()
      window.removeEventListener('pointerdown', trigger)
      window.removeEventListener('keydown', trigger)
    }
    // Audio context can only start after user gesture — listen for first interaction
    window.addEventListener('pointerdown', trigger, { once: true })
    window.addEventListener('keydown', trigger, { once: true })
    return () => {
      window.removeEventListener('pointerdown', trigger)
      window.removeEventListener('keydown', trigger)
    }
  }, [])

  // ── Realtime notification toast + push + sound ────────────────────
  useEffect(() => {
    const handler = (e: Event) => {
      const notification = (e as CustomEvent<AppNotification>).detail
      if (!notification) return

      // Suppress toasts on the notifications page
      const onNotifPage = pathname === '/dashboard/notifications'

      const title = notification.title || getNotificationCategoryLabel(notification.category)
      const content = notification.content || ''
      const action = NOTIFICATION_ACTIONS[notification.type] ?? null
      const isCrisis = notification.type === 'crisis_alert'

      // 1) In-App Toast (skip on notifications page)
      if (!onNotifPage) {
        toast.custom(
          (t) => (
            <div
              className={cn(
                t.visible ? 'animate-slide-up' : 'animate-fade-out',
                'max-w-sm w-full bg-white shadow-xl rounded-2xl pointer-events-auto flex border border-stone-100 overflow-hidden',
                isCrisis && 'border-l-4 border-l-red-500',
              )}
            >
              {/* Avatar or colored bar */}
              {notification.actor_avatar ? (
                <div className="flex-shrink-0 p-3">
                  <Image
                    src={notification.actor_avatar}
                    alt={notification.actor_name || ''}
                    width={40}
                    height={40}
                    className="w-10 h-10 rounded-full object-cover"
                  />
                </div>
              ) : (
                <div className="w-1.5 bg-primary-500 flex-shrink-0" />
              )}

              <div className="flex-1 p-3 min-w-0">
                <div className="flex items-center gap-1.5 mb-0.5">
                  <div className="w-1.5 h-1.5 rounded-full bg-primary-500 animate-pulse" />
                  <span className="text-xs font-semibold text-primary-600 uppercase tracking-wider">Neu</span>
                </div>
                <p className="text-sm font-semibold text-ink-900 truncate">
                  {notification.actor_name && (
                    <span>{notification.actor_name}: </span>
                  )}
                  {title}
                </p>
                {content && (
                  <p className="text-xs text-ink-500 line-clamp-2 mt-0.5">{content}</p>
                )}
                {action && (
                  <Link
                    href={notification.link || '/dashboard/notifications'}
                    onClick={() => toast.dismiss(t.id)}
                    className={cn(
                      'text-sm font-semibold mt-2 block',
                      isCrisis ? 'text-red-600 font-bold' : 'text-primary-600',
                    )}
                  >
                    {action.emoji} {action.label} →
                  </Link>
                )}
                <p className="text-xs text-ink-400 mt-1">{formatRelativeTime(notification.created_at)}</p>
              </div>

              <div className="flex flex-col justify-center pr-3 gap-1">
                <Link
                  href={notification.link || '/dashboard/notifications'}
                  onClick={() => toast.dismiss(t.id)}
                  className="text-xs font-medium text-primary-600 hover:text-primary-700 whitespace-nowrap"
                >
                  Anzeigen
                </Link>
                <button
                  onClick={() => toast.dismiss(t.id)}
                  className="text-xs text-ink-400 hover:text-ink-600"
                >
                  Schließen
                </button>
              </div>
            </div>
          ),
          { duration: 6000, position: 'top-right' },
        )
      }

      // 2) Sound notification (respects user preference via localStorage)
      playNotificationSound()

      // 3) Browser Push Notification (when tab is not focused)
      if (shouldShowBrowserPush() && Notification.permission === 'granted') {
        const reg = swRef.current
        if (reg) {
          const pushBody = action
            ? (content ? `${content}\n${action.emoji} ${action.label}` : `${action.emoji} ${action.label}`)
            : (content || undefined)
          reg.showNotification(
            notification.actor_name ? `${notification.actor_name}: ${title}` : title,
            {
              body: pushBody,
              icon: notification.actor_avatar || '/icons/icon-192x192.png',
              badge: '/icons/icon-72x72.png',
              tag: `mensaena-${notification.category}-${notification.id}`,
              data: { url: notification.link || '/dashboard/notifications' },
              vibrate: [100, 50, 100],
              renotify: true,
              requireInteraction: false,
              ...(action ? { actions: [{ action: 'open', title: action.label }] } : {}),
            } as NotificationOptions,
          ).catch(() => {})
        }
      }
    }

    window.addEventListener('mensaena-notification', handler)
    return () => window.removeEventListener('mensaena-notification', handler)
  }, [pathname])

  // UPDATE-SYSTEM: App-Sperre bei Pflicht-APK-Update
  // Erst nach mount prüfen (document.body nur client-side verfügbar)
  if (mounted && update.appLocked) {
    return createPortal(
      <ApkUpdateScreen
        apkReleaseNotes={update.apkReleaseNotes!}
        webReleaseNotes={update.releaseNotes}
        newApkVersion={update.newApkVersion!}
        currentApkVersion={update.currentApkVersion}
        apkSize={update.apkSize!}
        isDownloading={update.isDownloadingApk}
        downloadProgress={update.apkDownloadProgress}
        onDownload={update.downloadApk}
      />,
      document.body,
    )
  }

  return (
    <>
      {/* UPDATE-SYSTEM: Web-Update Vollbild-Screen (optional, mit Später) */}
      {mounted && update.webUpdateAvailable && !update.webDismissed && createPortal(
        <WebUpdateScreen
          releaseNotes={update.releaseNotes!}
          newVersion={update.newWebVersion!}
          isUpdating={update.isUpdatingWeb}
          onUpdate={update.applyWebUpdate}
          onDismiss={update.dismissWebUpdate}
        />,
        document.body,
      )}

      {/* UPDATE-SYSTEM: Minimaler Banner wenn Web-Update dismissed */}
      {mounted && update.webUpdateAvailable && update.webDismissed && (
        <div className="fixed top-0 inset-x-0 z-[9998] h-10 bg-primary-500 text-white flex items-center justify-center gap-2 text-sm font-medium shadow-md">
          <span>🆕 Update verfügbar</span>
          <button
            onClick={update.applyWebUpdate}
            className="underline font-bold hover:opacity-80 transition-opacity"
          >
            Jetzt aktualisieren
          </button>
        </div>
      )}

      {children}

      {/* Bot + Onboarding */}
      <MensaenaBot />
      <OnboardingTour />

      {/* ── Zeitbank: global confirmation banner ── */}
      <ZeitbankConfirmationBanner />

      {/* ── Cinematic reveal activator ── */}
      <RevealObserver />

      {/* ── Location onboarding ── */}
      {profile && profile.latitude === null && profile.longitude === null && (
        <LocationOnboardingModal
          userId={profile.id}
          onLocationSaved={(lat, lng, location) =>
            setProfile(prev => prev ? { ...prev, latitude: lat, longitude: lng } : prev)
          }
        />
      )}

      {/* ── Push notification prompt (web only, permission=default, 5s delay) ── */}
      {profile && <NotificationPromptBanner userId={profile.id} />}

      {/* ── Global DM-Call Listener (zeigt IncomingCallScreen + LiveRoomModal) ── */}
      {profile && <GlobalCallListener userId={profile.id} />}
    </>
  )
}
