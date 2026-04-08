'use client'

import { useEffect } from 'react'
import { usePathname } from 'next/navigation'
import dynamic from 'next/dynamic'
import toast from 'react-hot-toast'
import Image from 'next/image'
import Link from 'next/link'
import MensaenaBot from '@/components/bot/MensaenaBot'
import { formatRelativeTime, getNotificationCategoryLabel } from '@/lib/notifications'
import type { AppNotification } from '@/types'

// ── Lazy-load PWA components (client-only, no SSR) ──────────────────
const OfflineBanner = dynamic(() => import('@/components/pwa/OfflineBanner'), { ssr: false })
const InstallPrompt = dynamic(() => import('@/components/pwa/InstallPrompt'), { ssr: false })
const UpdateAvailable = dynamic(() => import('@/components/pwa/UpdateAvailable'), { ssr: false })
const PushPermissionModal = dynamic(() => import('@/components/pwa/PushPermissionModal'), { ssr: false })

export default function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()

  // ── Realtime notification toast ────────────────────────────────────
  useEffect(() => {
    const handler = (e: Event) => {
      const notification = (e as CustomEvent<AppNotification>).detail
      if (!notification) return

      // Suppress toasts on the notifications page
      if (pathname === '/dashboard/notifications') return

      const title = notification.title || getNotificationCategoryLabel(notification.category)
      const content = notification.content || ''

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
              <div className="w-1.5 bg-emerald-500 flex-shrink-0" />
            )}

            <div className="flex-1 p-3 min-w-0">
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
                className="text-xs font-medium text-emerald-600 hover:text-emerald-700 whitespace-nowrap"
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

      // Optional notification sound
      try {
        const audio = new Audio('/sounds/notification.mp3')
        audio.volume = 0.3
        audio.play().catch(() => {})
      } catch {
        // Sound file missing or blocked – ignore
      }
    }

    window.addEventListener('mensaena-notification', handler)
    return () => window.removeEventListener('mensaena-notification', handler)
  }, [pathname])

  return (
    <>
      {children}

      {/* Bot – only in logged-in area */}
      <MensaenaBot />

      {/* ── PWA overlays ── */}
      <OfflineBanner />
      <UpdateAvailable />
      <InstallPrompt />
      <PushPermissionModal />
    </>
  )
}
