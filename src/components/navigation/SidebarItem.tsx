'use client'

import { useState } from 'react'
import Link from 'next/link'
import toast from 'react-hot-toast'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import type { NavItemConfig } from './navigationConfig'

interface SidebarItemProps {
  item: NavItemConfig
  active: boolean
  collapsed: boolean
  badge?: number
  onClick?: () => void
  onContextMenu?: () => void
}

export default function SidebarItem({ item, active, collapsed, badge, onClick, onContextMenu }: SidebarItemProps) {
  const t = useTranslations('nav')
  const Icon = item.icon
  const isCrisis = item.variant === 'crisis'
  const isHighlight = item.variant === 'highlight'
  const isComingSoon = item.comingSoon
  const [showTooltip, setShowTooltip] = useState(false)
  const label = t(item.label as Parameters<typeof t>[0])

  const handleClick = (e: React.MouseEvent) => {
    if (isComingSoon) {
      e.preventDefault()
      toast(`${label} – ${t('comingSoon')} 🚀`, { icon: '🔜' })
      return
    }
    onClick?.()
  }

  const handleContextMenu = (e: React.MouseEvent) => {
    if (onContextMenu) {
      e.preventDefault()
      onContextMenu()
    }
  }

  const content = (
    <>
      {/* Left accent bar */}
      {active && !collapsed && (
        <div className="absolute left-0 top-2 bottom-2 w-[3px] rounded-r-full bg-primary-500 animate-[scaleIn_0.2s_ease-out]" />
      )}

      {/* Icon */}
      <div
        className={cn(
          'flex-shrink-0 rounded-lg flex items-center justify-center transition-all duration-200',
          collapsed ? 'w-9 h-9' : 'w-8 h-8',
          active
            ? isCrisis
              ? 'bg-red-500 shadow-sm'
              : 'green-gradient shadow-sm'
            : isHighlight && !isComingSoon
              ? 'bg-primary-100 group-hover:bg-primary-200'
              : 'bg-stone-100 group-hover:bg-gray-200',
        )}
      >
        <Icon
          className={cn(
            'transition-colors duration-200',
            collapsed ? 'w-4.5 h-4.5' : 'w-4 h-4',
            active
              ? 'text-white'
              : isCrisis
                ? 'text-red-500 group-hover:text-red-600'
                : isHighlight && !isComingSoon
                  ? 'text-primary-600'
                  : 'text-ink-500 group-hover:text-ink-700',
          )}
        />
      </div>

      {/* Label */}
      {!collapsed && (
        <span
          className={cn(
            'truncate flex-1 text-[13px] leading-tight transition-colors',
            isComingSoon && 'opacity-60',
          )}
        >
          {label}
        </span>
      )}

      {/* Badge */}
      {badge !== undefined && badge > 0 && (
        <span
          className={cn(
            'font-bold bg-red-500 text-white rounded-full flex items-center justify-center flex-shrink-0 animate-badge-pop',
            collapsed
              ? 'absolute -top-1 -right-1 w-4 h-4 text-[9px]'
              : 'min-w-[20px] h-5 px-1 text-[10px]',
          )}
        >
          {badge > 99 ? '99+' : badge}
        </span>
      )}

      {/* Coming Soon tag */}
      {isComingSoon && !collapsed && (
        <span className="text-[9px] font-bold uppercase tracking-wider text-ink-400 bg-stone-100 px-1.5 py-0.5 rounded-md flex-shrink-0">
          Bald
        </span>
      )}

      {/* Crisis pulse */}
      {isCrisis && !active && !collapsed && (
        <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
      )}
    </>
  )

  // ── Tooltip for collapsed mode ──
  const tooltip = collapsed ? (
    <div
      className={cn(
        'absolute left-full top-1/2 -translate-y-1/2 ml-3 z-50 pointer-events-none transition-all duration-150',
        showTooltip ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-1',
      )}
    >
      <div className="px-2.5 py-1.5 bg-gray-900 text-white text-xs font-medium rounded-lg whitespace-nowrap shadow-lg">
        {label}
        {badge !== undefined && badge > 0 && (
          <span className="ml-1.5 px-1.5 py-0.5 bg-red-500 text-white text-[9px] font-bold rounded-full">
            {badge}
          </span>
        )}
      </div>
      {/* Arrow */}
      <div className="absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1 w-2 h-2 bg-gray-900 rotate-45" />
    </div>
  ) : null

  const className = cn(
    'group relative flex items-center rounded-xl transition-all duration-200 select-none',
    collapsed ? 'h-10 w-10 mx-auto justify-center' : 'gap-2.5 px-3 py-2',
    active
      ? isCrisis
        ? 'bg-red-50 text-red-700 font-semibold border border-red-200'
        : 'bg-primary-50 text-primary-800 font-semibold border border-primary-200'
      : cn(
          'text-ink-600 border border-transparent',
          isComingSoon
            ? 'hover:bg-stone-50 cursor-default'
            : 'hover:bg-stone-50 hover:text-ink-900',
          isHighlight && !isComingSoon && !active && 'bg-primary-50/50 border-primary-100 hover:bg-primary-50',
        ),
  )

  const mouseHandlers = collapsed ? {
    onMouseEnter: () => setShowTooltip(true),
    onMouseLeave: () => setShowTooltip(false),
  } : {}

  if (isComingSoon) {
    return (
      <div className="relative" {...mouseHandlers}>
        <button
          onClick={handleClick}
          onContextMenu={handleContextMenu}
          className={cn(className, 'w-full text-left')}
          title={collapsed ? label : undefined}
        >
          {content}
        </button>
        {tooltip}
      </div>
    )
  }

  return (
    <div className="relative" {...mouseHandlers}>
      <Link
        href={item.path}
        onClick={handleClick}
        onContextMenu={handleContextMenu}
        className={className}
        title={collapsed ? label : undefined}
      >
        {content}
      </Link>
      {tooltip}
    </div>
  )
}
