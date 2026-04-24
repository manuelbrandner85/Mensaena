'use client'

import { useEffect, useRef, useState } from 'react'
import { usePathname } from 'next/navigation'
import dynamic from 'next/dynamic'
import toast from 'react-hot-toast'
import Image from 'next/image'
import Link from 'next/link'
import MensaenaBot from '@/components/bot/MensaenaBot'
import { formatRelativeTime, getNotificationCategoryLabel } from '@/lib/notifications'
import type { AppNotification } from '@/types'
import { createClient } from '@/lib/supabase/client'
import LocationOnboardingModal from './components/LocationOnboardingModal'

// ── Lazy-load components (client-only, no SSR) ──────────────────
const ZeitbankConfirmationBanner = dynamic(() => import('@/components/zeitbank/ZeitbankConfirmationBanner'), { ssr: false })
const RevealObserver = dynamic(() => import('@/app/landing/components/RevealObserver'), { ssr: false })
const OnboardingTour = dynamic(() => import('@/components/shared/OnboardingTour'), { ssr: false })

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

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const swRef = useRef<ServiceWorkerRegistration | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      supabase
        .from('profiles')
        .select('id, latitude, longitude')
        .eq('id', user.id)
        .single()
        .then(({ data }) => { if (data) setProfile(data as Profile) })
    })
  }, [])

  // Cache SW registration for push notifications
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then(reg => { swRef.current = reg })
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

      // 1) In-App Toast (skip on notifications page)
      if (!onNotifPage) {
        toast.custom(
          (t) => (
            <div
              className={`${
                t.visible ? 'animate-slide-up' : 'animate-fade-out'
              } max-w-sm w-full bg-white shadow-xl rounded-2xl pointer-events-auto flex border border-gray-100 overflow-hidden`}
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
                  <span className="text-[10px] font-semibold text-primary-600 uppercase tracking-wider">Neu</span>
                </div>
                <p className="text-sm font-semibold text-gray-900 truncate">
                  {notification.actor_name && (
                    <span>{notification.actor_name}: </span>
                  )}
                  {title}
                </p>
                {content && (
                  <p className="text-xs text-gray-500 line-clamp-2 mt-0.5">{content}</p>
                )}
                <p className="text-xs text-gray-400 mt-1">{formatRelativeTime(notification.created_at)}</p>
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
                  className="text-xs text-gray-400 hover:text-gray-600"
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
          reg.showNotification(
            notification.actor_name ? `${notification.actor_name}: ${title}` : title,
            {
              body: content || undefined,
              icon: notification.actor_avatar || '/icons/icon-192x192.png',
              badge: '/icons/icon-72x72.png',
              tag: `mensaena-${notification.category}-${notification.id}`,
              data: { url: notification.link || '/dashboard/notifications' },
              vibrate: [100, 50, 100],
              renotify: true,
              requireInteraction: false,
            } as NotificationOptions,
          ).catch(() => {})
        }
      }
    }

    window.addEventListener('mensaena-notification', handler)
    return () => window.removeEventListener('mensaena-notification', handler)
  }, [pathname])

  return (
    <>
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
    </>
  )
}
