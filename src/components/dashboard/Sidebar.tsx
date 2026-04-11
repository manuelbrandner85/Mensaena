'use client'

import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useRouter } from 'next/navigation'
import { useState, useEffect } from 'react'
import {
  LayoutDashboard, Map, FilePlus, FileText, MessageCircle, ShieldAlert, PawPrint,
  Home, Wheat, BookOpen, Brain, Wrench, Car, Shuffle, Users, Siren,
  User, Settings, LogOut, ChevronLeft, ChevronRight, Bell, Menu, X,
  Clock, Sprout, Zap, CalendarDays, Building2, HandCoins, Phone,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'

// ── Navigationsstruktur – logisch nach Priorität & Thema geordnet ──────────
const navSections = [
  {
    label: 'Notfall & Krise',
    items: [
      {
        href: '/dashboard/crisis',
        label: 'Krisensystem',
        icon: Siren,
        iconBg: 'bg-red-500',
        activeBg: 'bg-red-50',
        activeText: 'text-red-700',
        activeBorder: 'border-red-400',
        crisis: true,
      },
      {
        href: '/dashboard/organizations',
        label: 'Hilfsorganisationen',
        icon: Building2,
        iconBg: 'bg-rose-500',
        activeBg: 'bg-rose-50',
        activeText: 'text-rose-700',
        activeBorder: 'border-rose-400',
      },
      {
        href: '/dashboard/rescuer',
        label: 'Retter-System',
        icon: ShieldAlert,
        iconBg: 'bg-orange-500',
        activeBg: 'bg-orange-50',
        activeText: 'text-orange-700',
        activeBorder: 'border-orange-400',
      },
      {
        href: '/dashboard/mental-support',
        label: 'Mentale Unterstützung',
        icon: Brain,
        iconBg: 'bg-cyan-500',
        activeBg: 'bg-cyan-50',
        activeText: 'text-cyan-700',
        activeBorder: 'border-cyan-400',
      },
    ],
  },
  {
    label: 'Übersicht & Kommunikation',
    items: [
      {
        href: '/dashboard',
        label: 'Dashboard',
        icon: LayoutDashboard,
        iconBg: 'bg-teal-500',
        activeBg: 'bg-teal-50',
        activeText: 'text-teal-700',
        activeBorder: 'border-teal-400',
      },
      {
        href: '/dashboard/map',
        label: 'Karte',
        icon: Map,
        iconBg: 'bg-blue-500',
        activeBg: 'bg-blue-50',
        activeText: 'text-blue-700',
        activeBorder: 'border-blue-400',
      },
      {
        href: '/dashboard/chat',
        label: 'Chat',
        icon: MessageCircle,
        iconBg: 'bg-pink-500',
        activeBg: 'bg-pink-50',
        activeText: 'text-pink-700',
        activeBorder: 'border-pink-400',
      },
      {
        href: '/dashboard/calendar',
        label: 'Kalender',
        icon: CalendarDays,
        iconBg: 'bg-fuchsia-500',
        activeBg: 'bg-fuchsia-50',
        activeText: 'text-fuchsia-700',
        activeBorder: 'border-fuchsia-400',
      },
      {
        href: '/dashboard/create',
        label: 'Beitrag erstellen',
        icon: FilePlus,
        iconBg: 'bg-emerald-500',
        activeBg: 'bg-emerald-50',
        activeText: 'text-emerald-700',
        activeBorder: 'border-emerald-400',
        highlight: true,
      },
      {
        href: '/dashboard/posts',
        label: 'Alle Beiträge',
        icon: FileText,
        iconBg: 'bg-violet-500',
        activeBg: 'bg-violet-50',
        activeText: 'text-violet-700',
        activeBorder: 'border-violet-400',
      },
    ],
  },
  {
    label: 'Versorgung & Alltag',
    items: [
      {
        href: '/dashboard/supply',
        label: 'Regionale Versorgung',
        icon: Wheat,
        iconBg: 'bg-yellow-600',
        activeBg: 'bg-yellow-50',
        activeText: 'text-yellow-700',
        activeBorder: 'border-yellow-400',
      },
      {
        href: '/dashboard/harvest',
        label: 'Erntehilfe',
        icon: Sprout,
        iconBg: 'bg-green-600',
        activeBg: 'bg-green-50',
        activeText: 'text-green-700',
        activeBorder: 'border-green-400',
      },
      {
        href: '/dashboard/housing',
        label: 'Wohnen & Alltag',
        icon: Home,
        iconBg: 'bg-lime-600',
        activeBg: 'bg-lime-50',
        activeText: 'text-lime-700',
        activeBorder: 'border-lime-400',
      },
      {
        href: '/dashboard/animals',
        label: 'Tiere',
        icon: PawPrint,
        iconBg: 'bg-amber-500',
        activeBg: 'bg-amber-50',
        activeText: 'text-amber-700',
        activeBorder: 'border-amber-400',
      },
      {
        href: '/dashboard/mobility',
        label: 'Mobilität & Fahrten',
        icon: Car,
        iconBg: 'bg-sky-500',
        activeBg: 'bg-sky-50',
        activeText: 'text-sky-700',
        activeBorder: 'border-sky-400',
      },
    ],
  },
  {
    label: 'Gemeinschaft & Netzwerk',
    items: [
      {
        href: '/dashboard/community',
        label: 'Community',
        icon: Users,
        iconBg: 'bg-violet-600',
        activeBg: 'bg-violet-50',
        activeText: 'text-violet-700',
        activeBorder: 'border-violet-400',
      },
      {
        href: '/dashboard/skills',
        label: 'Skill-Netzwerk',
        icon: Wrench,
        iconBg: 'bg-purple-500',
        activeBg: 'bg-purple-50',
        activeText: 'text-purple-700',
        activeBorder: 'border-purple-400',
      },
      {
        href: '/dashboard/timebank',
        label: 'Zeitbank',
        icon: Clock,
        iconBg: 'bg-rose-500',
        activeBg: 'bg-rose-50',
        activeText: 'text-rose-700',
        activeBorder: 'border-rose-400',
      },
      {
        href: '/dashboard/sharing',
        label: 'Teilen & Tauschen',
        icon: Shuffle,
        iconBg: 'bg-teal-600',
        activeBg: 'bg-teal-50',
        activeText: 'text-teal-700',
        activeBorder: 'border-teal-400',
      },
      {
        href: '/dashboard/knowledge',
        label: 'Bildung & Wissen',
        icon: BookOpen,
        iconBg: 'bg-indigo-500',
        activeBg: 'bg-indigo-50',
        activeText: 'text-indigo-700',
        activeBorder: 'border-indigo-400',
      },
    ],
  },
]

type NavItem = {
  href: string
  label: string
  icon: React.ComponentType<{ className?: string }>
  iconBg: string
  activeBg: string
  activeText: string
  activeBorder: string
  badge?: string
  highlight?: boolean
  crisis?: boolean
}

export default function Sidebar() {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)
  const [collapsed, setCollapsed] = useState(false)
  const [notifCount, setNotifCount] = useState(0)
  const [dmUnreadCount, setDmUnreadCount] = useState(0)
  const [isAdmin, setIsAdmin] = useState(false)

  useEffect(() => { setMobileOpen(false) }, [pathname])

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      // Notifications
      const { data: myPosts } = await supabase.from('posts').select('id').eq('user_id', user.id).eq('status', 'active')
      if (myPosts && myPosts.length > 0) {
        const { count } = await supabase.from('interactions').select('*', { count: 'exact', head: true })
          .in('post_id', myPosts.map(p => p.id)).eq('status', 'interested')
        setNotifCount(count ?? 0)
      }

      // Check admin role
      const adminEmails = ['admin@mensaena.de', 'manuelbrandner85@gmail.com']
      const { data: profile } = await supabase.from('profiles').select('role, email').eq('id', user.id).single()
      const isAdminUser = profile?.role === 'admin' || adminEmails.includes(profile?.email ?? '') || adminEmails.includes(user.email ?? '')
      setIsAdmin(isAdminUser)
    }

    const loadDm = async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data } = await supabase.from('conversation_members')
        .select('conversation_id, last_read_at, conversations(type, messages(id, created_at, sender_id))')
        .eq('user_id', user.id)
      if (!data) return
      let total = 0
      for (const row of data as any[]) {
        const c = row.conversations
        if (!c || c.type === 'system') continue
        const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
        total += (c.messages ?? []).filter((m: any) => m.sender_id !== user.id && new Date(m.created_at).getTime() > lastRead).length
      }
      setDmUnreadCount(total)
    }
    load(); loadDm()
  }, [pathname])

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success('Erfolgreich abgemeldet')
    window.location.href = '/'
  }

  const isActive = (href: string) => {
    if (href === '/dashboard') return pathname === '/dashboard'
    return pathname.startsWith(href)
  }

  return (
    <>
      {/* ── Mobile Topbar ── */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-40 shadow-lg"
        style={{ background: 'linear-gradient(135deg, #0f766e 0%, #0d9488 40%, #0891b2 100%)' }}>
        <div className="flex items-center justify-between px-4 h-16">
          <Link href="/dashboard" className="flex items-center">
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              width={180}
              height={56}
              className="h-10 w-auto object-contain brightness-0 invert"
              priority
            />
          </Link>
          <div className="flex items-center gap-1">
            {notifCount > 0 && (
              <Link href="/dashboard/posts" className="relative p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all">
                <Bell className="w-5 h-5" />
                <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-400 text-white text-[9px] font-bold rounded-full flex items-center justify-center shadow">{notifCount > 9 ? '9+' : notifCount}</span>
              </Link>
            )}
            {dmUnreadCount > 0 && (
              <Link href="/dashboard/chat" className="relative p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all">
                <MessageCircle className="w-5 h-5" />
                <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-400 text-white text-[9px] font-bold rounded-full flex items-center justify-center shadow">{dmUnreadCount > 9 ? '9+' : dmUnreadCount}</span>
              </Link>
            )}
            <button onClick={() => setMobileOpen(true)} className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all">
              <Menu className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* ── Mobile Overlay ── */}
      {mobileOpen && (
        <div className="lg:hidden fixed inset-0 z-50 bg-black/60 backdrop-blur-sm" onClick={() => setMobileOpen(false)} />
      )}

      {/* ── Mobile Drawer ── */}
      <div className={cn(
        'lg:hidden fixed top-0 left-0 bottom-0 z-50 w-[272px] shadow-2xl transition-transform duration-300 ease-out',
        mobileOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        <SidebarInner
          isActive={isActive} collapsed={false}
          notifCount={notifCount} dmUnreadCount={dmUnreadCount}
          onLogout={handleLogout} showClose onClose={() => setMobileOpen(false)}
          isAdmin={isAdmin}
        />
      </div>

      {/* ── Desktop Sidebar ── */}
      <aside className={cn(
        'hidden lg:flex flex-col fixed top-0 left-0 bottom-0 z-30 transition-all duration-300 ease-out shadow-xl',
        collapsed ? 'w-[68px]' : 'w-[240px]'
      )}>
        <SidebarInner
          isActive={isActive} collapsed={collapsed}
          notifCount={notifCount} dmUnreadCount={dmUnreadCount}
          onLogout={handleLogout} onToggleCollapse={() => setCollapsed(c => !c)}
          isAdmin={isAdmin}
        />
      </aside>
    </>
  )
}

// ── Inner Sidebar ────────────────────────────────────────────────────────────
function SidebarInner({
  isActive, collapsed, notifCount, dmUnreadCount,
  onLogout, onToggleCollapse, showClose, onClose, isAdmin,
}: {
  isActive: (href: string) => boolean
  collapsed: boolean
  notifCount: number
  dmUnreadCount: number
  onLogout: () => void
  onToggleCollapse?: () => void
  showClose?: boolean
  onClose?: () => void
  isAdmin?: boolean
}) {
  return (
    <div className="flex flex-col h-full overflow-hidden bg-white border-r border-gray-100">

      {/* ── Logo Header ── */}
      <div className={cn(
        'relative flex items-center flex-shrink-0 overflow-hidden',
        collapsed ? 'h-[72px] justify-center px-2' : 'h-[92px] px-5'
      )} style={{ background: 'linear-gradient(135deg, #0f766e 0%, #0d9488 50%, #0891b2 100%)' }}>
        {/* Decorative shapes */}
        <div className="absolute -top-8 -right-8 w-28 h-28 bg-white/8 rounded-full pointer-events-none" />
        <div className="absolute -bottom-10 -left-6 w-24 h-24 bg-white/5 rounded-full pointer-events-none" />

        <Link href="/dashboard" className="relative flex items-center gap-2 flex-1 min-w-0">
          {collapsed ? (
            <div className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center border border-white/30 shadow-sm">
              <span className="text-white font-black text-base">M</span>
            </div>
          ) : (
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              width={210}
              height={70}
              className="h-14 w-auto object-contain brightness-0 invert drop-shadow-sm"
              priority
            />
          )}
        </Link>

        {showClose && (
          <button onClick={onClose} className="relative p-1.5 rounded-lg bg-white/15 hover:bg-white/25 text-white transition-all flex-shrink-0 ml-2">
            <X className="w-4 h-4" />
          </button>
        )}
        {onToggleCollapse && (
          <button onClick={onToggleCollapse} className="relative p-1.5 rounded-lg bg-white/15 hover:bg-white/25 text-white transition-all flex-shrink-0 ml-2">
            {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
          </button>
        )}
      </div>

      {/* ── Status / Action Strip ── */}
      {!collapsed && (
        <div className="px-3 py-2 flex gap-2 bg-gray-50 border-b border-gray-100">
          {notifCount > 0 ? (
            <Link href="/dashboard/posts"
              className="flex-1 flex items-center gap-1.5 px-2.5 py-1.5 bg-amber-50 border border-amber-200 rounded-xl hover:bg-amber-100 transition-all group">
              <Bell className="w-3.5 h-3.5 text-amber-600 flex-shrink-0" />
              <span className="text-xs font-semibold text-amber-800 truncate flex-1">{notifCount} Reaktion{notifCount > 1 ? 'en' : ''}</span>
              <span className="w-4 h-4 bg-amber-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center flex-shrink-0">
                {notifCount > 9 ? '9+' : notifCount}
              </span>
            </Link>
          ) : (
            <div className="flex-1 flex items-center gap-2 px-2.5 py-1.5 bg-emerald-50 border border-emerald-100 rounded-xl">
              <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse flex-shrink-0" />
              <span className="text-xs text-emerald-700 font-medium">Online & aktiv</span>
            </div>
          )}
          <Link href="/dashboard/crisis"
            className="flex items-center gap-1.5 px-2.5 py-1.5 bg-red-50 border border-red-200 rounded-xl hover:bg-red-100 transition-all group flex-shrink-0">
            <Zap className="w-3.5 h-3.5 text-red-500 group-hover:scale-110 transition-transform" />
            <span className="text-xs font-bold text-red-700">SOS</span>
          </Link>
        </div>
      )}

      {/* ── Navigation ── */}
      <nav className="flex-1 overflow-y-auto py-2 px-2" style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}>
        {navSections.map((section, si) => (
          <div key={section.label} className={cn('mb-1', si > 0 && 'mt-2')}>
            {/* Section header */}
            {!collapsed ? (
              <div className="flex items-center gap-2 px-2 py-1 mb-0.5">
                <span className="text-[10px] font-black uppercase tracking-wider text-gray-400 select-none">{section.label}</span>
                <div className="flex-1 h-px bg-gradient-to-r from-gray-200 to-transparent" />
              </div>
            ) : (
              si > 0 && <div className="my-1.5 mx-2 h-px bg-gray-100" />
            )}

            {section.items.map((item: NavItem) => {
              const Icon = item.icon
              const active = isActive(item.href)
              const dmBadge = item.href === '/dashboard/chat' && dmUnreadCount > 0

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  title={collapsed ? item.label : undefined}
                  className={cn(
                    'group relative flex items-center rounded-xl mb-0.5 transition-all duration-200 select-none overflow-hidden',
                    collapsed ? 'h-10 w-10 mx-auto justify-center' : 'gap-3 px-2.5 py-2',
                    active
                      ? cn('font-semibold', item.activeBg, item.activeText, 'border', item.activeBorder, 'shadow-sm')
                      : cn(
                          'text-gray-600 border border-transparent hover:bg-gray-50 hover:text-gray-900',
                          item.highlight && 'bg-gradient-to-r from-emerald-50 to-teal-50 border-emerald-200 hover:from-emerald-100 hover:to-teal-100 text-emerald-700 font-semibold'
                        ),
                  )}
                >
                  {/* Left accent bar when active */}
                  {active && !collapsed && (
                    <div className="absolute left-0 top-2 bottom-2 w-0.5 rounded-r-full bg-current opacity-70" />
                  )}

                  {/* Crisis pulse ring */}
                  {item.crisis && !active && !collapsed && (
                    <span className="absolute right-2 top-1/2 -translate-y-1/2 w-1.5 h-1.5 bg-red-400 rounded-full animate-pulse" />
                  )}

                  {/* Icon with colored background */}
                  <div className={cn(
                    'flex-shrink-0 rounded-lg flex items-center justify-center transition-all duration-200',
                    collapsed ? 'w-8 h-8' : 'w-7 h-7',
                    active
                      ? cn(item.iconBg, 'shadow-sm scale-110')
                      : cn('bg-gray-100 group-hover:scale-105', 'group-hover:' + item.iconBg.replace('bg-', 'bg-'))
                  )}>
                    <Icon className={cn(
                      'transition-all duration-200',
                      collapsed ? 'w-4 h-4' : 'w-3.5 h-3.5',
                      active ? 'text-white' : cn('text-gray-500', 'group-hover:text-white')
                    )} />
                  </div>

                  {!collapsed && (
                    <span className="truncate flex-1 text-[13px] leading-tight">{item.label}</span>
                  )}

                  {/* DM Badge */}
                  {dmBadge && (
                    <span className={cn(
                      'font-bold bg-red-500 text-white rounded-full flex items-center justify-center flex-shrink-0 shadow-sm',
                      collapsed ? 'absolute -top-1 -right-1 w-4 h-4 text-[9px]' : 'w-5 h-5 text-[10px]'
                    )}>
                      {dmUnreadCount > 9 ? '9+' : dmUnreadCount}
                    </span>
                  )}
                </Link>
              )
            })}
          </div>
        ))}

        {/* Admin-Bereich – nur für Admins sichtbar */}
        {isAdmin && (
          <div className="mt-2">
            {!collapsed ? (
              <div className="flex items-center gap-2 px-2 py-1 mb-0.5">
                <span className="text-[10px] font-black uppercase tracking-wider text-gray-400 select-none">Administration</span>
                <div className="flex-1 h-px bg-gradient-to-r from-gray-200 to-transparent" />
              </div>
            ) : (
              <div className="my-1.5 mx-2 h-px bg-gray-100" />
            )}
            <Link
              href="/dashboard/admin"
              title={collapsed ? 'Admin' : undefined}
              className={cn(
                'group relative flex items-center rounded-xl mb-0.5 transition-all duration-200 select-none overflow-hidden',
                collapsed ? 'h-10 w-10 mx-auto justify-center' : 'gap-3 px-2.5 py-2',
                isActive('/dashboard/admin')
                  ? 'font-semibold bg-slate-50 text-slate-700 border border-slate-400 shadow-sm'
                  : 'text-gray-600 border border-transparent hover:bg-gray-50 hover:text-gray-900',
              )}
            >
              <div className={cn(
                'flex-shrink-0 rounded-lg flex items-center justify-center transition-all duration-200',
                collapsed ? 'w-8 h-8' : 'w-7 h-7',
                isActive('/dashboard/admin')
                  ? 'bg-slate-500 shadow-sm scale-110'
                  : 'bg-gray-100 group-hover:scale-105 group-hover:bg-slate-500'
              )}>
                <Settings className={cn(
                  'transition-all duration-200',
                  collapsed ? 'w-4 h-4' : 'w-3.5 h-3.5',
                  isActive('/dashboard/admin') ? 'text-white' : 'text-gray-500 group-hover:text-white'
                )} />
              </div>
              {!collapsed && <span className="truncate flex-1 text-[13px] leading-tight">Admin-Bereich</span>}
            </Link>
          </div>
        )}
      </nav>

      {/* ── Bottom User Section ── */}
      <div className="flex-shrink-0 border-t border-gray-100">
        {!collapsed && (
          <div className="px-3 py-2">
            <Link href="/dashboard/profile"
              className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl hover:bg-teal-50 hover:border-teal-200 border border-transparent transition-all group">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-teal-400 to-teal-600 flex items-center justify-center flex-shrink-0 shadow-sm">
                <User className="w-3.5 h-3.5 text-white" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-gray-800 truncate group-hover:text-teal-700 transition-colors">Mein Profil</p>
                <p className="text-[10px] text-gray-400">Profil anzeigen →</p>
              </div>
            </Link>
          </div>
        )}

        <div className={cn('px-2 pb-3 space-y-0.5', collapsed && 'flex flex-col items-center')}>
          {collapsed && (
            <Link href="/dashboard/profile" title="Mein Profil"
              className="w-10 h-10 flex items-center justify-center rounded-xl hover:bg-teal-50 transition-all border border-transparent hover:border-teal-200">
              <User className="w-4 h-4 text-teal-600" />
            </Link>
          )}
          <Link href="/dashboard/settings"
            title={collapsed ? 'Einstellungen' : undefined}
            className={cn(
              'flex items-center gap-2.5 rounded-xl text-[13px] font-medium text-gray-500 hover:bg-gray-50 hover:text-gray-800 border border-transparent transition-all',
              collapsed ? 'w-10 h-10 justify-center mx-auto' : 'px-3 py-2'
            )}>
            <Settings className={cn('flex-shrink-0 text-gray-400', collapsed ? 'w-4 h-4' : 'w-3.5 h-3.5')} />
            {!collapsed && <span>Einstellungen</span>}
          </Link>
          <button onClick={onLogout}
            title={collapsed ? 'Abmelden' : undefined}
            className={cn(
              'w-full flex items-center gap-2.5 rounded-xl text-[13px] font-medium text-gray-500 hover:bg-red-50 hover:text-red-600 border border-transparent hover:border-red-100 transition-all',
              collapsed ? 'h-10 justify-center' : 'px-3 py-2'
            )}>
            <LogOut className={cn('flex-shrink-0', collapsed ? 'w-4 h-4' : 'w-3.5 h-3.5')} />
            {!collapsed && <span>Abmelden</span>}
          </button>
        </div>
      </div>
    </div>
  )
}
