'use client'

import { Star, Filter, Loader2 } from 'lucide-react'
import RatingCard from './RatingCard'
import { cn } from '@/lib/utils'
import type { TrustRating } from '@/types'

interface RatingsListProps {
  ratings: TrustRating[]
  loading: boolean
  hasMore: boolean
  filter: 'all' | 'given' | 'received'
  onFilterChange: (f: 'all' | 'given' | 'received') => void
  onLoadMore: () => void
  currentUserId?: string
  isOwnProfile?: boolean
}

const FILTER_OPTIONS: { value: 'all' | 'given' | 'received'; label: string }[] = [
  { value: 'received', label: 'Erhaltene' },
  { value: 'given', label: 'Abgegebene' },
  { value: 'all', label: 'Alle' },
]

export default function RatingsList({
  ratings,
  loading,
  hasMore,
  filter,
  onFilterChange,
  onLoadMore,
  currentUserId,
  isOwnProfile,
}: RatingsListProps) {
  return (
    <div className="space-y-4">
      {/* Filter dropdown */}
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-gray-900 flex items-center gap-2">
          <Star className="w-4 h-4 text-amber-500" />
          Bewertungen
        </h3>
        <div className="flex items-center gap-1 bg-warm-50 rounded-lg p-1">
          {FILTER_OPTIONS.map(opt => (
            <button
              key={opt.value}
              onClick={() => onFilterChange(opt.value)}
              className={cn(
                'px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                filter === opt.value
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700',
              )}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {/* Loading */}
      {loading && ratings.length === 0 && (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-6 h-6 text-primary-500 animate-spin" />
        </div>
      )}

      {/* Empty state */}
      {!loading && ratings.length === 0 && (
        <div className="text-center py-12 bg-warm-50 rounded-xl border border-warm-200">
          <Star className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">
            {filter === 'received'
              ? 'Noch keine Bewertungen erhalten.'
              : filter === 'given'
                ? 'Noch keine Bewertungen abgegeben.'
                : 'Noch keine Bewertungen vorhanden.'}
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Bewertungen werden nach abgeschlossenen Interaktionen vergeben.
          </p>
        </div>
      )}

      {/* Rating cards */}
      <div className="space-y-3">
        {ratings.map(r => (
          <RatingCard
            key={r.id}
            rating={r}
            currentUserId={currentUserId}
            isOwnProfile={isOwnProfile}
          />
        ))}
      </div>

      {/* Load more */}
      {hasMore && (
        <button
          onClick={onLoadMore}
          disabled={loading}
          className="w-full py-3 rounded-xl text-sm font-medium text-primary-600 bg-primary-50 hover:bg-primary-100 border border-primary-200 transition-all disabled:opacity-50"
        >
          {loading ? (
            <Loader2 className="w-4 h-4 animate-spin mx-auto" />
          ) : (
            'Mehr laden'
          )}
        </button>
      )}
    </div>
  )
}
