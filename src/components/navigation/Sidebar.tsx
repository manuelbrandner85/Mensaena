'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronLeft, ChevronRight, LogOut, Zap } from 'lucide-react'
import { useRouter } from 'next/navigation'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'
import { useNavigationStore } from '@/store/useNavigationStore'
import { useNavigation } from '@/hooks/useNavigation'
import { createClient } from '@/lib/supabase/client'
import { mainNavItems, navGroups } from './navigationConfig'
import SidebarItem from './SidebarItem'
import SidebarGroup from './SidebarGroup'

interface SidebarProps {
  unreadMessages: number
  unreadNotifications: number
  isAdmin: boolean
}

export default function Sidebar({ unreadMessages, unreadNotifications, isAdmin }: SidebarProps) {
  const { sidebarCollapsed, toggleSidebar } = useNavigationStore()
  const { isActive } = useNavigation()
  const router = useRouter()

  // Track which groups are open (default: all open)
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>(() => {
    const groups: Record<string, boolean> = {}
    navGroups.forEach((g) => { groups[g.id] = true })
    return groups
  })

  const toggleGroup = (id: string) => {
    setOpenGroups((prev) => ({ ...prev, [id]: !prev[id] }))
  }

  const getBadge = (badgeKey?: string): number | undefined => {
    if (badgeKey === 'unreadMessages') return unreadMessages || undefined
    if (badgeKey === 'unreadNotifications') return unreadNotifications || undefined
    return undefined
  }

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success('Erfolgreich abgemeldet')
    router.push('/')
    router.refresh()
  }

  return (
    <aside
      className={cn(
        'hidden lg:flex flex-col fixed top-0 left-0 bottom-0 z-30 transition-all duration-300 ease-out bg-white border-r border-gray-100 shadow-sm',
        sidebarCollapsed ? 'w-[68px]' : 'w-[260px]',
      )}
    >
      {/* ── Logo Header ── */}
      <div
        className={cn(
          'relative flex items-center flex-shrink-0 overflow-hidden',
          sidebarCollapsed ? 'h-16 justify-center px-2' : 'h-16 px-4',
        )}
        style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
      >
        {/* Decorative shapes */}
        <div className="absolute -top-8 -right-8 w-28 h-28 bg-white/10 rounded-full pointer-events-none" />
        <div className="absolute -bottom-10 -left-6 w-24 h-24 bg-white/5 rounded-full pointer-events-none" />

        <Link href="/dashboard" className="relative flex items-center gap-2 flex-1 min-w-0">
          {sidebarCollapsed ? (
            <div className="w-9 h-9 bg-white/20 rounded-xl flex items-center justify-center border border-white/30">
              <span className="text-white font-black text-sm">M</span>
            </div>
          ) : (
            <Image
              src="/mensaena-logo.png"
              alt="Mensaena"
              width={180}
              height={56}
              className="h-10 w-auto object-contain brightness-0 invert drop-shadow-sm"
              priority
            />
          )}
        </Link>

        <button
          onClick={toggleSidebar}
          className="relative p-1.5 rounded-lg bg-white/15 hover:bg-white/25 text-white transition-all flex-shrink-0 ml-2"
          title={sidebarCollapsed ? 'Sidebar aufklappen' : 'Sidebar einklappen'}
        >
          {sidebarCollapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>

      {/* ── SOS Strip ── */}
      {!sidebarCollapsed && (
        <div className="px-3 py-2 flex gap-2 bg-gray-50/80 border-b border-gray-100">
          <div className="flex-1 flex items-center gap-2 px-2.5 py-1.5 bg-primary-50 border border-primary-100 rounded-xl">
            <div className="w-2 h-2 rounded-full bg-primary-400 animate-pulse flex-shrink-0" />
            <span className="text-xs text-primary-700 font-medium">Online & aktiv</span>
          </div>
          <Link
            href="/dashboard/crisis"
            className="flex items-center gap-1.5 px-2.5 py-1.5 bg-red-50 border border-red-200 rounded-xl hover:bg-red-100 transition-all group flex-shrink-0"
          >
            <Zap className="w-3.5 h-3.5 text-red-500 group-hover:scale-110 transition-transform" />
            <span className="text-xs font-bold text-red-700">SOS</span>
          </Link>
        </div>
      )}

      {/* ── Navigation ── */}
      <nav className="flex-1 overflow-y-auto py-2 px-2 no-scrollbar">
        {/* Main nav items (no group header) */}
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

        {/* Grouped items */}
        {navGroups
          .filter((group) => !group.adminOnly || isAdmin)
          .map((group) => (
            <SidebarGroup
              key={group.id}
              title={group.title}
              collapsed={sidebarCollapsed}
              open={openGroups[group.id] ?? true}
              onToggle={() => toggleGroup(group.id)}
            >
              {group.items.map((item) => (
                <SidebarItem
                  key={item.id}
                  item={item}
                  active={isActive(item.path)}
                  collapsed={sidebarCollapsed}
                  badge={getBadge(item.badgeKey)}
                />
              ))}
            </SidebarGroup>
          ))}
      </nav>

      {/* ── Bottom: Logout ── */}
      <div className="flex-shrink-0 border-t border-gray-100 px-2 py-2">
        <button
          onClick={handleLogout}
          title={sidebarCollapsed ? 'Abmelden' : undefined}
          className={cn(
            'w-full flex items-center gap-2.5 rounded-xl text-[13px] font-medium text-gray-500 hover:bg-red-50 hover:text-red-600 border border-transparent hover:border-red-100 transition-all',
            sidebarCollapsed ? 'h-10 justify-center' : 'px-3 py-2',
          )}
        >
          <LogOut className={cn('flex-shrink-0', sidebarCollapsed ? 'w-4 h-4' : 'w-4 h-4')} />
          {!sidebarCollapsed && <span>Abmelden</span>}
        </button>
      </div>
    </aside>
  )
}
