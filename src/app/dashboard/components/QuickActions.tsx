'use client'

import Link from 'next/link'
import { PlusCircle, Map, MessageCircle, Search } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { Badge } from '@/components/ui'
import { useNavigationStore } from '@/store/useNavigationStore'

interface QuickActionsProps {
  unreadCount: number
}

const actions = [
  {
    id: 'create',
    icon: PlusCircle,
    label: 'Beitrag erstellen',
    href: '/dashboard/create' as string | null,
    gradient: 'from-primary-500 to-primary-600',
    glow: 'rgba(30,170,166,0.35)',
    iconColor: 'text-white',
  },
  {
    id: 'map',
    icon: Map,
    label: 'Karte öffnen',
    href: '/dashboard/map' as string | null,
    gradient: 'from-primary-400 to-teal-500',
    glow: 'rgba(30,170,166,0.25)',
    iconColor: 'text-white',
  },
  {
    id: 'chat',
    icon: MessageCircle,
    label: 'Nachrichten',
    href: '/dashboard/chat' as string | null,
    gradient: 'from-[#4F6D8A] to-[#3a5470]',
    glow: 'rgba(79,109,138,0.3)',
    iconColor: 'text-white',
  },
  {
    id: 'search',
    icon: Search,
    label: 'Suche',
    href: null,
    gradient: 'from-stone-700 to-stone-800',
    glow: 'rgba(87,83,78,0.25)',
    iconColor: 'text-white',
  },
]

export default function QuickActions({ unreadCount }: QuickActionsProps) {
  const { toggleSearch } = useNavigationStore()

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      {actions.map((action, i) => {
        const Icon = action.icon
        const inner = (
          <div
            className={cn(
              'shine relative rounded-2xl p-4 flex flex-col items-center gap-2.5 overflow-hidden',
              'cursor-pointer transition-all duration-300',
              'hover:scale-[1.04] hover:-translate-y-0.5',
              `bg-gradient-to-br ${action.gradient}`,
            )}
            style={{
              boxShadow: `0 4px 20px ${action.glow}, 0 1px 4px rgba(0,0,0,0.08)`,
              animationDelay: `${i * 60}ms`,
            }}
          >
            {/* Noise grain overlay */}
            <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />

            {/* Icon with float-idle */}
            <div className="relative z-10 float-idle" style={{ animationDelay: `${i * 0.4}s` }}>
              <Icon className={cn('w-6 h-6', action.iconColor)} strokeWidth={1.75} />
            </div>

            <span className={cn('relative z-10 text-xs font-semibold tracking-wide', action.iconColor, 'opacity-90')}>
              {action.label}
            </span>

            {action.id === 'chat' && unreadCount > 0 && (
              <Badge
                variant="danger"
                size="sm"
                animated
                className="absolute top-2 right-2 min-w-[20px] h-5 flex items-center justify-center z-20"
              >
                {unreadCount > 9 ? '9+' : unreadCount}
              </Badge>
            )}
          </div>
        )

        if (action.href) {
          return (
            <Link key={action.id} href={action.href} className="reveal" style={{ animationDelay: `${i * 70}ms` }}>
              {inner}
            </Link>
          )
        }

        return (
          <button
            key={action.id}
            onClick={toggleSearch}
            className="reveal text-left"
            style={{ animationDelay: `${i * 70}ms` }}
          >
            {inner}
          </button>
        )
      })}
    </div>
  )
}
