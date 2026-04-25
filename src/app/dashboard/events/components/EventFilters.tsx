'use client'

import { useRef, useEffect, useState } from 'react'
import { List, CalendarDays, Map, Search, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { EventCategory, ViewMode } from '../hooks/useEvents'
import { EVENT_CATEGORIES } from '../hooks/useEvents'

interface EventFiltersProps {
  activeView: ViewMode
  onViewChange: (v: ViewMode) => void
  activeFilter: EventCategory | 'all'
  onFilterChange: (f: EventCategory | 'all') => void
  searchQuery: string
  onSearchChange: (q: string) => void
}

const ALL_CATEGORIES: (EventCategory | 'all')[] = [
  'all', 'meetup', 'workshop', 'sport', 'food', 'market',
  'culture', 'kids', 'seniors', 'cleanup', 'other',
]

export default function EventFilters({
  activeView, onViewChange, activeFilter, onFilterChange, searchQuery, onSearchChange,
}: EventFiltersProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [localSearch, setLocalSearch] = useState(searchQuery)
  const timerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  useEffect(() => {
    timerRef.current = setTimeout(() => onSearchChange(localSearch), 300)
    return () => clearTimeout(timerRef.current)
  }, [localSearch]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="space-y-3">
      {/* Row 1: View switcher + Search */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        {/* View toggle */}
        <div className="inline-flex rounded-lg border border-gray-200 bg-gray-50 overflow-hidden flex-shrink-0">
          {([
            { key: 'list' as ViewMode, icon: List, label: 'Liste' },
            { key: 'calendar' as ViewMode, icon: CalendarDays, label: 'Kalender' },
            { key: 'map' as ViewMode, icon: Map, label: 'Karte' },
          ]).map(({ key, icon: Icon, label }) => (
            <button
              key={key}
              onClick={() => onViewChange(key)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-2 text-sm font-medium transition-all',
                activeView === key
                  ? 'bg-primary-100 text-primary-700'
                  : 'text-gray-600 hover:bg-gray-100',
              )}
              title={label}
            >
              <Icon className="w-4 h-4" />
              <span>{label}</span>
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            ref={inputRef}
            type="text"
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            placeholder="Events suchen..."
            className="w-full pl-9 pr-8 py-2 rounded-lg border border-gray-200 bg-white text-sm placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent transition"
          />
          {localSearch && (
            <button
              onClick={() => { setLocalSearch(''); inputRef.current?.focus() }}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-gray-100"
            >
              <X className="w-3.5 h-3.5 text-gray-400" />
            </button>
          )}
        </div>
      </div>

      {/* Row 2: Category chips */}
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
        {ALL_CATEGORIES.map((cat) => {
          const active = activeFilter === cat
          const info = cat === 'all' ? { label: 'Alle', emoji: '🏷️' } : EVENT_CATEGORIES[cat]
          return (
            <button
              key={cat}
              onClick={() => onFilterChange(cat)}
              className={cn(
                'inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all flex-shrink-0',
                active
                  ? 'bg-primary-600 text-white shadow-sm'
                  : 'bg-white text-gray-700 border border-gray-200 hover:bg-gray-50 hover:border-gray-300',
              )}
            >
              <span>{info.emoji}</span>
              <span>{info.label}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
