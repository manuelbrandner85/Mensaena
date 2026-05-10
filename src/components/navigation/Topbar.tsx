'use client'

import Link from 'next/link'
import { MessageCircle, Map, LayoutDashboard } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { usePathname } from 'next/navigation'
import { useNavigation } from '@/hooks/useNavigation'
import SearchBar from './SearchBar'
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
    <header
      className="hidden md:flex items-center justify-between h-16 px-6 xl:px-8 sticky top-0 z-20"
      style={{
        background: 'rgba(10,15,28,0.82)',
        backdropFilter: 'blur(20px) saturate(1.4)',
        WebkitBackdropFilter: 'blur(20px) saturate(1.4)',
        borderBottom: '1px solid rgba(245,158,11,0.10)',
      }}
    >
      {/* Left: Page title + Search */}
      <div className="flex items-center gap-5 min-w-0">
        <div className="hidden xl:flex flex-col min-w-0">
          <h1
            className="text-[1.15rem] font-medium text-mn-ink truncate leading-tight tracking-tight"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif' }}
          >
            {pageTitle}
          </h1>
          {breadcrumbs.length > 2 && (
            <div className="flex items-center gap-1 text-xs text-mn-mute mt-0.5 tracking-wide uppercase font-mono">
              {breadcrumbs.slice(0, -1).map((crumb, i) => (
                <span key={crumb.href} className="flex items-center gap-1">
                  {i > 0 && <span className="text-mn-ghost">·</span>}
                  <Link href={crumb.href} className="hover:text-mn-amber transition-colors truncate max-w-[80px]">
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
        <div className="flex items-center gap-1">
          <Link
            href="/dashboard/map"
            className="p-2 rounded-full text-mn-mute hover:bg-mn-elevated/5 hover:text-mn-amber transition-all"
            title={t('openMap')}
          >
            <Map className="w-5 h-5" />
          </Link>
          <Link
            href="/dashboard/messages"
            className="relative p-2 rounded-full text-mn-mute hover:bg-mn-elevated/5 hover:text-mn-amber transition-all"
            title={t('chat')}
          >
            <MessageCircle className="w-5 h-5" />
            {unreadMessages > 0 && (
              <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-0.5 bg-mn-herzrot text-white text-[9px] font-bold rounded-full flex items-center justify-center animate-badge-pop">
                {unreadMessages > 99 ? '99+' : unreadMessages}
              </span>
            )}
          </Link>
        </div>

        {isDashboardHome && (
          <button
            onClick={openWidgetSettings}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-mn-mute hover:text-mn-amber bg-mn-surface border border-white/7 hover:border-mn-amber/20 rounded-full transition-all"
            title="Dashboard-Widgets anpassen"
          >
            <LayoutDashboard className="w-3.5 h-3.5" />
            <span className="hidden lg:inline">Widgets</span>
          </button>
        )}

        <GlobalSOSButton />

        <div className="w-px h-5 mx-1" style={{ background: 'rgba(245,240,232,0.10)' }} />

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
