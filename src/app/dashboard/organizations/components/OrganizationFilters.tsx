'use client'

import { useState } from 'react'
import {
  Search, Filter, ChevronDown, SortAsc, RefreshCw, Map, List,
  Building2, X,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  ORGANIZATION_CATEGORY_CONFIG, COUNTRY_FLAGS, COUNTRY_LABELS,
  type OrganizationFilter, type OrganizationCategory,
} from '../types'

interface Props {
  filters: OrganizationFilter
  onSetFilters: (f: Partial<OrganizationFilter>) => void
  onReset: () => void
  viewMode: 'list' | 'map'
  onViewModeChange: (mode: 'list' | 'map') => void
  totalCount: number
  mapCount: number
  loading: boolean
}

export default function OrganizationFilters({
  filters, onSetFilters, onReset, viewMode, onViewModeChange,
  totalCount, mapCount, loading,
}: Props) {
  const [showCategories, setShowCategories] = useState(false)
  const [showSort, setShowSort] = useState(false)

  const hasActiveFilter = filters.category !== 'all' || filters.country !== 'all' || filters.search || filters.verified_only

  return (
    <div className="space-y-3">
      {/* Country Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-1" role="tablist" aria-label="Länder-Filter">
        {(['all', 'DE', 'AT', 'CH'] as const).map(c => (
          <button
            key={c}
            role="tab"
            aria-selected={filters.country === c}
            onClick={() => onSetFilters({ country: c })}
            className={cn(
              'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all border',
              filters.country === c
                ? 'bg-mn-bronze text-white border-primary-600 shadow-sm'
                : 'bg-mn-elevated text-mn-ink-soft border-white/5 hover:bg-mn-surface'
            )}
          >
            {c === 'all' ? 'Alle Länder' : `${COUNTRY_FLAGS[c]} ${COUNTRY_LABELS[c]}`}
          </button>
        ))}
      </div>

      {/* Category filter toggle */}
      <div className="flex gap-2 flex-wrap">
        <button
          onClick={() => { setShowCategories(s => !s); setShowSort(false) }}
          className={cn(
            'flex items-center gap-2 text-sm font-medium px-3 py-2 rounded-xl border transition-all',
            showCategories ? 'bg-mn-bronze/5 border-mn-bronze/20 text-mn-bronze' : 'bg-mn-elevated border-white/5 text-mn-ink-soft hover:bg-mn-surface'
          )}
          aria-expanded={showCategories}
        >
          <Filter className="w-4 h-4" />
          Kategorie
          {filters.category !== 'all' && (
            <span className="bg-mn-bronze text-white text-xs px-1.5 py-0.5 rounded-full">
              {ORGANIZATION_CATEGORY_CONFIG.find(c => c.value === filters.category)?.label}
            </span>
          )}
          <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', showCategories && 'rotate-180')} />
        </button>

        <button
          onClick={() => { setShowSort(s => !s); setShowCategories(false) }}
          className={cn(
            'flex items-center gap-2 text-sm font-medium px-3 py-2 rounded-xl border transition-all',
            showSort ? 'bg-mn-bronze/5 border-mn-bronze/20 text-mn-bronze' : 'bg-mn-elevated border-white/5 text-mn-ink-soft hover:bg-mn-surface'
          )}
          aria-expanded={showSort}
        >
          <SortAsc className="w-4 h-4" />
          Sortierung
          <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', showSort && 'rotate-180')} />
        </button>

        {hasActiveFilter && (
          <button
            onClick={onReset}
            className="flex items-center gap-1 text-xs text-mn-bronze hover:text-primary-800 px-2 py-1"
          >
            <RefreshCw className="w-3 h-3" />
            Zurücksetzen
          </button>
        )}
      </div>

      {/* Category grid */}
      {showCategories && (
        <div className="p-3 bg-mn-elevated border border-white/5 rounded-2xl shadow-sm grid grid-cols-2 gap-1.5">
          <button
            onClick={() => { onSetFilters({ category: 'all' }); setShowCategories(false) }}
            className={cn(
              'flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium transition-all text-left',
              filters.category === 'all' ? 'bg-mn-elevated text-mn-ink-soft ring-1 ring-stone-300' : 'hover:bg-mn-surface text-mn-ink-soft'
            )}
          >
            <Building2 className="w-3.5 h-3.5 text-mn-mute" />
            Alle
          </button>
          {ORGANIZATION_CATEGORY_CONFIG.map(cat => {
            const CatIcon = cat.icon
            const active = filters.category === cat.value
            return (
              <button
                key={cat.value}
                onClick={() => { onSetFilters({ category: cat.value }); setShowCategories(false) }}
                className={cn(
                  'flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium transition-all text-left',
                  active ? `${cat.bg} ${cat.color} ring-1 ring-current/20` : 'hover:bg-mn-surface text-mn-ink-soft'
                )}
              >
                <CatIcon className={cn('w-3.5 h-3.5 flex-shrink-0', active ? cat.color : 'text-mn-mute')} />
                {cat.label}
              </button>
            )
          })}
        </div>
      )}

      {/* Sort options */}
      {showSort && (
        <div className="p-2 bg-mn-elevated border border-white/5 rounded-2xl shadow-sm flex flex-wrap gap-1.5">
          {[
            { value: 'name' as const, label: 'Name A–Z' },
            { value: 'rating' as const, label: 'Beste Bewertung' },
            { value: 'newest' as const, label: 'Neueste' },
            { value: 'distance' as const, label: 'Entfernung' },
          ].map(opt => (
            <button
              key={opt.value}
              onClick={() => { onSetFilters({ sort_by: opt.value }); setShowSort(false) }}
              className={cn(
                'px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                filters.sort_by === opt.value ? 'bg-mn-bronze/10 text-mn-bronze' : 'hover:bg-mn-surface text-mn-ink-soft'
              )}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}

      {/* View toggle + count */}
      <div className="flex items-center gap-2">
        <div className="flex bg-mn-elevated border border-white/5 rounded-xl overflow-hidden">
          <button
            onClick={() => onViewModeChange('list')}
            className={cn(
              'flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-all',
              viewMode === 'list' ? 'bg-mn-bronze text-white' : 'text-mn-ink-soft hover:bg-mn-surface'
            )}
            aria-label="Listenansicht"
          >
            <List className="w-3.5 h-3.5" />
            Liste
          </button>
          <button
            onClick={() => onViewModeChange('map')}
            className={cn(
              'flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition-all',
              viewMode === 'map' ? 'bg-mn-bronze text-white' : 'text-mn-ink-soft hover:bg-mn-surface'
            )}
            aria-label="Kartenansicht"
          >
            <Map className="w-3.5 h-3.5" />
            Karte
            {mapCount > 0 && (
              <span className={cn(
                'text-xs px-1.5 py-0.5 rounded-full font-semibold',
                viewMode === 'map' ? 'bg-mn-elevated/20 text-white' : 'bg-mn-bronze/10 text-mn-bronze'
              )}>
                {mapCount}
              </span>
            )}
          </button>
        </div>
        {!loading && (
          <p className="text-sm text-mn-mute flex-1">
            {totalCount === 0 ? 'Keine Eintraege' : `${totalCount} Organisation${totalCount !== 1 ? 'en' : ''}`}
          </p>
        )}
      </div>
    </div>
  )
}
