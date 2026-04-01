'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import Sidebar from '@/components/dashboard/Sidebar'
import DashboardTopbar from '@/components/dashboard/DashboardTopbar'
import MensaenaBot from '@/components/bot/MensaenaBot'
import OfflineIndicator from '@/components/ui/OfflineIndicator'
import FloatingParticles from '@/components/ui/FloatingParticles'
import type { User } from '@supabase/supabase-js'

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [user, setUser]       = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()

    // Session sofort aus localStorage lesen (kein Netzwerk)
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setUser(session.user)
        setLoading(false)
      } else {
        // Nicht eingeloggt → zum Login
        router.replace('/login')
      }
    })

    // Reagiert auf Login/Logout in anderen Tabs
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        setUser(session.user)
        setLoading(false)
      } else {
        setUser(null)
        router.replace('/login')
      }
    })

    // Register service worker for push notifications + offline support
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(() => {})
    }

    return () => subscription.unsubscribe()
  }, [router])

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-600 rounded-full animate-spin mx-auto mb-3" />
          <p className="text-sm text-gray-500 font-medium">Mensaena lädt…</p>
        </div>
      </div>
    )
  }

  if (!user) return null

  return (
    <div className="min-h-screen bg-background relative">
      {/* Floating ambient particles */}
      <FloatingParticles />
      {/* Subtle dot-grid overlay */}
      <div className="bg-dots fixed inset-0 pointer-events-none" style={{ zIndex: 0 }} aria-hidden="true" />

      <Sidebar />
      <div className="lg:pl-64 transition-all duration-300 relative" style={{ zIndex: 1 }}>
        <DashboardTopbar user={user} />
        <main className="pt-14 lg:pt-0 min-h-screen">
          <div className="p-4 sm:p-6 lg:p-8 animate-slide-up">
            {children}
          </div>
        </main>
      </div>
      {/* Bot nur im eingeloggten Bereich */}
      <MensaenaBot />
      {/* Offline Indicator */}
      <OfflineIndicator />
    </div>
  )
}
