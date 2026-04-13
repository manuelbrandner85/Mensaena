'use client'

import { useState, useEffect, useCallback } from 'react'
import { HandHeart, HelpCircle, Search, Filter } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { InteractionFilter } from '../types'

interface Props {
  filter: InteractionFilter
  onFilterChange: (f: Partial<InteractionFilter>) => void
}

const ROLE_TABS = [
  { value: 'all' as const, label: 'Alle', icon: null },
  { value: 'helper' as const, label: 'Als Helfer', icon: HandHeart },
  { value: 'helped' as const, label: 'Als Hilfesuchender', icon: HelpCircle },
]

const STATUS_OPTIONS = [
  { value: 'all' as const, label: 'Alle Status' },
  { value: 'active' as const, label: 'Aktiv' },
  { value: 'completed' as const, label: 'Abgeschlossen' },
  { value: 'cancelled' as const, label: 'Abgesagt' },
]

export default function InteractionFilters({ filter, onFilterChange }: Props) {
  const [searchInput, setSearchInput] = useState(filter.search)
  const [showMobileFilters, setShowMobileFilters] = useState(false)

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchInput !== filter.search) {
        onFilterChange({ search: searchInput })
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [searchInput, filter.search, onFilterChange])

  return (
    <div className="space-y-3">
      {/* Role tabs */}
      <div className="flex gap-1 overflow-x-auto pb-1 scrollbar-hide">
        {ROLE_TABS.map(tab => {
          const Icon = tab.icon
          return (
            <button
              key={tab.value}
              onClick={() => onFilterChange({ role: tab.value })}
              className={cn(
                'flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-all',
                filter.role === tab.value
                  ? 'bg-primary-600 text-white shadow-sm'
                  : 'bg-white text-gray-600 hover:bg-gray-50 border border-gray-200',
              )}
            >
              {Icon && <Icon className="w-4 h-4" />}
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* Status + Search row */}
      <div className="flex flex-col sm:flex-row gap-2">
        {/* Mobile filter toggle */}
        <button
          onClick={() => setShowMobileFilters(!showMobileFilters)}
          className="sm:hidden flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium bg-white border border-gray-200 text-gray-600"
        >
          <Filter className="w-4 h-4" /> Filter
        </button>

        <div className={cn('flex gap-2 flex-1', showMobileFilters ? 'flex' : 'hidden sm:flex')}>
          <select
            value={filter.status}
            onChange={e => onFilterChange({ status: e.target.value as any })}
            className="px-3 py-2 rounded-lg text-sm border border-gray-200 bg-white text-gray-700 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
          >
            {STATUS_OPTIONS.map(opt => (
              <option key={opt.value} value={opt.value}>{opt.label}</option>
            ))}
          </select>

          <div className="relative flex-1 max-w-xs">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={searchInput}
              onChange={e => setSearchInput(e.target.value)}
              placeholder="Post oder Partner suchen..."
              className="w-full pl-9 pr-3 py-2 rounded-lg text-sm border border-gray-200 bg-white focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
