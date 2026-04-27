'use client'

import { useCallback } from 'react'
import Link from 'next/link'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { useNavigation } from '@/hooks/useNavigation'
import { useKeyboard } from '@/hooks/mobile'
import { bottomNavItems } from './navigationConfig'
import { useNavigationStore } from '@/store/useNavigationStore'

interface BottomNavProps {
  unreadMessages: number
  unreadNotifications: number
  activeCrises?: number
  suggestedMatches?: number
  interactionRequests?: number
}


// ═══════════════════════════════════════════════════════════════════════
// BottomNav
// ═══════════════════════════════════════════════════════════════════════
export default function BottomNav({
  unreadMessages,
  unreadNotifications,
  activeCrises: _activeCrises = 0,
  suggestedMatches: _suggestedMatches = 0,
  interactionRequests: _interactionRequests = 0,
}: BottomNavProps) {
  const t = useTranslations('nav')
  const { isActive, isExactActive } = useNavigation()
  const { isOpen: keyboardOpen } = useKeyboard()
  const isInCall = useNavigationStore(s => s.isInCall)

  const getBadge = useCallback(
    (badgeKey?: string): number | undefined => {
      if (badgeKey === 'unreadMessages') return unreadMessages || undefined
      if (badgeKey === 'unreadNotifications') return unreadNotifications || undefined
      return undefined
    },
    [unreadMessages, unreadNotifications],
  )

  // First 5 items (Home, Karte, Erstellen, Chat, Benachrichtigungen).
  // Full navigation lives in the left sidebar, opened via the top-left ☰ menu.
  const visibleItems = bottomNavItems.slice(0, 5)

  return (
    <>
      {/* ── Bottom Navigation Bar ── */}
      <nav
        className={cn(
          'md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-stone-200 shadow-[0_-4px_12px_-4px_rgba(0,0,0,0.08)] safe-area-bottom',
          'transition-transform duration-300 ease-out',
          (keyboardOpen || isInCall) && 'translate-y-full',
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
                prefetch
                className={cn(
                  'relative flex flex-col items-center justify-center gap-0.5 touch-target py-1.5 rounded-xl transition-all',
                  active ? 'text-primary-600' : 'text-ink-500 hover:text-ink-700',
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
                    'text-xs font-medium leading-tight',
                    isHighlight && '-mt-0.5',
                    active ? 'text-primary-600 font-semibold' : 'text-ink-500',
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
        </div>
      </nav>
    </>
  )
}
