'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Users, Check, Star, X as XIcon, ChevronDown, ChevronUp } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { EventAttendee } from '../hooks/useEvents'

interface EventAttendeesProps {
  eventId: string
  authorId: string
  loadAttendees: (eventId: string) => Promise<EventAttendee[]>
}

export default function EventAttendees({ eventId, authorId, loadAttendees }: EventAttendeesProps) {
  const router = useRouter()
  const [attendees, setAttendees] = useState<EventAttendee[]>([])
  const [loading, setLoading] = useState(true)
  const [expanded, setExpanded] = useState(false)

  useEffect(() => {
    setLoading(true)
    loadAttendees(eventId)
      .then(setAttendees)
      .finally(() => setLoading(false))
  }, [eventId, loadAttendees])

  const going = attendees.filter((a) => a.status === 'going')
  const interested = attendees.filter((a) => a.status === 'interested')
  const declined = attendees.filter((a) => a.status === 'declined')

  const total = going.length + interested.length
  const showLimit = 10
  const visibleGoing = expanded ? going : going.slice(0, showLimit)

  if (loading) {
    return (
      <div className="animate-pulse space-y-2">
        <div className="h-5 w-32 bg-gray-200 rounded" />
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex items-center gap-3 py-2">
            <div className="w-8 h-8 bg-gray-200 rounded-full" />
            <div className="h-4 w-24 bg-gray-200 rounded" />
          </div>
        ))}
      </div>
    )
  }

  return (
    <div>
      {/* Header */}
      <div className="flex items-center gap-2 mb-3">
        <Users className="w-5 h-5 text-gray-600" />
        <h3 className="text-base font-semibold text-gray-900">Teilnehmer</h3>
        <span className="text-sm text-gray-500">({total})</span>
      </div>

      {total === 0 ? (
        <p className="text-sm text-gray-500 py-2">Noch keine Teilnehmer. Sei der Erste!</p>
      ) : (
        <div className="space-y-4">
          {/* Going */}
          {going.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <Check className="w-3.5 h-3.5 text-primary-600" />
                <span className="text-sm font-medium text-gray-700">Dabei ({going.length})</span>
              </div>
              <div className="space-y-1">
                {visibleGoing.map((a) => (
                  <AttendeeRow key={a.id} attendee={a} onClick={() => router.push(`/dashboard/profile/${a.user_id}`)} />
                ))}
              </div>
              {going.length > showLimit && (
                <button
                  onClick={() => setExpanded(!expanded)}
                  className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 mt-2"
                >
                  {expanded ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                  {expanded ? 'Weniger anzeigen' : `Alle ${going.length} Teilnehmer anzeigen`}
                </button>
              )}
            </div>
          )}

          {/* Interested */}
          {interested.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <Star className="w-3.5 h-3.5 text-amber-600" />
                <span className="text-sm font-medium text-gray-700">Interessiert ({interested.length})</span>
              </div>
              <div className="space-y-1">
                {interested.map((a) => (
                  <AttendeeRow key={a.id} attendee={a} onClick={() => router.push(`/dashboard/profile/${a.user_id}`)} />
                ))}
              </div>
            </div>
          )}

          {/* Declined */}
          {declined.length > 0 && (
            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <XIcon className="w-3.5 h-3.5 text-gray-400" />
                <span className="text-sm font-medium text-gray-500">Abgesagt ({declined.length})</span>
              </div>
              <div className="space-y-1">
                {declined.map((a) => (
                  <AttendeeRow key={a.id} attendee={a} onClick={() => router.push(`/dashboard/profile/${a.user_id}`)} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

function AttendeeRow({ attendee, onClick }: { attendee: EventAttendee; onClick: () => void }) {
  const name = attendee.profiles?.display_name || attendee.profiles?.name || 'Anonym'
  const trust = attendee.profiles?.trust_score ?? 0

  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-3 py-2 px-2 rounded-lg hover:bg-gray-50 transition text-left"
    >
      {attendee.profiles?.avatar_url ? (
        <img src={attendee.profiles.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
      ) : (
        <div className="w-8 h-8 rounded-full bg-gray-300 flex items-center justify-center text-sm text-gray-600">
          {name.charAt(0).toUpperCase()}
        </div>
      )}
      <span className="text-sm font-medium text-gray-900 flex-1 truncate">{name}</span>
      {trust >= 70 && (
        <span className="text-xs text-primary-600 bg-primary-50 px-1.5 py-0.5 rounded-full flex-shrink-0">
          Vertraut
        </span>
      )}
    </button>
  )
}
