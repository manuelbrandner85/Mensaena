'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { useState, useEffect } from 'react'
import {
  LayoutDashboard, Map, FilePlus, MessageCircle, ShieldAlert, PawPrint,
  Home, Wheat, BookOpen, Brain, Wrench, Car, Shuffle, Users, Siren,
  User, Settings, LogOut, Leaf, ChevronLeft, ChevronRight, Bell, Menu, X
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'

const navSections = [
  {
    label: 'Übersicht',
    items: [
      { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/dashboard/map', label: 'Karte', icon: Map },
      { href: '/dashboard/create', label: 'Beitrag erstellen', icon: FilePlus },
      { href: '/dashboard/chat', label: 'Chat', icon: MessageCircle },
    ],
  },
  {
    label: 'Hilfe & Ressourcen',
    items: [
      { href: '/dashboard/rescuer', label: 'Retter-System', icon: ShieldAlert },
      { href: '/dashboard/animals', label: 'Tiere', icon: PawPrint },
      { href: '/dashboard/housing', label: 'Wohnen & Alltag', icon: Home },
      { href: '/dashboard/supply', label: 'Regionale Versorgung', icon: Wheat },
    ],
  },
  {
    label: 'Wissen & Netzwerk',
    items: [
      { href: '/dashboard/knowledge', label: 'Bildung & Wissen', icon: BookOpen },
      { href: '/dashboard/mental-support', label: 'Mentale Unterstützung', icon: Brain },
      { href: '/dashboard/skills', label: 'Skill-Netzwerk', icon: Wrench },
    ],
  },
  {
    label: 'Gemeinschaft',
    items: [
      { href: '/dashboard/mobility', label: 'Mobilität', icon: Car },
      { href: '/dashboard/sharing', label: 'Teilen & Tauschen', icon: Shuffle },
      { href: '/dashboard/community', label: 'Community', icon: Users },
      { href: '/dashboard/crisis', label: 'Krisensystem', icon: Siren },
    ],
  },
]

export default function Sidebar() {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)
  const [collapsed, setCollapsed] = useState(false)

  // Close mobile on route change
  useEffect(() => {
    setMobileOpen(false)
  }, [pathname])

  const handleLogout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    toast.success('Erfolgreich abgemeldet')
    router.push('/')
    router.refresh()
  }

  const isActive = (href: string) => {
    if (href === '/dashboard') return pathname === '/dashboard'
    return pathname.startsWith(href)
  }

  return (
    <>
      {/* Mobile Topbar */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-40 bg-white border-b border-warm-100 shadow-soft">
        <div className="flex items-center justify-between px-4 h-14">
          <Link href="/dashboard" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center">
              <Leaf className="w-4 h-4 text-white" />
            </div>
            <span className="font-bold text-gray-900">Mensaena</span>
          </Link>
          <button
            onClick={() => setMobileOpen(true)}
            className="p-2 rounded-lg text-gray-600 hover:bg-warm-100"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Mobile Overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 z-50 bg-black/40 animate-fade-in"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Mobile Drawer */}
      <div
        className={cn(
          'lg:hidden fixed top-0 left-0 bottom-0 z-50 w-72 bg-white shadow-2xl transition-transform duration-300',
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <SidebarContent
          navSections={navSections}
          isActive={isActive}
          collapsed={false}
          onLogout={handleLogout}
          showClose
          onClose={() => setMobileOpen(false)}
        />
      </div>

      {/* Desktop Sidebar */}
      <aside
        className={cn(
          'hidden lg:flex flex-col fixed top-0 left-0 bottom-0 z-30 bg-white border-r border-warm-100 shadow-soft transition-all duration-300',
          collapsed ? 'w-16' : 'w-64'
        )}
      >
        <SidebarContent
          navSections={navSections}
          isActive={isActive}
          collapsed={collapsed}
          onLogout={handleLogout}
          onToggleCollapse={() => setCollapsed(!collapsed)}
        />
      </aside>
    </>
  )
}

type NavSection = {
  label: string
  items: { href: string; label: string; icon: React.ComponentType<{ className?: string }> }[]
}

// ── Sidebar Content ──────────────────────────────────────────────────
function SidebarContent({
  navSections,
  isActive,
  collapsed,
  onLogout,
  onToggleCollapse,
  showClose,
  onClose,
}: {
  navSections: NavSection[]
  isActive: (href: string) => boolean
  collapsed: boolean
  onLogout: () => void
  onToggleCollapse?: () => void
  showClose?: boolean
  onClose?: () => void
}) {
  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Logo Header */}
      <div className={cn('flex items-center gap-3 px-4 h-16 border-b border-warm-100 flex-shrink-0', collapsed && 'justify-center px-2')}>
        <Link href="/dashboard" className="flex items-center gap-2.5 min-w-0">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center flex-shrink-0 shadow-sm">
            <Leaf className="w-4 h-4 text-white" />
          </div>
          {!collapsed && (
            <span className="font-bold text-gray-900 text-lg tracking-tight truncate">Mensaena</span>
          )}
        </Link>
        {showClose && (
          <button onClick={onClose} className="ml-auto p-1.5 rounded-lg hover:bg-warm-100 text-gray-500">
            <X className="w-4 h-4" />
          </button>
        )}
        {onToggleCollapse && !collapsed && (
          <button
            onClick={onToggleCollapse}
            className="ml-auto p-1.5 rounded-lg hover:bg-warm-100 text-gray-400 hover:text-gray-600 transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
        )}
        {onToggleCollapse && collapsed && (
          <button onClick={onToggleCollapse} className="p-1.5 rounded-lg hover:bg-warm-100 text-gray-400">
            <ChevronRight className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-4 px-2 space-y-0.5 no-scrollbar">
        {navSections.map((section) => (
          <div key={section.label} className="mb-4">
            {!collapsed && (
              <p className="px-3 mb-1.5 text-[10px] font-semibold uppercase tracking-widest text-gray-400">
                {section.label}
              </p>
            )}
            {section.items.map((item) => {
              const Icon = item.icon
              const active = isActive(item.href)
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  title={collapsed ? item.label : undefined}
                  className={cn(
                    'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150',
                    collapsed && 'justify-center px-2',
                    active
                      ? 'bg-primary-100 text-primary-700 font-semibold'
                      : 'text-gray-600 hover:bg-warm-100 hover:text-gray-900'
                  )}
                >
                  <Icon className={cn('w-5 h-5 flex-shrink-0', active ? 'text-primary-600' : 'text-gray-500')} />
                  {!collapsed && <span className="truncate">{item.label}</span>}
                </Link>
              )
            })}
          </div>
        ))}
      </nav>

      {/* Bottom User Actions */}
      <div className="border-t border-warm-100 p-2 flex-shrink-0 space-y-0.5">
        <Link
          href="/dashboard/profile"
          title={collapsed ? 'Mein Profil' : undefined}
          className={cn(
            'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-warm-100 hover:text-gray-900 transition-all duration-150',
            collapsed && 'justify-center px-2'
          )}
        >
          <User className="w-5 h-5 flex-shrink-0 text-gray-500" />
          {!collapsed && <span>Mein Profil</span>}
        </Link>
        <Link
          href="/dashboard/settings"
          title={collapsed ? 'Einstellungen' : undefined}
          className={cn(
            'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-warm-100 hover:text-gray-900 transition-all duration-150',
            collapsed && 'justify-center px-2'
          )}
        >
          <Settings className="w-5 h-5 flex-shrink-0 text-gray-500" />
          {!collapsed && <span>Einstellungen</span>}
        </Link>
        <button
          onClick={onLogout}
          title={collapsed ? 'Abmelden' : undefined}
          className={cn(
            'w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-red-50 hover:text-red-600 transition-all duration-150',
            collapsed && 'justify-center px-2'
          )}
        >
          <LogOut className="w-5 h-5 flex-shrink-0" />
          {!collapsed && <span>Abmelden</span>}
        </button>
      </div>
    </div>
  )
}
