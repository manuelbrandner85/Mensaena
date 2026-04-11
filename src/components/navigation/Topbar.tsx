'use client'

import Link from 'next/link'
import { Plus, MessageCircle, Map, Command, Search } from 'lucide-react'
import { useNavigation } from '@/hooks/useNavigation'
import SearchBar from './SearchBar'
import NotificationBell from './NotificationBell'
import UserMenu from './UserMenu'
import { cn } from '@/lib/utils'

interface TopbarProps {
  userId: string
  displayName: string
  email: string
  avatarUrl?: string | null
  isAdmin: boolean
  unreadMessages?: number
}

export default function Topbar({ userId, displayName, email, avatarUrl, isAdmin, unreadMessages = 0 }: TopbarProps) {
  const { pageTitle, breadcrumbs } = useNavigation()

  return (
    <header className="hidden md:flex items-center justify-between h-16 px-6 xl:px-8 bg-white/95 backdrop-blur-sm border-b border-warm-200 sticky top-0 z-20 shadow-sm">
      {/* Left: Page title + Search */}
      <div className="flex items-center gap-4 min-w-0">
        <div className="hidden xl:flex flex-col min-w-0">
          <h1 className="text-base font-bold text-gray-900 truncate leading-tight">{pageTitle}</h1>
          {/* Mini breadcrumb trail */}
          {breadcrumbs.length > 2 && (
            <div className="flex items-center gap-1 text-[10px] text-gray-400 mt-0.5">
              {breadcrumbs.slice(0, -1).map((crumb, i) => (
                <span key={crumb.href} className="flex items-center gap-1">
                  {i > 0 && <span>›</span>}
                  <Link href={crumb.href} className="hover:text-primary-600 transition-colors truncate max-w-[80px]">
                    {crumb.label}
                  </Link>
                </span>
              ))}
            </div>
          )}
        </div>
        <SearchBar />
      </div>

      {/* Right: Actions */}
      <div className="flex items-center gap-2">
        {/* Quick actions */}
        <div className="flex items-center gap-1.5">
          {/* Map shortcut */}
          <Link
            href="/dashboard/map"
            className="p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors"
            title="Karte öffnen"
          >
            <Map className="w-5 h-5" />
          </Link>

          {/* Chat with badge */}
          <Link
            href="/dashboard/chat"
            className="relative p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors"
            title="Nachrichten"
          >
            <MessageCircle className="w-5 h-5" />
            {unreadMessages > 0 && (
              <span className="absolute top-0.5 right-0.5 w-4.5 h-4.5 bg-blue-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop shadow-sm">
                {unreadMessages > 99 ? '99+' : unreadMessages}
              </span>
            )}
          </Link>
        </div>

        {/* Divider */}
        <div className="w-px h-6 bg-warm-200 mx-1" />

        {/* Quick Create */}
        <Link
          href="/dashboard/create"
          className="btn-primary px-3.5 py-2 text-sm min-h-[36px] gap-1.5"
        >
          <Plus className="w-4 h-4" />
          <span className="hidden xl:inline">Beitrag erstellen</span>
        </Link>

        {/* Notification Bell */}
        <NotificationBell userId={userId} />

        {/* User Menu */}
        <UserMenu
          displayName={displayName}
          email={email}
          avatarUrl={avatarUrl}
          isAdmin={isAdmin}
        />
      </div>
    </header>
  )
}
