'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import {
  ChevronLeft, ChevronRight, ChevronDown, LogOut, Zap,
  type LucideIcon,
} from 'lucide-react'
import { usePathname } from 'next/navigation'
import toast from 'react-hot-toast'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { useNavigationStore } from '@/store/useNavigationStore'
import { useNavigation } from '@/hooks/useNavigation'
import { createClient } from '@/lib/supabase/client'
import { mainNavItems, navGroups, type NavGroupConfig, type NavItemConfig } from './navigationConfig'
import SidebarItem from './SidebarItem'

interface SidebarProps {
  unreadMessages: number
  unreadNotifications: number
  activeCrises: number
  suggestedMatches: number
  interactionRequests?: number
  isAdmin: boolean
}

// ═══════════════════════════════════════════════════════════════════════
// Internal NavGroup component
// ═══════════════════════════════════════════════════════════════════════
interface NavGroupProps {
  group: NavGroupConfig
  isCollapsed: boolean
  getBadge: (badgeKey?: string) => number | undefined
}

function NavGroup({ group, isCollapsed, getBadge }: NavGroupProps) {
  const t = useTranslations('nav')
  const pathname = usePathname()
  const GroupIcon = group.icon

  // Check if any child path matches current pathname → auto-open
  const hasActiveChild = group.items.some(
    (item) => pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
  )

  const [isOpen, setIsOpen] = useState(hasActiveChild)

  // Auto-open group when navigating into it
  useEffect(() => {
    if (hasActiveChild && !isOpen) {
      setIsOpen(true)
    }
  }, [pathname]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── COLLAPSED: show only group icon; hover → flyout ──
  if (isCollapsed) {
    return (
      <div className="group/nav relative mt-1">
        <button
          className={cn(
            'w-full flex items-center justify-center p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors',
            hasActiveChild && 'bg-primary-50 text-primary-600',
          )}
          aria-label={t(group.title as Parameters<typeof t>[0])}
        >
          {GroupIcon && <GroupIcon className="w-4.5 h-4.5" />}
        </button>

        {/* Flyout menu on hover */}
        <div className="invisible group-hover/nav:visible opacity-0 group-hover/nav:opacity-100 transition-all duration-150 absolute left-full top-0 ml-2 z-50">
          <div className="bg-white rounded-xl shadow-xl border border-gray-200 py-2 min-w-[200px]">
            {/* Group name */}
            <div className="px-3 py-1 text-xs font-semibold text-gray-400 uppercase tracking-wider">
              {t(group.title as Parameters<typeof t>[0])}
            </div>
            {/* Child items */}
            {group.items.map((item) => {
              const Icon = item.icon
              const isCrisis = item.variant === 'crisis'
              const active = pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
              const badge = getBadge(item.badgeKey)

              return (
                <Link
                  key={item.id}
                  href={item.path}
                  className={cn(
                    'flex items-center gap-2.5 px-3 py-2 text-sm transition-colors',
                    active
                      ? isCrisis
                        ? 'bg-red-50 text-red-700 font-semibold'
                        : 'bg-primary-50 text-primary-700 font-semibold'
                      : 'text-gray-700 hover:bg-gray-50',
                  )}
                >
                  <Icon className={cn(
                    'w-4 h-4 flex-shrink-0',
                    active ? (isCrisis ? 'text-red-600' : 'text-primary-600') : (isCrisis ? 'text-red-500' : 'text-gray-400'),
                  )} />
                  <span className="flex-1 truncate">{t(item.label as Parameters<typeof t>[0])}</span>
                  {badge !== undefined && badge > 0 && (
                    <span className="min-w-[18px] h-[18px] bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1">
                      {badge > 99 ? '99+' : badge}
                    </span>
                  )}
                  {isCrisis && !active && (
                    <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
                  )}
                </Link>
              )
            })}
          </div>
        </div>
      </div>
    )
  }

  // ── EXPANDED: header button with icon, name, chevron; collapsible children ──
  return (
    <div className="mt-3">
      <button
        onClick={() => setIsOpen((o) => !o)}
        className="w-full flex items-center gap-2 px-3 py-1.5 group hover:bg-gray-50 rounded-lg transition-colors"
      >
        {GroupIcon && (
          <GroupIcon className={cn(
            'w-3.5 h-3.5 flex-shrink-0 transition-colors',
            hasActiveChild ? 'text-primary-500' : 'text-gray-400 group-hover:text-gray-500',
          )} />
        )}
        <span className={cn(
          'text-xs font-semibold uppercase tracking-wider select-none whitespace-nowrap transition-colors',
          hasActiveChild ? 'text-primary-600' : 'text-gray-400 group-hover:text-gray-500',
        )}>
          {t(group.title as Parameters<typeof t>[0])}
        </span>
        <div className="flex-1 h-px bg-gradient-to-r from-gray-200 to-transparent" />
        <ChevronDown
          className={cn(
            'w-3 h-3 text-gray-400 transition-transform duration-200 flex-shrink-0',
            isOpen ? 'rotate-0' : '-rotate-90',
          )}
        />
      </button>

      {/* Items – collapsible via max-height/opacity */}
      <div
        className={cn(
          'overflow-hidden transition-all duration-200 ease-out',
          isOpen ? 'max-h-[500px] opacity-100 mt-0.5' : 'max-h-0 opacity-0',
        )}
      >
        <div className="space-y-0.5 px-1">
          {group.items.map((item) => {
            const active = pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
            const badge = getBadge(item.badgeKey)
            return (
              <SidebarItem
                key={item.id}
                item={item}
                active={active}
                collapsed={false}
                badge={badge}
              />
            )
          })}
        </div>
      </div>
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════════════
// Sidebar
// ═══════════════════════════════════════════════════════════════════════
export default function Sidebar({
  unreadMessages,
  unreadNotifications,
  activeCrises,
  suggestedMatches,
  interactionRequests = 0,
  isAdmin,
}: SidebarProps) {
  const t = useTranslations('nav')
  const { sidebarCollapsed, toggleSidebar } = useNavigationStore()
  const { isActive } = useNavigation()

  const getBadge = useCallback((badgeKey?: string): number | undefined => {
    if (badgeKey === 'unreadMessages') return unreadMessages || undefined
    if (badgeKey === 'unreadNotifications') return unreadNotifications || undefined
    if (badgeKey === 'activeCrises') return activeCrises || undefined
    if (badgeKey === 'suggestedMatches') return suggestedMatches || undefined
    if (badgeKey === 'interactionRequests') return interactionRequests || undefined
    return undefined
  }, [unreadMessages, unreadNotifications, activeCrises, suggestedMatches, interactionRequests])

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success(t('logoutSuccess'))
    window.location.href = '/'
  }

  // Total badge count for collapsed view
  const totalBadges = (unreadMessages || 0) + (unreadNotifications || 0) + (activeCrises || 0)

  // Separate regular groups from admin group
  const regularGroups = navGroups.filter(g => !g.adminOnly)
  const adminGroups = navGroups.filter(g => g.adminOnly)

  return (
    <aside
      className={cn(
        'hidden md:flex flex-col fixed top-0 left-0 bottom-0 z-30 transition-all duration-300 ease-out bg-paper/95 backdrop-blur-md border-r border-stone-200',
        sidebarCollapsed ? 'w-[68px]' : 'w-[260px]',
      )}
    >
      {/* ── Logo Header — editorial treatment ── */}
      <div
        className={cn(
          'relative flex items-center flex-shrink-0 border-b border-stone-200 bg-paper',
          sidebarCollapsed ? 'h-16 justify-center px-2' : 'h-16 px-4',
        )}
      >
        <Link href="/dashboard" className="group relative flex items-center gap-2.5 flex-1 min-w-0">
          {sidebarCollapsed ? (
            <div className="relative">
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                width={60}
                height={40}
                className="h-11 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
                priority
              />
              {totalBadges > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 bg-emergency-500 text-white text-[8px] font-bold rounded-full flex items-center justify-center animate-badge-pop">
                  {totalBadges > 9 ? '9+' : totalBadges}
                </span>
              )}
            </div>
          ) : (
            <>
              <Image
                src="/mensaena-logo.png"
                alt="Mensaena"
                width={60}
                height={40}
                className="h-11 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
                priority
              />
              <span className="font-display text-[1.35rem] font-medium text-ink-800 tracking-tight group-hover:text-primary-700 transition-colors">
                Mensaena<span className="text-primary-500">.</span>
              </span>
            </>
          )}
        </Link>

        <button
          onClick={toggleSidebar}
          className="relative p-1.5 rounded-full hover:bg-stone-100 text-ink-400 hover:text-ink-800 transition-all flex-shrink-0 ml-2"
          title={sidebarCollapsed ? t('sidebarExpand') : t('sidebarCollapse')}
        >
          {sidebarCollapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>

      {/* ── SOS Strip — editorial ── */}
      {!sidebarCollapsed ? (
        <div className="px-3 py-2.5 flex gap-2 border-b border-stone-200">
          <div className="flex-1 flex items-center gap-2 px-3 py-1.5 bg-primary-50/60 border border-primary-100 rounded-full">
            <div className="w-1.5 h-1.5 rounded-full bg-primary-500 animate-pulse flex-shrink-0" />
            <span className="text-[11px] text-primary-800 font-medium tracking-wide">{t('online')}</span>
          </div>
          <Link
            href="/dashboard/crisis"
            className="flex items-center gap-1.5 px-3 py-1.5 bg-emergency-50 border border-emergency-100 rounded-full hover:bg-emergency-100 transition-all group flex-shrink-0"
          >
            <Zap className="w-3.5 h-3.5 text-emergency-500 group-hover:scale-110 transition-transform" />
            <span className="text-[11px] font-semibold text-emergency-600 tracking-wide">SOS</span>
            {activeCrises > 0 && (
              <span className="w-4 h-4 bg-emergency-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-pulse">
                {activeCrises > 9 ? '9+' : activeCrises}
              </span>
            )}
          </Link>
        </div>
      ) : (
        <div className="px-2 py-2 border-b border-stone-200">
          <Link
            href="/dashboard/crisis"
            className="w-10 h-10 mx-auto flex items-center justify-center bg-emergency-50 border border-emergency-100 rounded-full hover:bg-emergency-100 transition-all group relative"
            title={t('sosCrisis')}
          >
            <Zap className="w-4 h-4 text-emergency-500 group-hover:scale-110 transition-transform" />
            {activeCrises > 0 && (
              <span className="absolute -top-1 -right-1 w-3.5 h-3.5 bg-emergency-500 text-white text-[7px] font-bold rounded-full flex items-center justify-center animate-pulse">
                {activeCrises}
              </span>
            )}
          </Link>
        </div>
      )}

      {/* ── Navigation ── */}
      <nav className="flex-1 overflow-y-auto py-2 px-2 no-scrollbar">
        {/* Top: main nav items (no group header) */}
        <div className="space-y-0.5">
          {mainNavItems.map((item) => (
            <SidebarItem
              key={item.id}
              item={item}
              active={isActive(item.path)}
              collapsed={sidebarCollapsed}
              badge={getBadge(item.badgeKey)}
            />
          ))}
        </div>

        {/* Middle: 6 grouped sections */}
        {regularGroups.map((group) => (
          <NavGroup
            key={group.id}
            group={group}
            isCollapsed={sidebarCollapsed}
            getBadge={getBadge}
          />
        ))}

        {/* Admin group (visible only for admins) */}
        {isAdmin && adminGroups.map((group) => (
          <NavGroup
            key={group.id}
            group={group}
            isCollapsed={sidebarCollapsed}
            getBadge={getBadge}
          />
        ))}
      </nav>

      {/* ── Bottom: Logout ── */}
      <div className="flex-shrink-0 border-t border-stone-200 px-2 py-2">
        <button
          onClick={handleLogout}
          title={sidebarCollapsed ? t('logout') : undefined}
          className={cn(
            'w-full flex items-center gap-2.5 rounded-full text-[13px] font-medium text-ink-400 hover:bg-emergency-50 hover:text-emergency-600 border border-transparent hover:border-emergency-100 transition-all',
            sidebarCollapsed ? 'h-10 justify-center' : 'px-3 py-2',
          )}
        >
          <LogOut className="w-4 h-4 flex-shrink-0" />
          {!sidebarCollapsed && <span>{t('logout')}</span>}
        </button>
      </div>
    </aside>
  )
}
