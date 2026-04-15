'use client'

import Link from 'next/link'
import { Plus, MessageCircle, Map, Command, Search } from 'lucide-react'
import { useNavigation } from '@/hooks/useNavigation'
import NotificationBell from './NotificationBell'
import UserMenu from './UserMenu'
import GlobalSOSButton from '@/app/dashboard/crisis/components/GlobalSOSButton'
import { cn } from '@/lib/utils'
import { useT } from '@/lib/i18n'

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
  const { t } = useT()

  const openPalette = () => {
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new Event('mensaena:open-command-palette'))
    }
  }

  return (
    <header className="hidden md:flex items-center justify-between h-16 px-6 xl:px-8 bg-paper/85 dark:bg-ink-900/85 backdrop-blur-md border-b border-stone-200 dark:border-ink-700 sticky top-0 z-20 transition-colors">
      {/* Left: Page title + Search */}
      <div className="flex items-center gap-5 min-w-0">
        <div className="hidden xl:flex flex-col min-w-0">
          <h1 className="font-display text-[1.15rem] font-medium text-ink-800 dark:text-stone-100 truncate leading-tight tracking-tight">
            {pageTitle}
          </h1>
          {/* Mini breadcrumb trail */}
          {breadcrumbs.length > 2 && (
            <div className="flex items-center gap-1 text-[10px] text-ink-400 dark:text-stone-500 mt-0.5 tracking-wide uppercase">
              {breadcrumbs.slice(0, -1).map((crumb, i) => (
                <span key={crumb.href} className="flex items-center gap-1">
                  {i > 0 && <span className="text-stone-300 dark:text-ink-600">·</span>}
                  <Link href={crumb.href} className="hover:text-primary-700 dark:hover:text-primary-300 transition-colors truncate max-w-[80px]">
                    {crumb.label}
                  </Link>
                </span>
              ))}
            </div>
          )}
        </div>
        {/* Command-palette trigger (replaces the legacy SearchBar) */}
        <button
          type="button"
          onClick={openPalette}
          className="group hidden md:flex items-center gap-2 pl-3 pr-2 py-1.5 rounded-full bg-stone-100 dark:bg-ink-800 hover:bg-stone-200 dark:hover:bg-ink-700 border border-stone-200 dark:border-ink-700 text-xs text-ink-500 dark:text-stone-400 transition-colors"
          aria-label={t('a11y.searchOpen')}
        >
          <Search className="w-3.5 h-3.5" />
          <span className="hidden lg:inline">{t('common.searchPlaceholder')}</span>
          <kbd className="hidden lg:inline-flex items-center gap-0.5 ml-2 px-1.5 py-0.5 rounded bg-white dark:bg-ink-900 border border-stone-200 dark:border-ink-600 text-[10px] font-mono text-ink-400 dark:text-stone-500">
            <Command className="w-3 h-3" />K
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
            className="p-2 rounded-full text-ink-400 dark:text-stone-400 hover:bg-stone-100 dark:hover:bg-ink-700 hover:text-primary-700 dark:hover:text-primary-300 transition-all"
            title={t('nav.map')}
            aria-label={t('nav.map')}
          >
            <Map className="w-5 h-5" />
          </Link>

          {/* Chat with badge */}
          <Link
            href="/dashboard/chat"
            className="relative p-2 rounded-full text-ink-400 dark:text-stone-400 hover:bg-stone-100 dark:hover:bg-ink-700 hover:text-primary-700 dark:hover:text-primary-300 transition-all"
            title={t('nav.chat')}
            aria-label={t('nav.chat')}
          >
            <MessageCircle className="w-5 h-5" />
            {unreadMessages > 0 && (
              <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-0.5 bg-primary-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop shadow-sm">
                {unreadMessages > 99 ? '99+' : unreadMessages}
              </span>
            )}
          </Link>
        </div>

        {/* SOS Button */}
        <GlobalSOSButton />

        {/* Divider */}
        <div className="w-px h-5 bg-stone-300 dark:bg-ink-700 mx-1" />

        {/* Quick Create — editorial ink pill */}
        <Link
          href="/dashboard/create"
          className="magnetic shine inline-flex items-center gap-1.5 bg-ink-800 hover:bg-ink-700 dark:bg-primary-500 dark:hover:bg-primary-400 text-paper px-4 py-2 rounded-full text-sm font-medium tracking-wide transition-colors duration-300 min-h-[36px]"
          aria-label={t('common.createPost')}
        >
          <Plus className="w-4 h-4" />
          <span className="hidden xl:inline">{t('common.createPost')}</span>
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
