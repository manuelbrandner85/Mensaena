'use client'

import { useMemo } from 'react'
import dynamic from 'next/dynamic'
import type { EventItem, AttendeeStatus } from '../hooks/useEvents'
import { MapSkeleton } from './EventSkeleton'

const EventMapInner = dynamic(() => import('./EventMapInner'), {
  ssr: false,
  loading: () => <MapSkeleton />,
})

interface EventMapProps {
  events: EventItem[]
  onAttend: (eventId: string, status: AttendeeStatus) => Promise<boolean>
  onRemove: (eventId: string) => void
}

export default function EventMap({ events, onAttend, onRemove }: EventMapProps) {
  const eventsWithLocation = useMemo(
    () => events.filter((e) => e.latitude != null && e.longitude != null),
    [events],
  )

  return <EventMapInner events={eventsWithLocation} onAttend={onAttend} onRemove={onRemove} />
}
