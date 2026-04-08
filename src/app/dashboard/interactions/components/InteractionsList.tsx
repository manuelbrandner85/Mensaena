'use client'

import { useMemo } from 'react'
import InteractionCard from './InteractionCard'
import InteractionEmptyState from './InteractionEmptyState'
import type { Interaction, InteractionFilter } from '../types'

interface Props {
  interactions: Interaction[]
  filter: InteractionFilter
  hasMore: boolean
  onLoadMore: () => void
  onAccept?: (id: string) => void
  onDecline?: (id: string) => void
  onStart?: (id: string) => void
  onComplete?: (id: string) => void
  onRate?: (id: string) => void
  currentUserId?: string
}

interface Group {
  key: string
  label: string
  items: Interaction[]
  highlight?: boolean
}

export default function InteractionsList({
  interactions, filter, hasMore, onLoadMore,
  onAccept, onDecline, onStart, onComplete, onRate,
  currentUserId,
}: Props) {
  const groups = useMemo(() => {
    const result: Group[] = []

    // New requests (requested where I'm the receiver)
    const newRequests = interactions.filter(i =>
      i.status === 'requested' && i.helped_id === currentUserId
    )
    if (newRequests.length > 0) {
      result.push({ key: 'new', label: 'Neue Anfragen', items: newRequests, highlight: true })
    }

    // Active
    const active = interactions.filter(i =>
      ['accepted', 'in_progress'].includes(i.status) ||
      (i.status === 'requested' && i.helped_id !== currentUserId)
    )
    if (active.length > 0) {
      result.push({ key: 'active', label: 'Aktiv', items: active })
    }

    // Awaiting rating
    const awaitingRating = interactions.filter(i =>
      i.status === 'completed' && (
        (i.myRole === 'helper' && !i.helper_rated) ||
        (i.myRole === 'helped' && !i.helped_rated)
      )
    )
    if (awaitingRating.length > 0) {
      result.push({ key: 'rating', label: 'Bewertung ausstehend', items: awaitingRating })
    }

    // Completed (already rated)
    const completed = interactions.filter(i =>
      i.status === 'completed' && !awaitingRating.find(a => a.id === i.id)
    )
    if (completed.length > 0) {
      result.push({ key: 'completed', label: 'Abgeschlossen', items: completed })
    }

    // Other
    const otherStatuses = ['cancelled_by_helper', 'cancelled_by_helped', 'disputed', 'resolved']
    const other = interactions.filter(i => otherStatuses.includes(i.status))
    if (other.length > 0) {
      result.push({ key: 'other', label: 'Sonstiges', items: other })
    }

    return result
  }, [interactions, currentUserId])

  if (interactions.length === 0) {
    return <InteractionEmptyState filter={filter} />
  }

  return (
    <div className="space-y-6">
      {groups.map(group => (
        <div key={group.key}>
          <div className="flex items-center gap-2 mb-3">
            <h3 className="text-sm font-semibold text-gray-700">{group.label}</h3>
            <span className="text-xs bg-gray-100 text-gray-600 rounded-full px-2 py-0.5">{group.items.length}</span>
          </div>
          <div className="space-y-3">
            {group.items.map(i => (
              <InteractionCard
                key={i.id}
                interaction={i}
                isNewRequest={group.key === 'new'}
                onAccept={onAccept}
                onDecline={onDecline}
                onStart={onStart}
                onComplete={onComplete}
                onRate={onRate}
              />
            ))}
          </div>
        </div>
      ))}

      {hasMore && (
        <div className="text-center py-4">
          <button
            onClick={onLoadMore}
            className="px-6 py-2 text-sm font-medium text-emerald-700 bg-emerald-50 rounded-lg hover:bg-emerald-100 transition-colors"
          >
            Mehr laden
          </button>
        </div>
      )}
    </div>
  )
}
