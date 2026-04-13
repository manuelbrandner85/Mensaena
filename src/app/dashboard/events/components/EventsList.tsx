'use client'

import { useMemo, useRef, useEffect, useCallback } from 'react'
import { CalendarDays, Plus } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { LoaderCircle } from 'lucide-react'
import type { EventItem, AttendeeStatus } from '../hooks/useEvents'
import { getTimeGroup } from '../hooks/useEvents'
import EventCard from './EventCard'

interface EventsListProps {
  events: EventItem[]
  loading: boolean
  hasMore: boolean
  onLoadMore: () => void
  onAttend: (eventId: string, status: AttendeeStatus) => Promise<boolean>
  onRemove: (eventId: string) => void
}

export default function EventsList({ events, loading, hasMore, onLoadMore, onAttend, onRemove }: EventsListProps) {
  const router = useRouter()
  const sentinelRef = useRef<HTMLDivElement>(null)

  // Infinite scroll
  const handleIntersect = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      if (entries[0]?.isIntersecting && hasMore && !loading) onLoadMore()
    },
    [hasMore, loading, onLoadMore],
  )

  useEffect(() => {
    const el = sentinelRef.current
    if (!el) return
    const obs = new IntersectionObserver(handleIntersect, { rootMargin: '200px' })
    obs.observe(el)
    return () => obs.disconnect()
  }, [handleIntersect])

  // Group by time
  const groups = useMemo(() => {
    const map = new Map<string, EventItem[]>()
    for (const event of events) {
      const group = getTimeGroup(new Date(event.start_date))
      if (!map.has(group)) map.set(group, [])
      map.get(group)!.push(event)
    }
    return Array.from(map.entries())
  }, [events])

  if (events.length === 0 && !loading) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="p-4 rounded-full bg-purple-50 mb-4">
          <CalendarDays className="w-10 h-10 text-purple-400" />
        </div>
        <h3 className="text-lg font-semibold text-gray-700 mb-1">Noch keine Veranstaltungen</h3>
        <p className="text-sm text-gray-500 mb-4">
          Erstelle die erste Veranstaltung in deiner Nachbarschaft!
        </p>
        <button
          onClick={() => router.push('/dashboard/events/create')}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-primary-600 text-white font-medium text-sm hover:bg-primary-700 transition"
        >
          <Plus className="w-4 h-4" />
          Event erstellen
        </button>
      </div>
    )
  }

  return (
    <div>
      {groups.map(([groupName, groupEvents]) => (
        <div key={groupName}>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mt-6 mb-2 first:mt-0">
            {groupName}
          </h3>
          <div className="space-y-3">
            {groupEvents.map((event) => (
              <EventCard
                key={event.id}
                event={event}
                onAttend={onAttend}
                onRemove={onRemove}
              />
            ))}
          </div>
        </div>
      ))}

      <div ref={sentinelRef} className="h-4" />
      {loading && events.length > 0 && (
        <div className="flex items-center justify-center py-6">
          <LoaderCircle className="w-5 h-5 animate-spin text-primary-600" />
          <span className="ml-2 text-sm text-gray-500">Laden...</span>
        </div>
      )}
    </div>
  )
}
