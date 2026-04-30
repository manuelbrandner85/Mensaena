'use client'

import { useRef, useEffect } from 'react'
import {
  Inbox, MessageCircle, Handshake, Star, MapPin, MessageSquare, Info,
  MessageSquareText,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import type { NotificationFilter, UnreadCounts } from '@/store/useNotificationStore'

interface Props {
  activeFilter: NotificationFilter
  unreadCounts: UnreadCounts
  onFilterChange: (filter: NotificationFilter) => void
}

const FILTERS: { value: NotificationFilter; label: string; Icon: typeof Inbox }[] = [
  { value: 'all',           label: 'Alle',          Icon: Inbox },
  { value: 'message',       label: 'Nachrichten',   Icon: MessageCircle },
  { value: 'interaction',   label: 'Interaktionen', Icon: Handshake },
  { value: 'trust_rating',  label: 'Bewertungen',   Icon: Star },
  { value: 'post_nearby',   label: 'In der Nähe',   Icon: MapPin },
  { value: 'post_response', label: 'Antworten',     Icon: MessageSquare },
  { value: 'comment',       label: 'Kommentare',    Icon: MessageSquareText },
  { value: 'system',        label: 'System',        Icon: Info },
]

function getCount(filter: NotificationFilter, counts: UnreadCounts): number {
  if (filter === 'all') return counts.total
  return counts[filter as keyof UnreadCounts] ?? 0
}

export default function NotificationFilters({ activeFilter, unreadCounts, onFilterChange }: Props) {
  const scrollRef = useRef<HTMLDivElement>(null)
  const activeRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    activeRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' })
  }, [activeFilter])

  return (
    <div
      ref={scrollRef}
      className="flex gap-1.5 overflow-x-auto pb-1 scrollbar-hide"
    >
      {FILTERS.map(({ value, label, Icon }) => {
        const isActive = activeFilter === value
        const count = getCount(value, unreadCounts)

        return (
          <button
            key={value}
            ref={isActive ? activeRef : undefined}
            onClick={() => onFilterChange(value)}
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all duration-150 flex-shrink-0',
              isActive
                ? 'bg-primary-600 text-white shadow-sm'
                : 'bg-white border border-stone-200 text-ink-600 hover:border-primary-300 hover:text-primary-700 hover:bg-primary-50',
            )}
          >
            <Icon className="w-3.5 h-3.5" />
            {label}
            {count > 0 && (
              <span className={cn(
                'text-[10px] font-bold rounded-full min-w-[16px] h-4 px-1 flex items-center justify-center leading-none',
                isActive
                  ? 'bg-white/20 text-white'
                  : 'bg-red-500 text-white',
              )}>
                {count > 99 ? '99+' : count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}
