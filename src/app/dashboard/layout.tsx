'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import Sidebar from '@/components/dashboard/Sidebar'
import DashboardTopbar from '@/components/dashboard/DashboardTopbar'
import type { User } from '@supabase/supabase-js'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()

    // Zuerst getSession() – sofort aus lokalem Storage (kein Netzwerk)
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        // Session vorhanden → User setzen, fertig
        setUser(session.user)
        setLoading(false)
      } else {
        // Keine lokale Session → zur Sicherheit getUser() prüfen (verifiziert Server-seitig)
        supabase.auth.getUser().then(({ data: { user: verifiedUser }, error }) => {
          if (error || !verifiedUser) {
            // Wirklich nicht eingeloggt → zu /login
            router.replace('/login')
          } else {
            setUser(verifiedUser)
          }
          setLoading(false)
        })
      }
    })

    // Auth-State-Listener: reagiert auf Login/Logout-Events in Echtzeit
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session) {
        setUser(session.user)
        setLoading(false)
      } else if (event === 'SIGNED_OUT') {
        setUser(null)
        router.replace('/login')
      } else if (event === 'TOKEN_REFRESHED') {
        if (session) {
          setUser(session.user)
        } else {
          setUser(null)
          router.replace('/login')
        }
      }
    })

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
    <div className="min-h-screen bg-background">
      <Sidebar />
      <div className="lg:pl-64 transition-all duration-300">
        <DashboardTopbar user={user} />
        <main className="pt-14 lg:pt-0 min-h-screen">
          <div className="p-4 sm:p-6 lg:p-8 animate-fade-in">
            {children}
          </div>
        </main>
      </div>
    </div>
  )
}
