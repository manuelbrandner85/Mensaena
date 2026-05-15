'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/design-system'
import ProfilOrb from './ProfilOrb'

export interface SidebarItem {
  href: string
  label: string
  icon: React.ReactNode
  badge?: number
}

export interface SidebarGroup {
  label?: string
  items: SidebarItem[]
}

interface CinemaSidebarProps {
  groups: SidebarGroup[]
  user?: { name?: string | null; avatar?: string | null; email?: string | null }
  collapsed?: boolean
}

export default function CinemaSidebar({ groups, user, collapsed = false }: CinemaSidebarProps) {
  const pathname = usePathname()

  return (
    <aside
      className={cn(
        'hidden md:flex flex-col shrink-0 h-full',
        'bg-mn-deep border-r border-white/5 transition-all duration-300',
        collapsed ? 'w-16' : 'w-60',
      )}
    >
      <div className="flex-1 overflow-y-auto py-4 space-y-6 px-3">
        {groups.map((group, gi) => (
          <div key={gi}>
            {group.label && !collapsed && (
              <div className="px-2 mb-2 text-[11px] font-mono font-medium text-mn-mute uppercase tracking-widest">
                {group.label}
              </div>
            )}
            <ul className="space-y-0.5">
              {group.items.map(item => {
                const active = pathname === item.href || pathname.startsWith(item.href + '/')
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className={cn(
                        'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200',
                        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-mn-bronze focus-visible:ring-inset',
                        active
                          ? 'text-mn-bronze bg-mn-bronze/5 border-l-2 border-mn-bronze'
                          : 'text-mn-ink-soft hover:text-mn-ink hover:bg-mn-elevated/[0.02] border-l-2 border-transparent',
                        collapsed && 'justify-center px-0',
                      )}
                    >
                      <span className={cn('shrink-0', active ? 'text-mn-bronze' : 'text-mn-mute')}>
                        {item.icon}
                      </span>
                      {!collapsed && (
                        <span className="flex-1 truncate">{item.label}</span>
                      )}
                      {!collapsed && item.badge != null && item.badge > 0 && (
                        <span className="min-w-[18px] h-[18px] px-1 rounded-full bg-mn-herzrot text-white text-[10px] font-mono flex items-center justify-center">
                          {item.badge > 99 ? '99+' : item.badge}
                        </span>
                      )}
                    </Link>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </div>

      {user && (
        <div className={cn('p-3 border-t border-white/5', collapsed && 'flex justify-center')}>
          <div className={cn('flex items-center gap-3 rounded-xl p-2', !collapsed && 'px-2')}>
            <ProfilOrb src={user.avatar} name={user.name} size="sm" status="online" />
            {!collapsed && (
              <div className="min-w-0 flex-1">
                <div className="text-sm font-medium text-mn-ink truncate">{user.name}</div>
                <div className="text-xs text-mn-mute truncate">{user.email}</div>
              </div>
            )}
          </div>
        </div>
      )}
    </aside>
  )
}
