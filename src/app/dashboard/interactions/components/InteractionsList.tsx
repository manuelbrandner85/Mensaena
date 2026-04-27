'use client'

import { useMemo, useState } from 'react'
import { LayoutList, Clock } from 'lucide-react'
import { cn } from '@/lib/utils'
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
  const [view, setView] = useState<'status' | 'timeline'>('status')

  // Chronologische Timeline, gruppiert nach Datums-Label
  const timelineGroups = useMemo(() => {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1)
    const weekAgo = new Date(today); weekAgo.setDate(weekAgo.getDate() - 7)
    const monthAgo = new Date(today); monthAgo.setDate(monthAgo.getDate() - 30)
    const labelFor = (d: Date) => {
      const norm = new Date(d); norm.setHours(0, 0, 0, 0)
      if (norm.getTime() === today.getTime()) return 'Heute'
      if (norm.getTime() === yesterday.getTime()) return 'Gestern'
      if (norm.getTime() >= weekAgo.getTime()) return 'Diese Woche'
      if (norm.getTime() >= monthAgo.getTime()) return 'Dieser Monat'
      return d.toLocaleDateString('de-AT', { month: 'long', year: 'numeric' })
    }
    const sorted = [...interactions].sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    )
    const groups: { key: string; label: string; items: Interaction[] }[] = []
    sorted.forEach(it => {
      const label = labelFor(new Date(it.created_at))
      const existing = groups.find(g => g.key === label)
      if (existing) existing.items.push(it)
      else groups.push({ key: label, label, items: [it] })
    })
    return groups
  }, [interactions])

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
      {/* View switcher */}
      <div className="flex items-center gap-1 p-1 bg-stone-100 rounded-xl w-fit">
        <button
          onClick={() => setView('status')}
          className={cn(
            'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
            view === 'status'
              ? 'bg-white text-ink-800 shadow-sm'
              : 'text-ink-500 hover:text-ink-700',
          )}
        >
          <LayoutList className="w-3.5 h-3.5" />
          Nach Status
        </button>
        <button
          onClick={() => setView('timeline')}
          className={cn(
            'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
            view === 'timeline'
              ? 'bg-white text-ink-800 shadow-sm'
              : 'text-ink-500 hover:text-ink-700',
          )}
        >
          <Clock className="w-3.5 h-3.5" />
          Zeitverlauf
        </button>
      </div>

      {view === 'status' ? (
        groups.map(group => (
          <div key={group.key}>
            <div className="flex items-center gap-2 mb-3">
              <h3 className="text-sm font-semibold text-ink-700">{group.label}</h3>
              <span className="text-xs bg-stone-100 text-ink-600 rounded-full px-2 py-0.5">{group.items.length}</span>
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
        ))
      ) : (
        timelineGroups.map(group => (
          <div key={group.key}>
            <div className="flex items-center gap-3 mb-3">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-primary-500" />
                <h3 className="text-[11px] font-bold uppercase tracking-wider text-ink-500">{group.label}</h3>
              </div>
              <div className="flex-1 h-px bg-gradient-to-r from-stone-200 to-transparent" />
              <span className="text-xs text-ink-400 font-medium">{group.items.length}</span>
            </div>
            <div className="space-y-3 pl-4 border-l-2 border-stone-100 ml-0.5">
              {group.items.map(i => (
                <InteractionCard
                  key={i.id}
                  interaction={i}
                  onAccept={onAccept}
                  onDecline={onDecline}
                  onStart={onStart}
                  onComplete={onComplete}
                  onRate={onRate}
                />
              ))}
            </div>
          </div>
        ))
      )}

      {hasMore && (
        <div className="text-center py-4">
          <button
            onClick={onLoadMore}
            className="px-6 py-2 text-sm font-medium text-primary-700 bg-primary-50 rounded-lg hover:bg-primary-100 transition-colors"
          >
            Mehr laden
          </button>
        </div>
      )}
    </div>
  )
}
