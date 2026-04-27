'use client'

import { useEffect, useRef, useState } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { Menu, Bell, MessageCircle } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { useNavigationStore } from '@/store/useNavigationStore'
import { useAccessibilityStore } from '@/store/useAccessibilityStore'
import DashboardSidebar from '@/components/layout/DashboardSidebar'
import { useSidebarStore } from '@/store/useSidebarStore'
import Topbar from './Topbar'
import Breadcrumbs from './Breadcrumbs'
import MobileMenu from './MobileMenu'
import BottomNav from './BottomNav'
import { ScrollToTop } from '@/components/mobile'
import GlobalSOSButton from '@/app/dashboard/crisis/components/GlobalSOSButton'
import OnboardingTour from '@/components/shared/OnboardingTour'
import CommandPalette from '@/components/shared/CommandPalette'
import KeyboardShortcutsModal from '@/components/shared/KeyboardShortcutsModal'

// Module-level user cache — survives Next.js soft navigations.
// Cleared on sign-out so the next login gets fresh data.
let _userCache: { accessToken: string; data: UserData } | null = null

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
  const setMobileOpen = useSidebarStore((s) => s.setMobileOpen)
  const initA11y = useAccessibilityStore((s) => s.init)

  useEffect(() => { initA11y() }, [initA11y])

  // Initialise from module cache so returning users skip the loading spinner
  const [user, setUser] = useState<UserData | null>(() => _userCache?.data ?? null)
  const [loading, setLoading] = useState(!_userCache?.data)
  const [unreadMessages, setUnreadMessages] = useState(0)
  const [unreadNotifications, setUnreadNotifications] = useState(0)
  const [activeCrises, setActiveCrises] = useState(0)
  const [suggestedMatches, setSuggestedMatches] = useState(0)
  const [interactionRequests, setInteractionRequests] = useState(0)
  // Tracks conversation IDs the user belongs to so we only increment for relevant messages
  const userConvIdsRef = useRef<Set<string>>(new Set())

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

      // Cache hit — skip DB round-trip on route navigations
      if (_userCache?.accessToken === session.access_token) {
        setUser(_userCache.data)
        setLoading(false)
        return
      }

      const u = session.user
      const adminEmails = ['admin@mensaena.de', 'manuelbrandner85@gmail.com']

      // Fetch profile — 0 rows is legitimate (new user), so use maybeSingle
      const { data: profile, error: profileErr } = await supabase
        .from('profiles')
        .select('name, nickname, avatar_url, role, email')
        .eq('id', u.id)
        .maybeSingle()
      if (profileErr) console.error('AppShell profile query failed:', profileErr.message)

      const isAdmin = profile?.role === 'admin' || profile?.role === 'moderator'
        || adminEmails.includes(profile?.email ?? '')
        || adminEmails.includes(u.email ?? '')

      const userData: UserData = {
        id: u.id,
        email: u.email ?? '',
        displayName: profile?.name || u.user_metadata?.full_name || u.email?.split('@')[0] || 'Nutzer',
        avatarUrl: profile?.avatar_url ?? null,
        isAdmin,
      }
      _userCache = { accessToken: session.access_token, data: userData }
      setUser(userData)
      setLoading(false)
    }

    loadUser()

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!session?.user) {
        _userCache = null
        setUser(null)
        // On SIGNED_OUT: redirect to landing page, not auth
        if (event === 'SIGNED_OUT') {
          router.replace('/')
        } else if (!isPublicRoute(pathname)) {
          // Only redirect to auth if not a deliberate sign-out (e.g. token expired)
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

    // ── Re-fetch the notification badge from DB (handles read, delete, bulk ops) ──
    const refreshNotifCount = () => {
      supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('read', false)
        .is('deleted_at', null)
        .then(({ count }) => setUnreadNotifications(count ?? 0))
    }

    // ── Re-fetch message badge — also updates the conversation-ID set used by the
    //    realtime INSERT handler so we only count messages in the user's own convos ──
    const refreshMsgCount = async () => {
      const { data: rows } = await supabase
        .from('conversation_members')
        .select('conversation_id, last_read_at, conversations!inner(type)')
        .eq('user_id', user.id)
        .neq('conversations.type', 'system')

      if (!rows || rows.length === 0) { setUnreadMessages(0); return }

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const typedRows = rows as any[]
      const convIds = typedRows.map(r => r.conversation_id as string)
      userConvIdsRef.current = new Set(convIds)

      const minTs = typedRows.reduce((min: string, r) => {
        const ts = (r.last_read_at as string | null) || '1970-01-01T00:00:00Z'
        return ts < min ? ts : min
      }, '9999-12-31T00:00:00Z')

      const { data: msgs } = await supabase
        .from('messages')
        .select('conversation_id, created_at')
        .in('conversation_id', convIds)
        .neq('sender_id', user.id)
        .gt('created_at', minTs)

      if (msgs) {
        const convLastRead = new Map<string, string>(
          typedRows.map(r => [r.conversation_id as string, (r.last_read_at as string | null) || '1970-01-01T00:00:00Z'])
        )
        const total = msgs.filter(m => {
          const lr = convLastRead.get(m.conversation_id as string) ?? '1970-01-01T00:00:00Z'
          return (m.created_at as string) > lr
        }).length
        setUnreadMessages(total)
      }
    }

    const loadCounts = async () => {
      // Run parallel queries for notification count and crises
      const [notifRes, crisisRes] = await Promise.all([
        // Unread notifications — exclude soft-deleted rows
        supabase
          .from('notifications')
          .select('*', { count: 'exact', head: true })
          .eq('user_id', user.id)
          .eq('read', false)
          .is('deleted_at', null),
        // Active crises count (for red badge)
        supabase
          .from('crises')
          .select('*', { count: 'exact', head: true })
          .in('status', ['active', 'in_progress'])
          .in('urgency', ['critical', 'high']),
      ])

      setUnreadNotifications(notifRes.count ?? 0)
      setActiveCrises(crisisRes.count ?? 0)

      await refreshMsgCount()

      // Suggested matches count (table may not exist)
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const { count: matchCount } = await (supabase as any)
          .from('matches')
          .select('*', { count: 'exact', head: true })
          .or(`offer_user_id.eq.${user.id},request_user_id.eq.${user.id}`)
          .eq('status', 'suggested')
        setSuggestedMatches(matchCount ?? 0)
      } catch { /* matches table may not exist yet */ }

      // Interaction requests count (RPC may not exist)
      try {
        const { data: iCounts } = await supabase.rpc('get_interaction_counts', { p_user_id: user.id })
        if (iCounts) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const c = iCounts as any
          setInteractionRequests((c.requested ?? 0) + (c.awaiting_rating ?? 0))
        }
      } catch { /* interactions RPCs may not exist yet */ }
    }

    loadCounts()

    // Realtime subscriptions for badges + push dispatch
    const channel = supabase
      .channel(`nav-realtime:${user.id}`)

      // ── Notifications: INSERT → increment + dispatch toast/push/sound ──
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${user.id}`,
      }, (payload) => {
        setUnreadNotifications((prev) => prev + 1)
        try {
          const n = payload.new as Record<string, unknown>
          window.dispatchEvent(new CustomEvent('mensaena-notification', {
            detail: {
              id: n.id,
              title: n.title,
              content: n.content,
              category: n.category,
              link: n.link,
              actor_name: null,
              actor_avatar: null,
              created_at: n.created_at,
              read: false,
            },
          }))
        } catch { /* ignore dispatch errors */ }
      })

      // ── Notifications: UPDATE → re-fetch count (handles read, soft-delete, bulk RPCs) ──
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${user.id}`,
      }, () => {
        refreshNotifCount()
      })

      // ── Messages: INSERT → increment only for conversations the user is in ──
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
      }, (payload) => {
        const msg = payload.new as Record<string, unknown>
        if (
          msg.sender_id !== user.id &&
          userConvIdsRef.current.has(msg.conversation_id as string)
        ) {
          setUnreadMessages((prev) => prev + 1)
        }
      })

      // ── conversation_members: UPDATE → user read a convo → re-fetch message count ──
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'conversation_members',
        filter: `user_id=eq.${user.id}`,
      }, () => {
        void refreshMsgCount()
      })

      // ── Crises: any change → re-fetch crisis count ──
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'crises',
      }, () => {
        supabase
          .from('crises')
          .select('*', { count: 'exact', head: true })
          .in('status', ['active', 'in_progress'])
          .in('urgency', ['critical', 'high'])
          .then(({ count }) => setActiveCrises(count ?? 0))
      })

      // ── Interactions: any change → re-fetch interaction counts ──
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'interactions',
      }, () => {
        void (async () => {
          try {
            const { data: iCounts } = await supabase.rpc('get_interaction_counts', { p_user_id: user.id })
            if (iCounts) {
              const c = iCounts as { requested?: number; awaiting_rating?: number }
              setInteractionRequests((c.requested ?? 0) + (c.awaiting_rating ?? 0))
            }
          } catch { /* ignore */ }
        })()
      })

      .subscribe()

    return () => { supabase.removeChannel(channel) }
    // user.id (Primitive) statt user-Objekt → Effect re-runs nur bei tatsächlichem User-Wechsel
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id])

  // ── PUBLIC ROUTES: render children only ──
  if (isPublic) {
    return <>{children}</>
  }

  // ── LOADING STATE ──
  if (loading) {
    return (
      <div className="min-h-dvh bg-paper aurora-bg flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-500 rounded-full animate-spin mx-auto mb-3" />
          <p className="meta-label meta-label--subtle justify-center">Mensaena lädt</p>
        </div>
      </div>
    )
  }

  // ── NOT LOGGED IN ──
  if (!user) return null

  // ── FULL APP SHELL ──
  return (
    <div className="min-h-dvh bg-paper relative aurora-bg">
      {/* ── Sidebar (Desktop + Mobile Drawer) ── */}
      <DashboardSidebar
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
        activeCrises={activeCrises}
        isAdmin={user.isAdmin}
      />

      {/* ── Mobile Top Bar — editorial paper/ink treatment ── */}
      <div className="md:hidden fixed top-0 left-0 right-0 z-40 bg-paper/90 backdrop-blur-md border-b border-stone-200 safe-area-top">
        <div className="flex items-center justify-between px-3 h-14">
          <div className="flex items-center gap-2">
            <button
              onClick={() => setMobileOpen(true)}
              className="p-2 rounded-full hover:bg-stone-100 text-ink-800 transition-all touch-target"
              aria-label="Menü öffnen"
            >
              <Menu className="w-5 h-5" />
            </button>
            <Link href="/dashboard" className="flex items-center gap-2">
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                width={48}
                height={32}
                className="h-10 w-auto object-contain"
                priority
              />
            </Link>
          </div>
          <div className="flex items-center gap-0.5">
            <GlobalSOSButton />
            <Link
              href="/dashboard/notifications"
              className="relative p-2.5 rounded-full hover:bg-stone-100 text-ink-600 hover:text-primary-700 transition-all touch-target"
              aria-label="Benachrichtigungen"
            >
              <Bell className="w-5 h-5" />
              {unreadNotifications > 0 && (
                <span className="absolute top-1 right-1 min-w-[16px] h-4 bg-emergency-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5 shadow animate-badge-pop">
                  {unreadNotifications > 99 ? '99+' : unreadNotifications}
                </span>
              )}
            </Link>
            <Link
              href="/dashboard/messages"
              className="relative p-2.5 rounded-full hover:bg-stone-100 text-ink-600 hover:text-primary-700 transition-all touch-target"
              aria-label="Nachrichten"
            >
              <MessageCircle className="w-5 h-5" />
              {unreadMessages > 0 && (
                <span className="absolute top-1 right-1 min-w-[16px] h-4 bg-primary-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5 shadow animate-badge-pop">
                  {unreadMessages > 99 ? '99+' : unreadMessages}
                </span>
              )}
            </Link>
            <Link
              href="/dashboard/profile"
              className="p-1 rounded-full hover:bg-stone-100 transition-all touch-target ml-0.5"
              aria-label="Profil"
            >
              {user.avatarUrl ? (
                <img
                  src={user.avatarUrl}
                  alt={user.displayName}
                  className="w-7 h-7 rounded-full object-cover border border-stone-200"
                />
              ) : (
                <div className="w-7 h-7 rounded-full bg-primary-100 border border-stone-200 flex items-center justify-center text-primary-700 text-xs font-bold">
                  {user.displayName.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)}
                </div>
              )}
            </Link>
          </div>
        </div>
      </div>

      {/* ── Mobile Menu ── */}
      <MobileMenu
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
        activeCrises={activeCrises}
        suggestedMatches={suggestedMatches}
        interactionRequests={interactionRequests}
        isAdmin={user.isAdmin}
        displayName={user.displayName}
        email={user.email}
        avatarUrl={user.avatarUrl}
      />

      {/* ── Content area ── */}
      <div
        className={cn(
          'transition-all duration-300 relative',
          sidebarCollapsed ? 'md:pl-[68px]' : 'md:pl-[260px]',
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
          unreadMessages={unreadMessages}
        />

        {/* Breadcrumbs */}
        <div className="hidden md:block">
          <Breadcrumbs />
        </div>

        {/* Main content */}
        <main
          id="main-content"
          tabIndex={-1}
          className="pt-[60px] md:pt-0 pb-20 md:pb-4 min-h-dvh [overflow-x:clip]"
        >
          <div className="px-3 py-3 sm:p-6 lg:p-8 animate-slide-up w-full">
            {children}
          </div>
        </main>
      </div>

      {/* ── Mobile Bottom Navigation ── */}
      <BottomNav
        unreadMessages={unreadMessages}
        unreadNotifications={unreadNotifications}
        activeCrises={activeCrises}
        suggestedMatches={suggestedMatches}
        interactionRequests={interactionRequests}
      />

      {/* ── Scroll To Top ── */}
      <ScrollToTop />

      {/* ── Cinematic Onboarding Tour (first-time users) ── */}
      <OnboardingTour />

      {/* ── Command Palette (⌘K) ── */}
      <CommandPalette />


      {/* ── Keyboard Shortcuts Modal (?) ── */}
      <KeyboardShortcutsModal />

      {/* SOS button now rendered inline in the mobile header above */}
    </div>
  )
}
