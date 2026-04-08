'use client'

import Link from 'next/link'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'
import type { NavItemConfig } from './navigationConfig'

interface SidebarItemProps {
  item: NavItemConfig
  active: boolean
  collapsed: boolean
  badge?: number
  onClick?: () => void
}

export default function SidebarItem({ item, active, collapsed, badge, onClick }: SidebarItemProps) {
  const Icon = item.icon
  const isCrisis = item.variant === 'crisis'
  const isHighlight = item.variant === 'highlight'
  const isComingSoon = item.comingSoon

  const handleClick = (e: React.MouseEvent) => {
    if (isComingSoon) {
      e.preventDefault()
      toast('Diese Funktion kommt bald! 🚀', { icon: '🔜' })
      return
    }
    onClick?.()
  }

  const content = (
    <>
      {/* Left accent bar */}
      {active && !collapsed && (
        <div className="absolute left-0 top-2 bottom-2 w-[3px] rounded-r-full bg-primary-500" />
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
              : 'bg-gray-100 group-hover:bg-gray-200',
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
                  : 'text-gray-500 group-hover:text-gray-700',
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
          {item.label}
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
        <span className="text-[9px] font-bold uppercase tracking-wider text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded-md flex-shrink-0">
          Bald
        </span>
      )}

      {/* Crisis pulse */}
      {isCrisis && !active && !collapsed && (
        <span className="w-2 h-2 bg-red-400 rounded-full animate-pulse flex-shrink-0" />
      )}
    </>
  )

  const className = cn(
    'group relative flex items-center rounded-xl transition-all duration-200 select-none',
    collapsed ? 'h-10 w-10 mx-auto justify-center' : 'gap-2.5 px-3 py-2',
    active
      ? isCrisis
        ? 'bg-red-50 text-red-700 font-semibold border border-red-200'
        : 'bg-primary-50 text-primary-800 font-semibold border border-primary-200'
      : cn(
          'text-gray-600 border border-transparent',
          isComingSoon
            ? 'hover:bg-gray-50 cursor-default'
            : 'hover:bg-gray-50 hover:text-gray-900',
          isHighlight && !isComingSoon && !active && 'bg-primary-50/50 border-primary-100 hover:bg-primary-50',
        ),
  )

  if (isComingSoon) {
    return (
      <button onClick={handleClick} className={cn(className, 'w-full text-left')} title={collapsed ? item.label : undefined}>
        {content}
      </button>
    )
  }

  return (
    <Link href={item.path} onClick={handleClick} className={className} title={collapsed ? item.label : undefined}>
      {content}
    </Link>
  )
}
