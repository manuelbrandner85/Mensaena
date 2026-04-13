'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuthStore } from '@/store/useAuthStore'
import LandingPage from './landing/components/LandingPage'

/**
 * Root route – Auth-aware landing page.
 *
 * 1. Initialises the Zustand auth store (checks Supabase session).
 * 2. While loading → minimal primary spinner.
 * 3. If authenticated → redirect to /dashboard (never renders landing).
 * 4. If unauthenticated → render the full landing page.
 */
export default function HomePage() {
  const router = useRouter()
  const { user, loading, initialized, init } = useAuthStore()

  // Initialise auth on mount
  useEffect(() => {
    init()
  }, [init])

  // Redirect authenticated users
  useEffect(() => {
    if (initialized && user) {
      router.replace('/dashboard')
    }
  }, [initialized, user, router])

  // Loading state – minimal primary spinner
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

  // Unauthenticated visitors: full landing page
  return <LandingPage />
}
