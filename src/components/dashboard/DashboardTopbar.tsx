'use client'

// C6: DashboardTopbar previously duplicated the search UI from SearchBar.
// Now it uses SearchBar directly to avoid duplicate placeholder text and logic.
import { Plus, LayoutDashboard } from 'lucide-react'
import Link from 'next/link'
import type { User } from '@supabase/supabase-js'
import NotificationBell from '@/components/navigation/NotificationBell'
import SearchBar from '@/components/navigation/SearchBar'

interface DashboardTopbarProps {
  user: User
  onOpenWidgetSettings?: () => void
}

export default function DashboardTopbar({ user, onOpenWidgetSettings }: DashboardTopbarProps) {
  const displayName = user.user_metadata?.full_name || user.email?.split('@')[0] || 'Nutzer'
  const initials = displayName
    .split(' ')
    .map((n: string) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)

  return (
    <header className="hidden lg:flex items-center justify-between h-16 px-8 bg-white border-b border-warm-200 sticky top-0 z-20 shadow-soft">
      {/* Global Search — shared component, no duplicate placeholder */}
      <SearchBar />

      {/* Right Actions */}
      <div className="flex items-center gap-3">
        {/* Widget settings */}
        {onOpenWidgetSettings && (
          <button
            onClick={onOpenWidgetSettings}
            className="flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-ink-600 hover:text-ink-900 hover:bg-stone-100 rounded-xl transition-colors border border-warm-200"
            title="Widgets anpassen"
          >
            <LayoutDashboard className="w-4 h-4" />
            <span className="hidden xl:inline">Widgets</span>
          </button>
        )}

        {/* Quick Create */}
        <Link
          href="/dashboard/create"
          className="flex items-center gap-2 px-4 py-2 text-white text-sm font-medium rounded-xl transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 active:scale-95"
          style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
        >
          <Plus className="w-4 h-4" />
          Beitrag erstellen
        </Link>

        {/* Notification Bell */}
        <NotificationBell userId={user.id} />

        {/* User Avatar */}
        <Link href="/dashboard/profile" className="flex items-center gap-2.5 pl-2 border-l border-warm-200">
          <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shadow-sm"
            style={{ background: 'linear-gradient(135deg, #38c4c0 0%, #38a169 100%)' }}>
            {initials}
          </div>
          <div className="hidden xl:block">
            <p className="text-sm font-medium text-ink-900 leading-none">{displayName}</p>
            <p className="text-xs text-ink-500 mt-0.5">{user.email}</p>
          </div>
        </Link>
      </div>
    </header>
  )
}
