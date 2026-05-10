'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { ChevronDown } from 'lucide-react'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import type { NavGroupConfig, NavItemConfig } from './navigationConfig'

interface SidebarGroupProps {
  group: NavGroupConfig
  isCollapsed: boolean
  getBadge: (badgeKey?: string) => number | undefined
}

export default function SidebarGroup({ group, isCollapsed, getBadge }: SidebarGroupProps) {
  const t = useTranslations('nav')
  const pathname = usePathname()
  const GroupIcon = group.icon

  // Check if any child is active
  const hasActiveChild = group.items.some(
    (item) => pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
  )

  const [isOpen, setIsOpen] = useState(hasActiveChild)

  // Auto-open group when navigating into it
  useEffect(() => {
    if (hasActiveChild && !isOpen) {
      setIsOpen(true)
    }
  }, [pathname]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── COLLAPSED MODE: icon button with hover flyout ──
  if (isCollapsed) {
    return (
      <div className="group/nav relative mt-1">
        <button
          className={cn(
            'w-full flex items-center justify-center p-2 rounded-lg text-mn-mute hover:bg-mn-elevated/5 transition-colors',
            hasActiveChild && 'bg-mn-amber/5 text-mn-amber',
          )}
          aria-label={t(group.title as Parameters<typeof t>[0])}
        >
          {GroupIcon && <GroupIcon className="w-4.5 h-4.5" />}
        </button>

        {/* Flyout on hover */}
        <div className="invisible group-hover/nav:visible opacity-0 group-hover/nav:opacity-100 transition-all duration-150 absolute left-full top-0 ml-2 z-50">
          <div className="bg-mn-elevated rounded-xl shadow-xl border border-white/5 py-2 min-w-[200px]">
            {/* Group title */}
            <div className="px-3 py-1 text-xs font-semibold text-mn-mute uppercase tracking-wider">
              {t(group.title as Parameters<typeof t>[0])}
            </div>
            {/* Child items */}
            {group.items.map((item) => {
              const Icon = item.icon
              const isCrisis = item.variant === 'crisis'
              const active = pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
              const badge = getBadge(item.badgeKey)

              return (
                <Link
                  key={item.id}
                  href={item.path}
                  className={cn(
                    'flex items-center gap-2.5 px-3 py-2 text-sm transition-colors',
                    active
                      ? isCrisis
                        ? 'bg-mn-surface text-mn-herzrot font-semibold'
                        : 'bg-mn-amber/5 text-mn-amber font-semibold'
                      : 'text-mn-ink-soft hover:bg-mn-elevated/[0.02]',
                  )}
                >
                  <Icon className={cn(
                    'w-4 h-4 flex-shrink-0',
                    active ? (isCrisis ? 'text-mn-herzrot' : 'text-mn-amber') : (isCrisis ? 'text-mn-herzrot' : 'text-mn-mute'),
                  )} />
                  <span className="flex-1 truncate">{t(item.label as Parameters<typeof t>[0])}</span>
                  {badge !== undefined && badge > 0 && (
                    <span className="min-w-[18px] h-[18px] bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1">
                      {badge > 99 ? '99+' : badge}
                    </span>
                  )}
                  {isCrisis && !active && (
                    <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
                  )}
                </Link>
              )
            })}
          </div>
        </div>
      </div>
    )
  }

  // ── EXPANDED MODE: collapsible group with header ──
  return (
    <div className="mt-3">
      {/* Group header – clickable to toggle */}
      <button
        onClick={() => setIsOpen((o) => !o)}
        className="w-full flex items-center gap-2 px-3 py-1.5 group hover:bg-mn-elevated/[0.02] rounded-lg transition-colors"
      >
        {GroupIcon && (
          <GroupIcon className={cn(
            'w-3.5 h-3.5 flex-shrink-0 transition-colors',
            hasActiveChild ? 'text-mn-amber' : 'text-mn-mute group-hover:text-mn-mute',
          )} />
        )}
        <span className={cn(
          'text-xs font-semibold uppercase tracking-wider select-none whitespace-nowrap transition-colors',
          hasActiveChild ? 'text-mn-amber' : 'text-mn-mute group-hover:text-mn-mute',
        )}>
          {t(group.title as Parameters<typeof t>[0])}
        </span>
        <div className="flex-1 h-px bg-gradient-to-r from-stone-200 to-transparent" />
        <ChevronDown
          className={cn(
            'w-3 h-3 text-mn-mute transition-transform duration-200 flex-shrink-0',
            isOpen ? 'rotate-0' : '-rotate-90',
          )}
        />
      </button>

      {/* Items – collapsible */}
      <div
        className={cn(
          'overflow-hidden transition-all duration-200 ease-out',
          isOpen ? 'max-h-96 opacity-100 mt-0.5' : 'max-h-0 opacity-0',
        )}
      >
        <div className="space-y-0.5 px-1">
          {group.items.map((item) => {
            const Icon = item.icon
            const isCrisis = item.variant === 'crisis'
            const isHighlight = item.variant === 'highlight'
            const active = pathname === item.path || (item.path !== '/dashboard' && pathname.startsWith(item.path))
            const badge = getBadge(item.badgeKey)

            return (
              <Link
                key={item.id}
                href={item.path}
                className={cn(
                  'group relative flex items-center gap-2.5 px-3 py-2 rounded-xl transition-all duration-200 select-none',
                  active
                    ? isCrisis
                      ? 'bg-mn-surface text-mn-herzrot font-semibold border border-mn-herzrot/20'
                      : 'bg-mn-amber/5 text-primary-800 font-semibold border border-mn-amber/20'
                    : cn(
                        'text-mn-ink-soft border border-transparent hover:bg-mn-elevated/[0.02] hover:text-mn-ink',
                        isHighlight && !active && 'bg-mn-amber/5/50 border-white/8 hover:bg-mn-amber/5',
                      ),
                )}
              >
                {/* Left accent bar */}
                {active && (
                  <div className="absolute left-0 top-2 bottom-2 w-[3px] rounded-r-full bg-mn-amber" />
                )}

                {/* Icon */}
                <div
                  className={cn(
                    'flex-shrink-0 rounded-lg w-8 h-8 flex items-center justify-center transition-all duration-200',
                    active
                      ? isCrisis ? 'bg-red-500 shadow-sm' : 'green-gradient shadow-sm'
                      : 'bg-mn-elevated group-hover:bg-mn-raised',
                  )}
                >
                  <Icon className={cn(
                    'w-4 h-4 transition-colors duration-200',
                    active
                      ? 'text-white'
                      : isCrisis ? 'text-mn-herzrot group-hover:text-mn-herzrot' : 'text-mn-mute group-hover:text-mn-ink-soft',
                  )} />
                </div>

                {/* Label */}
                <span className="truncate flex-1 text-[13px] leading-tight">{t(item.label as Parameters<typeof t>[0])}</span>

                {/* Badge */}
                {badge !== undefined && badge > 0 && (
                  <span className="font-bold bg-red-500 text-white rounded-full min-w-[20px] h-5 px-1 text-xs flex items-center justify-center flex-shrink-0 animate-badge-pop">
                    {badge > 99 ? '99+' : badge}
                  </span>
                )}

                {/* Crisis pulse */}
                {isCrisis && !active && (
                  <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
                )}
              </Link>
            )
          })}
        </div>
      </div>
    </div>
  )
}
