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
  { id: 'create', icon: PlusCircle, label: 'Beitrag erstellen', href: '/dashboard/create', bg: 'bg-primary-50 hover:bg-primary-100', text: 'text-primary-600' },
  { id: 'map', icon: Map, label: 'Karte öffnen', href: '/dashboard/map', bg: 'bg-primary-100/50 hover:bg-primary-100', text: 'text-primary-700' },
  { id: 'chat', icon: MessageCircle, label: 'Nachrichten', href: '/dashboard/chat', bg: 'bg-trust-50 hover:bg-trust-100', text: 'text-trust-500' },
  { id: 'search', icon: Search, label: 'Suche', href: null as string | null, bg: 'bg-primary-50/50 hover:bg-primary-100', text: 'text-primary-500' },
]

export default function QuickActions({ unreadCount }: QuickActionsProps) {
  const { toggleSearch } = useNavigationStore()

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
      {actions.map((action) => {
        const Icon = action.icon
        const inner = (
          <div className={cn(
            'relative rounded-xl p-4 flex flex-col items-center gap-2',
            'cursor-pointer transition-all duration-200 hover:scale-[1.02] hover:shadow-sm',
            action.bg,
          )}>
            <Icon className={cn('w-6 h-6', action.text)} />
            <span className={cn('text-sm font-medium', action.text)}>{action.label}</span>
            {action.id === 'chat' && unreadCount > 0 && (
              <Badge
                variant="danger"
                size="sm"
                animated
                className="absolute top-2 right-2 min-w-[20px] h-5 flex items-center justify-center"
              >
                {unreadCount > 9 ? '9+' : unreadCount}
              </Badge>
            )}
          </div>
        )

        if (action.href) {
          return (
            <Link key={action.id} href={action.href}>
              {inner}
            </Link>
          )
        }

        return (
          <button key={action.id} onClick={toggleSearch} className="text-left">
            {inner}
          </button>
        )
      })}
    </div>
  )
}
