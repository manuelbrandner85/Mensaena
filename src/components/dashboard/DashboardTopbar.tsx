'use client'

import { useState } from 'react'
import { Bell, Search, Plus } from 'lucide-react'
import Link from 'next/link'
import type { User } from '@supabase/supabase-js'
import dynamic from 'next/dynamic'
const DarkModeToggle = dynamic(() => import('@/components/ui/DarkModeToggle'), { ssr: false })

export default function DashboardTopbar({ user }: { user: User }) {
  const [notifications] = useState(3)

  const displayName = user.user_metadata?.full_name || user.email?.split('@')[0] || 'Nutzer'
  const initials = displayName
    .split(' ')
    .map((n: string) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)

  return (
    <header className="hidden lg:flex items-center justify-between h-16 px-8 bg-white border-b border-warm-100 sticky top-0 z-20 shadow-soft">
      {/* Search */}
      <div className="relative w-72 xl:w-96">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          placeholder="Beiträge, Nutzer, Orte suchen…"
          className="w-full pl-9 pr-4 py-2 text-sm bg-warm-50 border border-warm-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-500 focus:bg-white transition-all"
        />
      </div>

      {/* Right Actions */}
      <div className="flex items-center gap-3">
        {/* Quick Create */}
        <Link
          href="/dashboard/create"
          className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white text-sm font-medium rounded-xl transition-all duration-200 hover:shadow-md"
        >
          <Plus className="w-4 h-4" />
          Beitrag erstellen
        </Link>

        {/* Dark Mode */}
        <DarkModeToggle />

        {/* Notifications */}
        <button className="relative p-2 rounded-xl text-gray-500 hover:bg-warm-100 hover:text-gray-700 transition-colors">
          <Bell className="w-5 h-5" />
          {notifications > 0 && (
            <span className="absolute top-1 right-1 w-4 h-4 bg-emergency-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
              {notifications}
            </span>
          )}
        </button>

        {/* User Avatar */}
        <Link href="/dashboard/profile" className="flex items-center gap-2.5 pl-2 border-l border-warm-200">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center text-white text-xs font-bold shadow-sm">
            {initials}
          </div>
          <div className="hidden xl:block">
            <p className="text-sm font-medium text-gray-900 leading-none">{displayName}</p>
            <p className="text-xs text-gray-500 mt-0.5">{user.email}</p>
          </div>
        </Link>
      </div>
    </header>
  )
}
