'use client'

import {
  LayoutDashboard, Users, FileText, UsersRound, Target, Clock,
  Flag, Settings, MessageCircle, Calendar, LayoutGrid,
  AlertTriangle, Building2, Wheat, ChevronDown, ChevronRight
} from 'lucide-react'
import { useState } from 'react'
import type { AdminTab } from './AdminTypes'

interface Props {
  activeTab: AdminTab
  onTabChange: (tab: AdminTab) => void
  userRole: string
  openReportsCount?: number
}

type NavItem = {
  key: AdminTab
  label: string
  icon: React.ComponentType<{ className?: string }>
  adminOnly?: boolean
  badge?: number
}

type NavSection = {
  label: string
  items: NavItem[]
  collapsible?: boolean
}

export default function AdminSidebar({ activeTab, onTabChange, userRole, openReportsCount = 0 }: Props) {
  const [showMore, setShowMore] = useState(false)

  const mainSection: NavSection = {
    label: 'Verwaltung',
    items: [
      { key: 'overview',   label: 'Dashboard',   icon: LayoutDashboard },
      { key: 'users',      label: 'Benutzer',    icon: Users, adminOnly: true },
      { key: 'posts',      label: 'Beiträge',    icon: FileText },
      { key: 'groups',     label: 'Gruppen',     icon: UsersRound },
      { key: 'challenges', label: 'Challenges',  icon: Target },
      { key: 'zeitbank',   label: 'Zeitbank',    icon: Clock },
      { key: 'reports',    label: 'Meldungen',   icon: Flag, badge: openReportsCount },
      { key: 'system',     label: 'Einstellungen', icon: Settings, adminOnly: true },
    ],
  }

  const moreSection: NavSection = {
    label: 'Weitere Module',
    collapsible: true,
    items: [
      { key: 'chat',   label: 'Chat-Moderation', icon: MessageCircle },
      { key: 'events', label: 'Events',          icon: Calendar },
      { key: 'board',  label: 'Brett',           icon: LayoutGrid },
      { key: 'crisis', label: 'Krisen',          icon: AlertTriangle },
      { key: 'orgs',   label: 'Organisationen',  icon: Building2 },
      { key: 'farms',  label: 'Betriebe',        icon: Wheat },
    ],
  }

  const isVisible = (item: NavItem) => !item.adminOnly || userRole === 'admin'

  const renderItem = (item: NavItem) => {
    if (!isVisible(item)) return null
    const Icon = item.icon
    const active = activeTab === item.key
    return (
      <button
        key={item.key}
        onClick={() => onTabChange(item.key)}
        className={`w-full group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
          active
            ? 'bg-primary-50 text-primary-700 border border-primary-200 shadow-sm'
            : 'text-gray-600 border border-transparent hover:bg-gray-50 hover:text-gray-900'
        }`}
      >
        <div className={`flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center transition-all ${
          active
            ? 'bg-primary-500 shadow-sm'
            : 'bg-gray-100 group-hover:bg-primary-100'
        }`}>
          <Icon className={`w-4 h-4 transition-colors ${
            active ? 'text-white' : 'text-gray-500 group-hover:text-primary-600'
          }`} />
        </div>
        <span className="flex-1 text-left truncate">{item.label}</span>
        {item.badge !== undefined && item.badge > 0 && (
          <span className="flex-shrink-0 min-w-[20px] h-5 px-1.5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center shadow-sm">
            {item.badge > 99 ? '99+' : item.badge}
          </span>
        )}
      </button>
    )
  }

  return (
    <aside className="w-full lg:w-64 flex-shrink-0">
      <div className="sticky top-4 bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        {/* Header */}
        <div className="px-4 py-4 bg-gradient-to-br from-primary-500 to-teal-600 text-white">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-white/20 rounded-xl flex items-center justify-center border border-white/30">
              <Settings className="w-4 h-4 text-white" />
            </div>
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-white/80">Administration</p>
              <p className="text-sm font-bold truncate">
                {userRole === 'admin' ? 'Admin-Panel' : 'Moderator-Panel'}
              </p>
            </div>
          </div>
        </div>

        {/* Main nav */}
        <nav className="p-2">
          <div className="px-2 pt-1 pb-1.5">
            <span className="text-[10px] font-black uppercase tracking-wider text-gray-400">
              {mainSection.label}
            </span>
          </div>
          <div className="space-y-0.5">
            {mainSection.items.map(renderItem)}
          </div>

          {/* Collapsible "more" section */}
          <div className="mt-3 pt-3 border-t border-gray-100">
            <button
              onClick={() => setShowMore(s => !s)}
              className="w-full flex items-center justify-between px-2 py-1.5 text-[10px] font-black uppercase tracking-wider text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span>{moreSection.label}</span>
              {showMore ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
            </button>
            {showMore && (
              <div className="space-y-0.5 mt-1">
                {moreSection.items.map(renderItem)}
              </div>
            )}
          </div>
        </nav>
      </div>
    </aside>
  )
}
