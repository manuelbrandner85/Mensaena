'use client'

import { useEffect, useState } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { Menu, Bell, MessageCircle } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { useNavigationStore } from '@/store/useNavigationStore'
import Sidebar from './Sidebar'
import Topbar from './Topbar'
import Breadcrumbs from './Breadcrumbs'
import BottomNav from './BottomNav'
import MobileMenu from './MobileMenu'

/** Routes that don't get the navigation shell */
const PUBLIC_ROUTES = [
  '/',
  '/auth',
  '/login',
  '/register',
  '/agb',
  '/nutzungsbedingungen',
  '/datenschutz',
  '/impressum',
  '/haftungsausschluss',
  '/community-guidelines',
  '/kontakt',
  '/about',
]

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTES.some((route) => {
    if (route === '/') return pathname === '/'
    return pathname === route || pathname.startsWith(route + '/')
  })
}

interface UserData {
  id: string
  email: string
  displayName: string
  avatarUrl: string | null
  isAdmin: boolean
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const { sidebarCollapsed, toggleMobileMenu } = useNavigationStore()

  const [user, setUser] = useState<UserData | null>(null)
  const [loading, setLoading] = useState(true)
  const [unreadMessages, setUnreadMessages] = useState(0)
  const [unreadNotifications, setUnreadNotifications] = useState(0)

  const isPublic = isPublicRoute(pathname)

  useEffect(() => {
    if (isPublic) {
      setLoading(false)
      return
    }

    const supabase = createClient()

    const loadUser = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }

      const u = session.user
      const adminEmails = ['admin@mensaena.de', 'manuelbrandner85@gmail.com']

      // Fetch profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('name, nickname, avatar_url, role, email')
        .eq('id', u.id)
        .single()

      const isAdmin = profile?.role === 'admin'
        || adminEmails.includes(profile?.email ?? '')
        || adminEmails.includes(u.email ?? '')

      setUser({
        id: u.id,
        email: u.email ?? '',
        displayName: profile?.name || u.user_metadata?.full_name || u.email?.split('@')[0] || 'Nutzer',
        avatarUrl: profile?.avatar_url ?? null,
        isAdmin,
      })
      setLoading(false)
    }

    loadUser()

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!session?.user) {
        setUser(null)
        if (!isPublicRoute(pathname)) {
          router.replace('/auth?mode=login')
        }
      }
    })

    return () => subscription.unsubscribe()
  }, [isPublic, router, pathname])

  // Load unread counts
  useEffect(() => {
    if (!user) return
    const supabase = createClient()

    const loadCounts = async () => {
      // Unread notifications
      const { count: notifCount } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('read', false)
      setUnreadNotifications(notifCount ?? 0)

      // Unread messages
      const { data: convMembers } = await supabase
        .from('conversation_members')
        .select('conversation_id, last_read_at, conversations(type, messages(id, created_at, sender_id))')
        .eq('user_id', user.id)
      if (convMembers) {
        let total = 0
        for (const row of convMembers as any[]) {
          const c = row.conversations
          if (!c || c.type === 'system') continue
          const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
          total += (c.messages ?? []).filter(
            (m: any) => m.sender_id !== user.id && new Date(m.created_at).getTime() > lastRead
          ).length
        }
        setUnreadMessages(total)
      }
    }

    loadCounts()

    // Realtime for new notifications
    const channel = supabase
      .channel(`nav-notifs:${user.id}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${user.id}`,
      }, () => {
        setUnreadNotifications((prev) => prev + 1)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [user])

  // ── PUBLIC ROUTES: render children only ──
  if (isPublic) {
    return <>{children}</>
  }

  // ── LOADING STATE ──
  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-500 rounded-full animate-spin mx-auto mb-3" />
          <p className="text-sm text-gray-500 font-medium">Mensaena lädt…</p>
        </div>
      </div>
    )
  }

  // ── NOT LOGGED IN ──
  if (!user) return null

  // ── FULL APP SHELL ──
  return (
    <div className="min-h-screen bg-background relative">
      {/* ── Desktop Sidebar ── */}
      <Sidebar
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
        isAdmin={user.isAdmin}
      />

      {/* ── Mobile Top Bar ── */}
      <div
        className="lg:hidden fixed top-0 left-0 right-0 z-40 shadow-md"
        style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
      >
        <div className="flex items-center justify-between px-4 h-14">
          <Link href="/dashboard" className="flex items-center">
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              width={140}
              height={40}
              className="h-8 w-auto object-contain brightness-0 invert"
              priority
            />
          </Link>
          <div className="flex items-center gap-1">
            {unreadNotifications > 0 && (
              <Link
                href="/dashboard/notifications"
                className="relative p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all"
              >
                <Bell className="w-5 h-5" />
                <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-400 text-white text-[9px] font-bold rounded-full flex items-center justify-center shadow">
                  {unreadNotifications > 9 ? '9+' : unreadNotifications}
                </span>
              </Link>
            )}
            {unreadMessages > 0 && (
              <Link
                href="/dashboard/chat"
                className="relative p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all"
              >
                <MessageCircle className="w-5 h-5" />
                <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-400 text-white text-[9px] font-bold rounded-full flex items-center justify-center shadow">
                  {unreadMessages > 9 ? '9+' : unreadMessages}
                </span>
              </Link>
            )}
            <button
              onClick={toggleMobileMenu}
              className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all"
              aria-label="Menü öffnen"
            >
              <Menu className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* ── Mobile Menu ── */}
      <MobileMenu
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
        isAdmin={user.isAdmin}
        displayName={user.displayName}
        email={user.email}
      />

      {/* ── Content area ── */}
      <div
        className={cn(
          'transition-all duration-300 relative',
          sidebarCollapsed ? 'lg:pl-[68px]' : 'lg:pl-[260px]',
        )}
        style={{ zIndex: 1 }}
      >
        {/* Desktop Topbar */}
        <Topbar
          userId={user.id}
          displayName={user.displayName}
          email={user.email}
          avatarUrl={user.avatarUrl}
          isAdmin={user.isAdmin}
        />

        {/* Breadcrumbs (desktop only) */}
        <div className="hidden lg:block">
          <Breadcrumbs />
        </div>

        {/* Main content */}
        <main
          id="main-content"
          className="pt-14 lg:pt-0 pb-20 lg:pb-0 min-h-screen"
        >
          <div className="p-4 sm:p-6 lg:p-8 animate-slide-up">
            {children}
          </div>
        </main>
      </div>

      {/* ── Mobile Bottom Nav ── */}
      <BottomNav
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
      />
    </div>
  )
}
