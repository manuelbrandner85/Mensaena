'use client'

import Link from 'next/link'
import { Plus } from 'lucide-react'
import { useNavigation } from '@/hooks/useNavigation'
import SearchBar from './SearchBar'
import NotificationBell from './NotificationBell'
import UserMenu from './UserMenu'

interface TopbarProps {
  userId: string
  displayName: string
  email: string
  avatarUrl?: string | null
  isAdmin: boolean
}

export default function Topbar({ userId, displayName, email, avatarUrl, isAdmin }: TopbarProps) {
  const { pageTitle } = useNavigation()

  return (
    <header className="hidden lg:flex items-center justify-between h-16 px-8 bg-white/95 backdrop-blur-sm border-b border-warm-200 sticky top-0 z-20 shadow-sm">
      {/* Left: Page title + Search */}
      <div className="flex items-center gap-6">
        <h1 className="text-lg font-bold text-gray-900 hidden xl:block">{pageTitle}</h1>
        <SearchBar />
      </div>

      {/* Right: Actions */}
      <div className="flex items-center gap-3">
        {/* Quick Create */}
        <Link
          href="/dashboard/create"
          className="btn-primary px-4 py-2 text-sm min-h-[36px]"
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
