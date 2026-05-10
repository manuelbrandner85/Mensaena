'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useRouter } from 'next/navigation'
import {
  Plus, ChevronDown, LogOut, Heart, X,
  LayoutDashboard, User, MessageCircle, Bell, Settings,
  FileText, Repeat, Store, Clock, Wrench, Sparkles,
  Map, Calendar, Users, StickyNote, Users2, Building2,
  AlertTriangle, PawPrint, Brain, LifeBuoy, Package,
  Home, Car, Wheat, BookOpen, Trophy, Award, ShieldCheck,
  PlusCircle, Mail, Handshake, Share2, Briefcase, GraduationCap,
  ShieldAlert,
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

interface GroupAccent {
  header: string       // group label color when active
  activeBg: string     // active item bg
  activeBorder: string // active item left border
  activeText: string   // active item text
  activeIcon: string   // active item icon
  dot: string          // indicator dot on group header
}

interface NavGroup {
  id: string
  label: string
  accent: GroupAccent
  items: NavItem[]
}

const ACCENTS: Record<string, GroupAccent> = {
  personal:  { header: 'text-mn-amber',     activeBg: 'bg-mn-amber/5',     activeBorder: 'border-mn-amber',     activeText: 'text-mn-amber',     activeIcon: 'text-mn-amber',     dot: 'bg-mn-amber'     },
  help:      { header: 'text-mn-teal-soft', activeBg: 'bg-mn-teal/8',      activeBorder: 'border-mn-teal',      activeText: 'text-mn-teal-soft', activeIcon: 'text-mn-teal-soft', dot: 'bg-mn-teal'      },
  community: { header: 'text-mn-trust-soft',activeBg: 'bg-mn-trust/8',     activeBorder: 'border-mn-trust',     activeText: 'text-mn-trust-soft',activeIcon: 'text-mn-trust-soft',dot: 'bg-mn-trust'     },
  emergency: { header: 'text-mn-herzrot-warm',activeBg:'bg-mn-herzrot/8',  activeBorder: 'border-mn-herzrot',   activeText: 'text-mn-herzrot-warm',activeIcon:'text-mn-herzrot-warm',dot:'bg-mn-herzrot'  },
  living:    { header: 'text-mn-leben-soft',activeBg: 'bg-mn-leben/8',     activeBorder: 'border-mn-leben',     activeText: 'text-mn-leben-soft',activeIcon: 'text-mn-leben-soft',dot: 'bg-mn-leben'     },
}

function buildGroups(unreadMessages: number, unreadNotifications: number, activeCrises: number): NavGroup[] {
  return [
    {
      id: 'personal',
      label: '🏠 Mein Bereich',
      accent: ACCENTS.personal,
      items: [
        { id: 'dashboard',      label: 'Dashboard',           path: '/dashboard',                icon: LayoutDashboard },
        { id: 'profile',        label: 'Profil',              path: '/dashboard/profile',        icon: User },
        { id: 'messages',       label: 'Direktnachrichten',   path: '/dashboard/messages',       icon: Mail, badge: unreadMessages },
        { id: 'chat',           label: 'Community-Chat',      path: '/dashboard/chat',           icon: MessageCircle },
        { id: 'notifications',  label: 'Benachrichtigungen',  path: '/dashboard/notifications',  icon: Bell, badge: unreadNotifications },
        { id: 'calendar',       label: 'Kalender',            path: '/dashboard/calendar',       icon: Calendar },
        { id: 'badges',         label: 'Badges',              path: '/dashboard/badges',         icon: Award },
        { id: 'invite',         label: 'Nachbarn einladen',   path: '/dashboard/invite',         icon: Share2 },
        { id: 'settings',       label: 'Einstellungen',       path: '/dashboard/settings',       icon: Settings },
      ],
    },
    {
      id: 'help',
      label: '🤝 Helfen & Teilen',
      accent: ACCENTS.help,
      items: [
        { id: 'posts',         label: 'Beiträge',           path: '/dashboard/posts',         icon: FileText },
        { id: 'map',           label: 'Karte',              path: '/dashboard/map',           icon: Map },
        { id: 'interactions',  label: 'Interaktionen',      path: '/dashboard/interactions',  icon: Handshake },
        { id: 'sharing',       label: 'Teilen & Tauschen',  path: '/dashboard/sharing',       icon: Repeat },
        { id: 'marketplace',   label: 'Marktplatz',         path: '/dashboard/marketplace',   icon: Store },
        { id: 'timebank',      label: 'Zeitbank',           path: '/dashboard/timebank',      icon: Clock },
        { id: 'skills',        label: 'Skills',             path: '/dashboard/skills',        icon: Wrench },
        { id: 'matching',      label: 'Matching',           path: '/dashboard/matching',      icon: Sparkles },
        { id: 'jobs',          label: 'Jobs in der Nähe',   path: '/dashboard/jobs',          icon: Briefcase },
      ],
    },
    {
      id: 'community',
      label: '🌍 Nachbarschaft',
      accent: ACCENTS.community,
      items: [
        { id: 'events',        label: 'Events',         path: '/dashboard/events',        icon: Calendar },
        { id: 'groups',        label: 'Gruppen',        path: '/dashboard/groups',        icon: Users },
        { id: 'board',         label: 'Pinnwand',       path: '/dashboard/board',         icon: StickyNote },
        { id: 'community',     label: 'Community',      path: '/dashboard/community',     icon: Users2 },
        { id: 'organizations', label: 'Organisationen', path: '/dashboard/organizations', icon: Building2 },
        { id: 'challenges',    label: 'Challenges',     path: '/dashboard/challenges',    icon: Trophy },
      ],
    },
    {
      id: 'emergency',
      label: '🆘 Notfall & Fürsorge',
      accent: ACCENTS.emergency,
      items: [
        { id: 'crisis',         label: 'Krisenhilfe',             path: '/dashboard/crisis',          icon: AlertTriangle, badge: activeCrises },
        { id: 'warnungen',      label: 'Lebensmittelwarnungen',   path: '/dashboard/warnungen',       icon: ShieldAlert },
        { id: 'animals',        label: 'Tierhilfe',               path: '/dashboard/animals',         icon: PawPrint },
        { id: 'mental-support', label: 'Seelische Unterstützung', path: '/dashboard/mental-support',  icon: Brain },
        { id: 'rescuer',        label: 'Retter',                  path: '/dashboard/rescuer',         icon: LifeBuoy },
        { id: 'supply',         label: 'Versorgung',              path: '/dashboard/supply',          icon: Package },
      ],
    },
    {
      id: 'living',
      label: '🌿 Wohnen & Leben',
      accent: ACCENTS.living,
      items: [
        { id: 'housing',   label: 'Wohnen',          path: '/dashboard/housing',   icon: Home },
        { id: 'mobility',  label: 'Mobilität',       path: '/dashboard/mobility',  icon: Car },
        { id: 'harvest',   label: 'Ernte',           path: '/dashboard/harvest',   icon: Wheat },
        { id: 'wiki',      label: 'Wiki',            path: '/dashboard/wiki',      icon: BookOpen },
        { id: 'knowledge', label: 'Bildung & Kurse', path: '/dashboard/knowledge', icon: GraduationCap },
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
  const { openGroups, toggleGroup, openGroup, setMobileOpen } = useSidebarStore()
  const isOpen = openGroups.includes(group.id)
  const { accent } = group

  const hasActive = group.items.some(
    (item) => pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
  )

  // Accordion: auto-open active group, which closes all others via store
  useEffect(() => {
    if (hasActive) openGroup(group.id)
  }, [pathname]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="mb-0.5">
      <button
        onClick={() => toggleGroup(group.id)}
        className={cn(
          'w-full flex items-center justify-between px-3 py-1.5 rounded-lg text-left transition-colors group/header',
          hasActive ? accent.header : 'text-mn-mute hover:text-mn-ink-soft hover:bg-mn-elevated/[0.02]',
        )}
      >
        <span className="flex items-center gap-2 min-w-0">
          {hasActive && (
            <span className={cn('w-1.5 h-1.5 rounded-full flex-shrink-0', accent.dot)} />
          )}
          <span className="text-xs font-semibold uppercase tracking-wider select-none truncate">
            {group.label}
          </span>
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
                  onClick={() => setMobileOpen(false)}
                  className={cn(
                    'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors relative',
                    active
                      ? cn(accent.activeBg, accent.activeText, 'font-medium border-l-2 pl-[10px]', accent.activeBorder)
                      : 'text-mn-ink-soft hover:bg-mn-elevated/[0.02] hover:text-mn-ink',
                  )}
                >
                  <Icon className={cn('w-4 h-4 flex-shrink-0', active ? accent.activeIcon : 'text-mn-ghost')} />
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
  const router = useRouter()
  const { mobileOpen, setMobileOpen } = useSidebarStore()
  const groups = buildGroups(unreadMessages, unreadNotifications, activeCrises)

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success('Erfolgreich abgemeldet')
    router.push('/')
  }

  const inner = (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="flex items-center gap-2.5 px-4 h-16 flex-shrink-0" style={{ borderBottom: '1px solid rgba(245,240,232,0.06)' }}>
        <Link href="/dashboard" className="flex items-center gap-2.5 flex-1 min-w-0" onClick={() => setMobileOpen(false)}>
          <Image src="/mensaena-logo.png" alt="Mensaena" width={48} height={32} className="h-10 w-auto object-contain drop-shadow-[0_0_8px_rgba(245,158,11,0.20)]" priority />
          <span
            className="text-[1.2rem] font-medium tracking-tight truncate"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F1F5F9' }}
          >
            Mensaena<span style={{ color: 'rgba(245,158,11,0.80)' }}>.</span>
          </span>
        </Link>
        <button
          onClick={() => setMobileOpen(false)}
          className="md:hidden p-1.5 rounded-full hover:bg-mn-elevated/5 text-mn-mute"
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
          className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl text-sm font-semibold transition-all shadow-amber-glow hover:shadow-[0_4px_24px_rgba(245,158,11,0.50)]"
          style={{ background: 'linear-gradient(135deg, #F59E0B, #FBBF24)', color: '#0A0F1C' }}
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

        {isAdmin && (
          <div className="mt-2 pt-2" style={{ borderTop: '1px solid rgba(245,240,232,0.06)' }}>
            <Link
              href="/dashboard/admin"
              onClick={() => setMobileOpen(false)}
              className={cn(
                'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors',
                pathname.startsWith('/dashboard/admin')
                  ? 'bg-mn-amber/8 text-mn-amber font-medium border-l-2 border-mn-amber pl-[10px]'
                  : 'text-mn-ink-soft hover:bg-mn-elevated/[0.02]',
              )}
            >
              <ShieldCheck className="w-4 h-4 text-mn-ghost" />
              Admin
            </Link>
          </div>
        )}
      </nav>

      {/* Footer */}
      <div className="flex-shrink-0 px-2 py-2 space-y-1" style={{ borderTop: '1px solid rgba(245,240,232,0.06)' }}>
        <Link
          href="/spenden"
          className="w-full flex items-center gap-2.5 px-3 py-2 rounded-full text-sm font-medium transition-colors"
          style={{ color: 'rgba(239,68,68,0.70)' }}
          onMouseEnter={e => (e.currentTarget.style.background = 'rgba(239,68,68,0.06)')}
          onMouseLeave={e => (e.currentTarget.style.background = '')}
        >
          <Heart className="w-4 h-4" />
          Unterstützen
        </Link>
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-2.5 px-3 py-2 rounded-full text-sm font-medium text-mn-mute hover:bg-mn-herzrot/5 hover:text-mn-herzrot-warm transition-colors"
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
      <aside
        className="hidden md:flex flex-col fixed top-0 left-0 bottom-0 z-30 w-[260px]"
        style={{
          background: 'rgba(15,22,40,0.96)',
          backdropFilter: 'blur(16px)',
          WebkitBackdropFilter: 'blur(16px)',
          borderRight: '1px solid rgba(245,240,232,0.06)',
        }}
      >
        {inner}
      </aside>

      {/* ── Mobile drawer ── */}
      {mobileOpen && (
        <>
          <div
            className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm md:hidden animate-fade-in"
            onClick={() => setMobileOpen(false)}
          />
          <aside
            className="fixed top-0 left-0 bottom-0 z-50 w-[280px] md:hidden animate-slide-in-left shadow-cinema-raised"
            style={{ background: '#0F1628', borderRight: '1px solid rgba(245,240,232,0.08)' }}
          >
            {inner}
          </aside>
        </>
      )}
    </>
  )
}
