'use client'

import Link from 'next/link'
import { Plus, MessageCircle, Map, Command, LayoutDashboard } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { usePathname } from 'next/navigation'
import { useNavigation } from '@/hooks/useNavigation'
import SearchBar from './SearchBar'
import { openCommandPalette } from '@/components/shared/CommandPalette'
import NotificationBell from './NotificationBell'
import UserMenu from './UserMenu'
import GlobalSOSButton from '@/app/dashboard/crisis/components/GlobalSOSButton'
import LanguageSwitcher from '@/components/shared/LanguageSwitcher'
import { cn } from '@/lib/utils'
import { useDashboardWidgetStore } from '@/stores/dashboardWidgetStore'

interface TopbarProps {
  userId: string
  displayName: string
  email: string
  avatarUrl?: string | null
  isAdmin: boolean
  unreadMessages?: number
}

export default function Topbar({ userId, displayName, email, avatarUrl, isAdmin, unreadMessages = 0 }: TopbarProps) {
  const t = useTranslations('nav')
  const { pageTitle, breadcrumbs } = useNavigation()
  const pathname = usePathname()
  const openWidgetSettings = useDashboardWidgetStore(s => s.openSettings)
  const isDashboardHome = pathname === '/dashboard' || pathname === '/de/dashboard' || pathname === '/en/dashboard'

  return (
    <header className="hidden md:flex items-center justify-between h-16 px-6 xl:px-8 bg-paper/85 backdrop-blur-md border-b border-stone-200 sticky top-0 z-20">
      {/* Left: Page title + Search */}
      <div className="flex items-center gap-5 min-w-0">
        <div className="hidden xl:flex flex-col min-w-0">
          <h1 className="font-display text-[1.15rem] font-medium text-ink-800 truncate leading-tight tracking-tight">
            {pageTitle}
          </h1>
          {/* Mini breadcrumb trail */}
          {breadcrumbs.length > 2 && (
            <div className="flex items-center gap-1 text-xs text-ink-400 mt-0.5 tracking-wide uppercase">
              {breadcrumbs.slice(0, -1).map((crumb, i) => (
                <span key={crumb.href} className="flex items-center gap-1">
                  {i > 0 && <span className="text-stone-300">·</span>}
                  <Link href={crumb.href} className="hover:text-primary-700 transition-colors truncate max-w-[80px]">
                    {crumb.label}
                  </Link>
                </span>
              ))}
            </div>
          )}
        </div>
        <SearchBar />
        <button
          type="button"
          onClick={() => openCommandPalette()}
          className="hidden lg:inline-flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium text-ink-500 bg-warm-50 border border-warm-200 hover:border-primary-300 hover:text-primary-700 transition-all"
          aria-label={t('commandPalette')}
          title={t('commandPaletteHint')}
        >
          <Command className="w-3.5 h-3.5" />
          <span>{t('quickAccess')}</span>
          <kbd className="inline-flex items-center bg-white border border-stone-200 rounded px-1.5 py-0.5 text-xs font-semibold">
            ⌘K
          </kbd>
        </button>
      </div>

      {/* Right: Actions */}
      <div className="flex items-center gap-2">
        {/* Quick actions */}
        <div className="flex items-center gap-1">
          {/* Map shortcut */}
          <Link
            href="/dashboard/map"
            className="p-2 rounded-full text-ink-400 hover:bg-stone-100 hover:text-primary-700 transition-all"
            title={t('openMap')}
          >
            <Map className="w-5 h-5" />
          </Link>

          {/* Chat with badge */}
          <Link
            href="/dashboard/messages"
            className="relative p-2 rounded-full text-ink-400 hover:bg-stone-100 hover:text-primary-700 transition-all"
            title={t('chat')}
          >
            <MessageCircle className="w-5 h-5" />
            {unreadMessages > 0 && (
              <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-0.5 bg-primary-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop shadow-sm">
                {unreadMessages > 99 ? '99+' : unreadMessages}
              </span>
            )}
          </Link>
        </div>

        {/* Widget settings – only on dashboard home */}
        {isDashboardHome && (
          <button
            onClick={openWidgetSettings}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-ink-600 hover:text-primary-700 hover:bg-primary-50 border border-stone-200 hover:border-primary-200 rounded-full transition-all"
            title="Dashboard-Widgets anpassen"
          >
            <LayoutDashboard className="w-3.5 h-3.5" />
            <span className="hidden lg:inline">Widgets</span>
          </button>
        )}

        {/* SOS Button */}
        <GlobalSOSButton />

        {/* Divider */}
        <div className="w-px h-5 bg-stone-300 mx-1" />

        {/* Quick Create — editorial ink pill */}
        <Link
          href="/dashboard/create"
          className="magnetic shine inline-flex items-center gap-1.5 bg-ink-800 hover:bg-ink-700 text-paper px-4 py-2 rounded-full text-sm font-medium tracking-wide transition-colors duration-300 min-h-[36px]"
        >
          <Plus className="w-4 h-4" />
          <span>{t('create')}</span>
        </Link>

        {/* Language Switcher */}
        <LanguageSwitcher />

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
