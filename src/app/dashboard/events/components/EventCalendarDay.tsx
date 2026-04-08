'use client'

import { cn } from '@/lib/utils'
import type { EventItem } from '../hooks/useEvents'
import { getCategoryDotColor, isToday as checkIsToday } from '../hooks/useEvents'

interface EventCalendarDayProps {
  date: Date
  events: EventItem[]
  isCurrentMonth: boolean
  onSelect: (date: Date) => void
}

export default function EventCalendarDay({ date, events, isCurrentMonth, onSelect }: EventCalendarDayProps) {
  const today = checkIsToday(date)
  const hasEvents = events.length > 0
  const maxShow = 3

  return (
    <button
      onClick={() => hasEvents && onSelect(date)}
      className={cn(
        'min-h-[70px] md:min-h-[90px] border border-gray-100 p-1 text-left transition-colors relative',
        hasEvents ? 'cursor-pointer hover:bg-purple-50/50' : 'cursor-default',
        !isCurrentMonth && 'bg-gray-50/50',
      )}
    >
      {/* Day number */}
      <div className="flex justify-end">
        <span
          className={cn(
            'text-xs md:text-sm leading-none',
            today
              ? 'w-6 h-6 bg-purple-600 text-white rounded-full flex items-center justify-center font-semibold'
              : isCurrentMonth
                ? 'text-gray-900 font-medium'
                : 'text-gray-300',
          )}
        >
          {date.getDate()}
        </span>
      </div>

      {/* Events */}
      {hasEvents && (
        <div className="mt-0.5 space-y-0.5">
          {/* Desktop: bars with text */}
          <div className="hidden md:block">
            {events.slice(0, maxShow).map((ev) => (
              <div key={ev.id} className="flex items-center gap-1 mb-0.5">
                <div className={cn('h-1.5 w-1.5 rounded-full flex-shrink-0', getCategoryDotColor(ev.category))} />
                <span className="text-[10px] text-gray-700 truncate leading-tight">{ev.title}</span>
              </div>
            ))}
          </div>

          {/* Mobile: dots only */}
          <div className="flex gap-0.5 md:hidden flex-wrap">
            {events.slice(0, maxShow).map((ev) => (
              <div key={ev.id} className={cn('w-1.5 h-1.5 rounded-full', getCategoryDotColor(ev.category))} />
            ))}
          </div>

          {events.length > maxShow && (
            <span className="text-[10px] text-gray-500 leading-none">+{events.length - maxShow} weitere</span>
          )}
        </div>
      )}
    </button>
  )
}
