'use client'

import { useEffect, useState } from 'react'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { useAuthStore } from '@/store/useAuthStore'
import LandingPage from './landing/components/LandingPage'

/**
 * Detect whether the page is running inside the Capacitor APK.
 * - In Capacitor we set `appendUserAgent: 'MensaenaApp/1.0'` (capacitor.config.ts)
 * - `html.is-native` is set asynchronously by NativeBridge after Capacitor import
 * - UA check is synchronous and reliable immediately after hydration
 */
function detectNative(): boolean {
  if (typeof navigator === 'undefined') return false
  return /MensaenaApp/i.test(navigator.userAgent)
}

/**
 * Root route – Auth-aware entry.
 *
 * Web:
 *   - Loading → white spinner
 *   - Authenticated → /dashboard
 *   - Unauthenticated → full LandingPage
 *
 * Capacitor APK:
 *   - Skip LandingPage komplett (User hat die App ja schon installiert)
 *   - Authenticated → /dashboard
 *   - Unauthenticated → /auth?mode=login
 *   - Während der Umleitung: dunkler Splash mit Mensaena-Logo (passt zum
 *     nativen Splash-Screen `#0a1420`, kein Weiß-Flash)
 */
export default function HomePage() {
  const router = useRouter()
  const { user, loading, initialized, init } = useAuthStore()
  const [isNative, setIsNative] = useState(false)

  useEffect(() => {
    setIsNative(detectNative())
    init()
  }, [init])

  useEffect(() => {
    if (!initialized) return
    if (user) {
      router.replace('/dashboard')
    } else if (isNative) {
      router.replace('/auth?mode=login')
    }
  }, [initialized, user, isNative, router])

  // In der APK: immer dunklen Splash zeigen (nahtloser Übergang zum Login)
  if (isNative) {
    return <NativeSplash />
  }

  // Web – Loading-State während Auth initialisiert
  if (!initialized || loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white" role="status">
        <div className="flex flex-col items-center gap-4">
          <div
            className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-600 rounded-full animate-spin"
            aria-hidden="true"
          />
          <p className="text-sm text-gray-500 animate-pulse">Laden…</p>
          <span className="sr-only">Seite wird geladen</span>
        </div>
      </div>
    )
  }

  // Authenticated users are being redirected – show nothing
  if (user) {
    return null
  }

  // Web – unauthenticated visitors: full landing page
  return <LandingPage />
}

/**
 * Dunkler Vollbild-Splash mit Mensaena-Logo + Primärfarbe.
 * Matched den nativen Capacitor-Splash (`#0a1420`) für nahtlosen Übergang.
 */
function NativeSplash() {
  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-[#0a1420]"
      role="status"
      aria-live="polite"
    >
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage:
            'radial-gradient(circle at 50% 40%, rgba(30,170,166,0.22) 0%, transparent 55%)',
        }}
        aria-hidden="true"
      />
      <div className="relative flex flex-col items-center gap-6 animate-fade-in">
        <Image
          src="/mensaena-logo.png"
          alt="Mensaena Logo"
          width={112}
          height={112}
          priority
          className="drop-shadow-[0_0_24px_rgba(30,170,166,0.45)]"
        />
        <div
          className="w-8 h-8 border-[3px] border-primary-500/30 border-t-primary-400 rounded-full animate-spin"
          aria-hidden="true"
        />
      </div>
      <span className="sr-only">Mensaena wird geladen</span>
    </div>
  )
}
