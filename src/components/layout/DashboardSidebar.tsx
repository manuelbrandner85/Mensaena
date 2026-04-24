'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { usePathname } from 'next/navigation'
import {
  Plus, ChevronDown, LogOut, Heart, X,
  LayoutDashboard, User, MessageCircle, Bell, Settings,
  FileText, Repeat, Store, Clock, Wrench, Sparkles,
  Map, Calendar, Users, StickyNote, Users2, Building2,
  AlertTriangle, PawPrint, Brain, LifeBuoy, Package,
  Home, Car, Wheat, BookOpen, Trophy, Award, ShieldCheck,
  type LucideIcon,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { useSidebarStore } from '@/store/useSidebarStore'

// ── Nav config ────────────────────────────────────────────────────────────────

interface NavItem {
  id: string
  label: string
  path: string
  icon: LucideIcon
  badge?: number
}

interface NavGroup {
  id: string
  label: string
  items: NavItem[]
}

function buildGroups(unreadMessages: number, unreadNotifications: number, activeCrises: number): NavGroup[] {
  return [
    {
      id: 'personal',
      label: '🏠 Mein Bereich',
      items: [
        { id: 'dashboard',      label: 'Dashboard',           path: '/dashboard',                icon: LayoutDashboard },
        { id: 'profile',        label: 'Profil',              path: '/dashboard/profile',        icon: User },
        { id: 'chat',           label: 'Nachrichten',         path: '/dashboard/chat',           icon: MessageCircle, badge: unreadMessages },
        { id: 'notifications',  label: 'Benachrichtigungen',  path: '/dashboard/notifications',  icon: Bell, badge: unreadNotifications },
        { id: 'settings',       label: 'Einstellungen',       path: '/dashboard/settings',       icon: Settings },
      ],
    },
    {
      id: 'help',
      label: '🤝 Helfen & Teilen',
      items: [
        { id: 'posts',       label: 'Beiträge',       path: '/dashboard/posts',       icon: FileText },
        { id: 'sharing',     label: 'Teilen & Tauschen', path: '/dashboard/sharing',  icon: Repeat },
        { id: 'marketplace', label: 'Marktplatz',     path: '/dashboard/marketplace', icon: Store },
        { id: 'timebank',    label: 'Zeitbank',        path: '/dashboard/timebank',   icon: Clock },
        { id: 'skills',      label: 'Skills',          path: '/dashboard/skills',     icon: Wrench },
        { id: 'matching',    label: 'Matching',        path: '/dashboard/matching',   icon: Sparkles },
      ],
    },
    {
      id: 'community',
      label: '🌍 Nachbarschaft',
      items: [
        { id: 'map',           label: 'Karte',          path: '/dashboard/map',           icon: Map },
        { id: 'events',        label: 'Events',          path: '/dashboard/events',        icon: Calendar },
        { id: 'groups',        label: 'Gruppen',         path: '/dashboard/groups',        icon: Users },
        { id: 'board',         label: 'Pinnwand',        path: '/dashboard/board',         icon: StickyNote },
        { id: 'community',     label: 'Community',       path: '/dashboard/community',     icon: Users2 },
        { id: 'organizations', label: 'Organisationen',  path: '/dashboard/organizations', icon: Building2 },
        { id: 'calendar',      label: 'Kalender',        path: '/dashboard/calendar',      icon: Calendar },
      ],
    },
    {
      id: 'emergency',
      label: '🆘 Notfall & Fürsorge',
      items: [
        { id: 'crisis',         label: 'Krisenhilfe',         path: '/dashboard/crisis',          icon: AlertTriangle, badge: activeCrises },
        { id: 'animals',        label: 'Tierhilfe',           path: '/dashboard/animals',         icon: PawPrint },
        { id: 'mental-support', label: 'Seelische Unterstützung', path: '/dashboard/mental-support', icon: Brain },
        { id: 'rescuer',        label: 'Retter',              path: '/dashboard/rescuer',         icon: LifeBuoy },
        { id: 'supply',         label: 'Versorgung',          path: '/dashboard/supply',          icon: Package },
      ],
    },
    {
      id: 'living',
      label: '🌿 Wohnen & Leben',
      items: [
        { id: 'housing',    label: 'Wohnen',      path: '/dashboard/housing',    icon: Home },
        { id: 'mobility',   label: 'Mobilität',   path: '/dashboard/mobility',   icon: Car },
        { id: 'harvest',    label: 'Ernte',        path: '/dashboard/harvest',    icon: Wheat },
        { id: 'knowledge',  label: 'Wissen',       path: '/dashboard/knowledge',  icon: BookOpen },
        { id: 'wiki',       label: 'Wiki',         path: '/dashboard/wiki',       icon: BookOpen },
        { id: 'challenges', label: 'Challenges',   path: '/dashboard/challenges', icon: Trophy },
        { id: 'badges',     label: 'Badges',       path: '/dashboard/badges',     icon: Award },
      ],
    },
  ]
}

// ── Props ─────────────────────────────────────────────────────────────────────

interface DashboardSidebarProps {
  unreadMessages?: number
  unreadNotifications?: number
  activeCrises?: number
  isAdmin?: boolean
}

// ── Group component ───────────────────────────────────────────────────────────

function SidebarGroup({ group, pathname }: { group: NavGroup; pathname: string }) {
  const { openGroups, toggleGroup, openGroup } = useSidebarStore()
  const isOpen = openGroups.includes(group.id)

  const hasActive = group.items.some(
    (item) => pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
  )

  // Auto-open the group containing the active route
  useEffect(() => {
    if (hasActive) openGroup(group.id)
  }, [pathname]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="mb-1">
      <button
        onClick={() => toggleGroup(group.id)}
        className={cn(
          'w-full flex items-center justify-between px-3 py-1.5 rounded-lg text-left transition-colors',
          hasActive ? 'text-primary-700' : 'text-stone-500 hover:text-stone-700 hover:bg-stone-50',
        )}
      >
        <span className={cn(
          'text-xs font-semibold uppercase tracking-wider select-none',
        )}>
          {group.label}
        </span>
        <ChevronDown className={cn(
          'w-3.5 h-3.5 flex-shrink-0 transition-transform duration-200',
          isOpen ? 'rotate-0' : '-rotate-90',
        )} />
      </button>

      <div className={cn(
        'overflow-hidden transition-all duration-200 ease-out',
        isOpen ? 'max-h-[600px] opacity-100 mt-0.5' : 'max-h-0 opacity-0',
      )}>
        <ul className="space-y-0.5 px-1">
          {group.items.map((item) => {
            const Icon = item.icon
            const active = pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
            return (
              <li key={item.id}>
                <Link
                  href={item.path}
                  className={cn(
                    'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors relative',
                    active
                      ? 'bg-primary-50 text-primary-700 font-medium border-l-2 border-primary-500 pl-[10px]'
                      : 'text-stone-600 hover:bg-stone-50 hover:text-stone-900',
                  )}
                >
                  <Icon className={cn('w-4 h-4 flex-shrink-0', active ? 'text-primary-600' : 'text-stone-400')} />
                  <span className="flex-1 truncate">{item.label}</span>
                  {item.badge !== undefined && item.badge > 0 && (
                    <span className="min-w-[18px] h-[18px] bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1">
                      {item.badge > 99 ? '99+' : item.badge}
                    </span>
                  )}
                </Link>
              </li>
            )
          })}
        </ul>
      </div>
    </div>
  )
}

// ── Main component ────────────────────────────────────────────────────────────

export default function DashboardSidebar({
  unreadMessages = 0,
  unreadNotifications = 0,
  activeCrises = 0,
  isAdmin = false,
}: DashboardSidebarProps) {
  const pathname = usePathname()
  const { mobileOpen, setMobileOpen } = useSidebarStore()
  const groups = buildGroups(unreadMessages, unreadNotifications, activeCrises)

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success('Erfolgreich abgemeldet')
    window.location.href = '/'
  }

  const inner = (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="flex items-center gap-2.5 px-4 h-16 border-b border-stone-200 flex-shrink-0">
        <Link href="/dashboard" className="flex items-center gap-2.5 flex-1 min-w-0" onClick={() => setMobileOpen(false)}>
          <Image src="/mensaena-logo.png" alt="Mensaena" width={48} height={32} className="h-10 w-auto object-contain" priority />
          <span className="font-display text-[1.2rem] font-medium text-ink-800 tracking-tight truncate">
            Mensaena<span className="text-primary-500">.</span>
          </span>
        </Link>
        {/* Mobile close button */}
        <button
          onClick={() => setMobileOpen(false)}
          className="md:hidden p-1.5 rounded-full hover:bg-stone-100 text-stone-500"
          aria-label="Menü schließen"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Create button */}
      <div className="px-3 py-3 flex-shrink-0">
        <Link
          href="/dashboard/create"
          onClick={() => setMobileOpen(false)}
          className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl bg-primary-600 text-white text-sm font-semibold hover:bg-primary-700 transition-colors shadow-sm"
        >
          <Plus className="w-4 h-4" />
          Beitrag erstellen
        </Link>
      </div>

      {/* Groups */}
      <nav className="flex-1 overflow-y-auto py-2 px-2 no-scrollbar">
        {groups.map((group) => (
          <SidebarGroup key={group.id} group={group} pathname={pathname} />
        ))}

        {/* Admin */}
        {isAdmin && (
          <div className="mt-2 pt-2 border-t border-stone-200">
            <Link
              href="/dashboard/admin"
              onClick={() => setMobileOpen(false)}
              className={cn(
                'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors',
                pathname.startsWith('/dashboard/admin')
                  ? 'bg-primary-50 text-primary-700 font-medium border-l-2 border-primary-500 pl-[10px]'
                  : 'text-stone-600 hover:bg-stone-50',
              )}
            >
              <ShieldCheck className="w-4 h-4 text-stone-400" />
              Admin
            </Link>
          </div>
        )}
      </nav>

      {/* Footer */}
      <div className="flex-shrink-0 border-t border-stone-200 px-2 py-2 space-y-1">
        <Link
          href="/spenden"
          className="w-full flex items-center gap-2.5 px-3 py-2 rounded-full text-sm font-medium text-rose-500 hover:bg-rose-50 transition-colors"
        >
          <Heart className="w-4 h-4 fill-rose-100" />
          Unterstützen
        </Link>
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-2.5 px-3 py-2 rounded-full text-sm font-medium text-stone-400 hover:bg-red-50 hover:text-red-600 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Abmelden
        </button>
      </div>
    </div>
  )

  return (
    <>
      {/* ── Desktop sidebar ── */}
      <aside className="hidden md:flex flex-col fixed top-0 left-0 bottom-0 z-30 w-[260px] bg-paper/95 backdrop-blur-md border-r border-stone-200">
        {inner}
      </aside>

      {/* ── Mobile drawer ── */}
      {mobileOpen && (
        <>
          <div
            className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm md:hidden animate-fade-in"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="fixed top-0 left-0 bottom-0 z-50 w-[280px] bg-white shadow-2xl md:hidden animate-slide-in-left">
            {inner}
          </aside>
        </>
      )}
    </>
  )
}
