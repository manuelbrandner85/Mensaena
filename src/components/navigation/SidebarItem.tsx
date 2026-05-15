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
        <div className="absolute left-0 top-2 bottom-2 w-[3px] rounded-r-full bg-mn-bronze animate-[scaleIn_0.2s_ease-out]" />
      )}

      {/* Icon */}
      <div
        className={cn(
          'flex-shrink-0 rounded-lg flex items-center justify-center transition-all duration-200',
          collapsed ? 'w-9 h-9' : 'w-8 h-8',
          active
            ? isCrisis
              ? 'bg-mn-herzrot shadow-sm'
              : 'bg-mn-bronze shadow-bronze-soft'
            : isHighlight && !isComingSoon
              ? 'bg-mn-bronze/10 group-hover:bg-mn-bronze/15'
              : 'bg-mn-elevated group-hover:bg-mn-raised',
        )}
      >
        <Icon
          className={cn(
            'transition-colors duration-200',
            collapsed ? 'w-4.5 h-4.5' : 'w-4 h-4',
            active
              ? 'text-white'
              : isCrisis
                ? 'text-mn-herzrot group-hover:text-mn-herzrot'
                : isHighlight && !isComingSoon
                  ? 'text-mn-bronze'
                  : 'text-mn-mute group-hover:text-mn-ink-soft',
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
            'font-bold bg-mn-herzrot text-white rounded-full flex items-center justify-center flex-shrink-0 animate-badge-pop',
            collapsed
              ? 'absolute -top-1 -right-1 w-4 h-4 text-[9px]'
              : 'min-w-[20px] h-5 px-1 text-xs',
          )}
        >
          {badge > 99 ? '99+' : badge}
        </span>
      )}

      {/* Coming Soon tag */}
      {isComingSoon && !collapsed && (
        <span className="text-[9px] font-bold uppercase tracking-wider text-mn-mute bg-mn-elevated px-1.5 py-0.5 rounded-md flex-shrink-0">
          Bald
        </span>
      )}

      {/* Crisis pulse */}
      {isCrisis && !active && !collapsed && (
        <span
          className="w-2 h-2 bg-mn-herzrot rounded-full animate-pulse flex-shrink-0"
          style={{ boxShadow: '0 0 8px rgba(239,68,68,0.6)' }}
        />
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
      <div
        className="px-2.5 py-1.5 bg-mn-elevated text-mn-ink text-xs font-medium rounded-lg whitespace-nowrap border border-white/5"
        style={{ boxShadow: '0 8px 24px rgba(0,0,0,0.50), 0 0 24px rgba(199,147,99,0.10)' }}
      >
        {label}
        {badge !== undefined && badge > 0 && (
          <span className="ml-1.5 px-1.5 py-0.5 bg-mn-herzrot text-white text-[9px] font-bold rounded-full">
            {badge}
          </span>
        )}
      </div>
      {/* Arrow */}
      <div className="absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1 w-2 h-2 bg-mn-elevated rotate-45 border-l border-b border-white/5" />
    </div>
  ) : null

  const className = cn(
    'group relative flex items-center rounded-xl transition-all duration-200 select-none',
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-mn-bronze focus-visible:ring-offset-1 focus-visible:ring-offset-mn-void',
    collapsed ? 'h-10 w-10 mx-auto justify-center' : 'gap-2.5 px-3 py-2',
    active
      ? isCrisis
        ? 'bg-mn-surface text-mn-herzrot font-semibold border border-mn-herzrot/20'
        : 'bg-mn-bronze/10 text-mn-bronze font-semibold border border-mn-bronze/20'
      : cn(
          'text-mn-ink-soft border border-transparent',
          isComingSoon
            ? 'hover:bg-mn-elevated/[0.02] cursor-default'
            : 'hover:bg-mn-elevated/[0.02] hover:text-mn-ink',
          isHighlight && !isComingSoon && !active && 'bg-mn-bronze/5 border-white/5 hover:bg-mn-bronze/10',
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
        aria-current={active ? 'page' : undefined}
        aria-label={collapsed ? label : undefined}
      >
        {content}
      </Link>
      {tooltip}
    </div>
  )
}
