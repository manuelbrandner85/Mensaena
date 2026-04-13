'use client'

import { useRef, useEffect } from 'react'
import {
  MessageCircle, Handshake, Star, MapPin, MessageSquare, Info,
  MessageSquareText,
} from 'lucide-react'
import type { NotificationFilter, UnreadCounts } from '@/store/useNotificationStore'

interface Props {
  activeFilter: NotificationFilter
  unreadCounts: UnreadCounts
  onFilterChange: (filter: NotificationFilter) => void
}

const FILTERS: { value: NotificationFilter; label: string; Icon: typeof MessageCircle }[] = [
  { value: 'all', label: 'Alle', Icon: Info },
  { value: 'message', label: 'Nachrichten', Icon: MessageCircle },
  { value: 'interaction', label: 'Interaktionen', Icon: Handshake },
  { value: 'trust_rating', label: 'Bewertungen', Icon: Star },
  { value: 'post_nearby', label: 'In der Nähe', Icon: MapPin },
  { value: 'post_response', label: 'Antworten', Icon: MessageSquare },
  { value: 'comment', label: 'Kommentare', Icon: MessageSquareText },
  { value: 'system', label: 'System', Icon: Info },
]

function getCount(filter: NotificationFilter, counts: UnreadCounts): number {
  if (filter === 'all') return counts.total
  return counts[filter] ?? 0
}

export default function NotificationFilters({ activeFilter, unreadCounts, onFilterChange }: Props) {
  const scrollRef = useRef<HTMLDivElement>(null)
  const activeRef = useRef<HTMLButtonElement>(null)

  // Scroll active tab into view
  useEffect(() => {
    activeRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' })
  }, [activeFilter])

  return (
    <div
      ref={scrollRef}
      className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide -mx-1 px-1"
    >
      {FILTERS.map(({ value, label, Icon }) => {
        const isActive = activeFilter === value
        const count = getCount(value, unreadCounts)

        return (
          <button
            key={value}
            ref={isActive ? activeRef : undefined}
            onClick={() => onFilterChange(value)}
            className={`px-3 py-2 rounded-full text-sm font-medium flex items-center gap-1.5 whitespace-nowrap transition-colors ${
              isActive
                ? 'bg-primary-100 text-primary-700'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <Icon className="w-3.5 h-3.5" />
            {label}
            {count > 0 && (
              <span className="bg-red-500 text-white text-[10px] rounded-full min-w-[18px] h-[18px] px-1 flex items-center justify-center font-bold">
                {count > 99 ? '99+' : count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}
