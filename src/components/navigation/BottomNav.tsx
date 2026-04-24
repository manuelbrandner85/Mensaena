'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { Bell, ChevronDown, Menu } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { useNavigation } from '@/hooks/useNavigation'
import { useKeyboard } from '@/hooks/mobile'
import { bottomNavItems, navGroups, type NavGroupConfig, type NavItemConfig } from './navigationConfig'

interface BottomNavProps {
  unreadMessages: number
  unreadNotifications: number
  activeCrises?: number
  suggestedMatches?: number
  interactionRequests?: number
}

// ── Collapsible group inside the More sheet ────────────────────────────
function SheetGroup({
  group,
  getBadge,
  onNavigate,
}: {
  group: NavGroupConfig
  getBadge: (badgeKey?: string) => number | undefined
  onNavigate: (path: string) => void
}) {
  const t = useTranslations('nav')
  const pathname = usePathname()
  const GroupIcon = group.icon
  const hasActiveChild = group.items.some(
    (item) => pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
  )
  const [isOpen, setIsOpen] = useState(hasActiveChild)

  return (
    <div>
      {/* Header */}
      <button
        onClick={() => setIsOpen((o) => !o)}
        className="w-full flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-50 transition-colors"
      >
        {GroupIcon && (
          <GroupIcon
            className={cn(
              'w-4 h-4 flex-shrink-0',
              hasActiveChild ? 'text-primary-500' : 'text-gray-400',
            )}
          />
        )}
        <span
          className={cn(
            'text-sm font-semibold select-none whitespace-nowrap',
            hasActiveChild ? 'text-primary-700' : 'text-gray-600',
          )}
        >
          {t(group.title as Parameters<typeof t>[0])}
        </span>
        <div className="flex-1" />
        <ChevronDown
          className={cn(
            'w-3.5 h-3.5 text-gray-400 transition-transform duration-200',
            isOpen ? 'rotate-0' : '-rotate-90',
          )}
        />
      </button>

      {/* Children */}
      <div
        className={cn(
          'overflow-hidden transition-all duration-200 ease-out',
          isOpen ? 'max-h-[400px] opacity-100' : 'max-h-0 opacity-0',
        )}
      >
        <div className="pl-2 pr-1 pb-1 space-y-0.5">
          {group.items.map((item) => {
            const Icon = item.icon
            const isCrisis = item.variant === 'crisis'
            const active =
              pathname === item.path ||
              (item.path !== '/dashboard' && pathname.startsWith(item.path))
            const badge = getBadge(item.badgeKey)

            return (
              <button
                key={item.id}
                onClick={() => onNavigate(item.path)}
                className={cn(
                  'w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-left transition-all',
                  active
                    ? isCrisis
                      ? 'bg-red-50 text-red-700 font-semibold border border-red-200'
                      : 'bg-primary-50 text-primary-700 font-semibold border border-primary-200'
                    : 'text-gray-600 border border-transparent hover:bg-gray-50',
                )}
              >
                <Icon
                  className={cn(
                    'w-4 h-4 flex-shrink-0',
                    active
                      ? isCrisis
                        ? 'text-red-600'
                        : 'text-primary-600'
                      : isCrisis
                        ? 'text-red-500'
                        : 'text-gray-400',
                  )}
                />
                <span className="flex-1 text-sm truncate">{t(item.label as Parameters<typeof t>[0])}</span>
                {badge !== undefined && badge > 0 && (
                  <span className="min-w-[18px] h-[18px] bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1 animate-badge-pop">
                    {badge > 99 ? '99+' : badge}
                  </span>
                )}
                {isCrisis && !active && (
                  <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
                )}
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════════════
// BottomNav
// ═══════════════════════════════════════════════════════════════════════
export default function BottomNav({
  unreadMessages,
  unreadNotifications,
  activeCrises = 0,
  suggestedMatches = 0,
  interactionRequests = 0,
}: BottomNavProps) {
  const t = useTranslations('nav')
  const { isActive, isExactActive } = useNavigation()
  const { isOpen: keyboardOpen } = useKeyboard()
  const pathname = usePathname()
  const router = useRouter()

  const [showMore, setShowMore] = useState(false)

  // Auto-close sheet on route change
  useEffect(() => {
    setShowMore(false)
  }, [pathname])

  const getBadge = useCallback(
    (badgeKey?: string): number | undefined => {
      if (badgeKey === 'unreadMessages') return unreadMessages || undefined
      if (badgeKey === 'unreadNotifications') return unreadNotifications || undefined
      if (badgeKey === 'activeCrises') return activeCrises || undefined
      if (badgeKey === 'suggestedMatches') return suggestedMatches || undefined
      if (badgeKey === 'interactionRequests') return interactionRequests || undefined
      return undefined
    },
    [unreadMessages, unreadNotifications, activeCrises, suggestedMatches, interactionRequests],
  )

  const handleNavigate = useCallback(
    (path: string) => {
      router.push(path)
      setShowMore(false)
    },
    [router],
  )

  // Total badges in "more" items (for the more button itself)
  const moreBadgeTotal = (activeCrises || 0) + (suggestedMatches || 0) + (interactionRequests || 0)

  // First 4 items (Home, Karte, Erstellen, Chat)
  const visibleItems = bottomNavItems.slice(0, 4)

  // Regular groups for the sheet (exclude adminOnly)
  const sheetGroups = navGroups.filter((g) => !g.adminOnly)

  return (
    <>
      {/* ── Bottom Navigation Bar ── */}
      <nav
        className={cn(
          'md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-gray-200 shadow-[0_-4px_12px_-4px_rgba(0,0,0,0.08)] safe-area-bottom',
          'transition-transform duration-200 ease-out',
          keyboardOpen && 'translate-y-full',
        )}
        role="navigation"
        aria-label="Navigation"
      >
        <div className="flex items-center justify-around h-16 px-1">
          {visibleItems.map((item) => {
            const Icon = item.icon
            const active =
              item.path === '/dashboard' ? isExactActive(item.path) : isActive(item.path)
            const badge = getBadge(item.badgeKey)
            const isHighlight = item.variant === 'highlight'

            return (
              <Link
                key={item.id}
                href={item.path}
                className={cn(
                  'relative flex flex-col items-center justify-center gap-0.5 touch-target py-1.5 rounded-xl transition-all',
                  active ? 'text-primary-600' : 'text-gray-500 hover:text-gray-700',
                )}
              >
                {isHighlight ? (
                  <div
                    className={cn(
                      'w-11 h-11 rounded-2xl flex items-center justify-center -mt-5 shadow-lg transition-all',
                      active ? 'scale-110' : 'hover:scale-105',
                    )}
                    style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
                  >
                    <Icon className="w-5 h-5 text-white" />
                  </div>
                ) : (
                  <div className="relative">
                    <Icon className={cn('w-5 h-5 transition-all', active && 'scale-110')} />
                    {badge !== undefined && badge > 0 && (
                      <span className="absolute -top-1.5 -right-2 min-w-[16px] h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1 animate-badge-pop">
                        {badge > 99 ? '99+' : badge}
                      </span>
                    )}
                  </div>
                )}
                <span
                  className={cn(
                    'text-[10px] font-medium leading-tight',
                    isHighlight && '-mt-0.5',
                    active ? 'text-primary-600 font-semibold' : 'text-gray-500',
                  )}
                >
                  {t(item.label as Parameters<typeof t>[0])}
                </span>
                {active && !isHighlight && (
                  <div className="absolute bottom-0 w-5 h-0.5 rounded-full bg-primary-500 animate-[scaleIn_0.2s_ease-out]" />
                )}
              </Link>
            )
          })}

          {/* ── Mehr button ── */}
          <button
            onClick={() => setShowMore(true)}
            className={cn(
              'relative flex flex-col items-center justify-center gap-0.5 touch-target py-1.5 rounded-xl transition-all',
              showMore ? 'text-primary-600' : 'text-gray-500 hover:text-gray-700',
            )}
          >
            <div className="relative">
              <Menu className="w-5 h-5" />
              {moreBadgeTotal > 0 && (
                <span className="absolute -top-1.5 -right-2 min-w-[16px] h-4 bg-amber-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1 animate-badge-pop">
                  {moreBadgeTotal > 99 ? '99+' : moreBadgeTotal}
                </span>
              )}
            </div>
            <span
              className={cn(
                'text-[10px] font-medium leading-tight',
                showMore ? 'text-primary-600 font-semibold' : 'text-gray-500',
              )}
            >
              {t('more')}
            </span>
          </button>
        </div>
      </nav>

      {/* ── More Bottom Sheet (custom, no new deps) ── */}
      {showMore && (
        <div className="md:hidden fixed inset-0 z-50">
          {/* Overlay */}
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-sm transition-opacity duration-300"
            onClick={() => setShowMore(false)}
          />

          {/* Sheet – slides up from bottom */}
          <div
            className={cn(
              'absolute bottom-0 left-0 right-0 bg-white rounded-t-2xl shadow-2xl',
              'transition-transform duration-300 ease-out',
              'max-h-[70vh] flex flex-col',
              showMore ? 'translate-y-0' : 'translate-y-full',
            )}
          >
            {/* Drag handle */}
            <div className="flex-shrink-0 flex justify-center py-2">
              <div className="w-10 h-1 bg-gray-300 rounded-full" />
            </div>

            {/* Scrollable content */}
            <div className="flex-1 overflow-y-auto overscroll-contain px-3 pb-safe-area-bottom pb-6 space-y-1">
              {/* Notification link with badge */}
              <Link
                href="/dashboard/notifications"
                onClick={() => setShowMore(false)}
                className="flex items-center gap-3 px-3 py-3 rounded-xl bg-gray-50 hover:bg-gray-100 transition-colors mb-2"
              >
                <Bell className="w-5 h-5 text-gray-500" />
                <span className="text-sm font-medium text-gray-700 flex-1">{t('notifications')}</span>
                {unreadNotifications > 0 && (
                  <span className="min-w-[20px] h-5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1.5 animate-badge-pop">
                    {unreadNotifications > 99 ? '99+' : unreadNotifications}
                  </span>
                )}
              </Link>

              {/* All six navGroups as collapsible sections */}
              {sheetGroups.map((group) => (
                <SheetGroup
                  key={group.id}
                  group={group}
                  getBadge={getBadge}
                  onNavigate={handleNavigate}
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </>
  )
}
