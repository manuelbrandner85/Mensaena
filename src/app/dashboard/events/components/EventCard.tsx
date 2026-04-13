'use client'

import { useState, useRef, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Clock, MapPin, Users, ChevronDown, Check, Star, X as XIcon } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { EventItem, AttendeeStatus } from '../hooks/useEvents'
import { EVENT_CATEGORIES, getCategoryBadgeClasses, formatEventDate, isToday } from '../hooks/useEvents'

interface EventCardProps {
  event: EventItem
  onAttend?: (eventId: string, status: AttendeeStatus) => Promise<boolean>
  onRemove?: (eventId: string) => void
  compact?: boolean
}

const DE_MONTHS_SHORT = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez']

export default function EventCard({ event, onAttend, onRemove, compact }: EventCardProps) {
  const router = useRouter()
  const [showMenu, setShowMenu] = useState(false)
  const [attending, setAttending] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const catInfo = EVENT_CATEGORIES[event.category]
  const startDate = new Date(event.start_date)
  const isFull = !!event.max_attendees && event.attendee_count >= event.max_attendees

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setShowMenu(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const handleAttend = async (status: AttendeeStatus) => {
    if (!onAttend || attending) return
    setAttending(true)
    setShowMenu(false)
    await onAttend(event.id, status)
    setAttending(false)
  }

  const handleRemove = () => {
    setShowMenu(false)
    onRemove?.(event.id)
  }

  if (compact) {
    return (
      <button
        onClick={() => router.push(`/dashboard/events/${event.id}`)}
        className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50 transition text-left"
      >
        <div className={cn('w-2 h-2 rounded-full flex-shrink-0', getCategoryBadgeClasses(event.category).split(' ')[0]?.replace('bg-', 'bg-') || 'bg-purple-500')} style={{ backgroundColor: `var(--tw-${catInfo.color}-500, #8b5cf6)` }} />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-900 truncate">{event.title}</p>
          <p className="text-xs text-gray-500">
            {event.is_all_day ? 'Ganztägig' : startDate.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}
            {event.attendee_count > 0 && ` · ${event.attendee_count} Teilnehmer`}
          </p>
        </div>
      </button>
    )
  }

  return (
    <div
      className="bg-white rounded-xl border border-gray-200 hover:border-gray-300 hover:shadow-sm transition-all cursor-pointer"
      onClick={() => router.push(`/dashboard/events/${event.id}`)}
    >
      <div className="flex flex-col sm:flex-row gap-4 p-4">
        {/* Date box */}
        <div className={cn(
          'w-14 h-14 sm:w-16 sm:h-16 rounded-xl flex flex-col items-center justify-center flex-shrink-0 border',
          'bg-primary-50 border-primary-100',
          isToday(startDate) && 'ring-2 ring-primary-400 bg-primary-100',
        )}>
          <span className="text-[10px] font-bold text-primary-500 uppercase tracking-wide">
            {DE_MONTHS_SHORT[startDate.getMonth()]}
          </span>
          <span className="text-2xl font-bold text-primary-700 leading-none">
            {startDate.getDate()}
          </span>
        </div>

        {/* Middle content */}
        <div className="flex-1 min-w-0">
          {/* Category badge */}
          <span className={cn(
            'inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium',
            getCategoryBadgeClasses(event.category),
          )}>
            <span>{catInfo.emoji}</span>
            {catInfo.label}
          </span>

          {/* Title */}
          <h3 className="text-base font-semibold text-gray-900 mt-1 line-clamp-1">{event.title}</h3>

          {/* Time */}
          <div className="flex items-center gap-1.5 mt-1">
            <Clock className="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
            <span className="text-sm text-gray-600 truncate">
              {formatEventDate(event.start_date, event.end_date, event.is_all_day)}
            </span>
          </div>

          {/* Location */}
          {event.location_name && (
            <div className="flex items-center gap-1.5 mt-0.5">
              <MapPin className="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
              <span className="text-sm text-gray-600 truncate">{event.location_name}</span>
            </div>
          )}

          {/* Author + Attendees */}
          <div className="flex items-center gap-3 mt-2 flex-wrap">
            <div className="flex items-center gap-1.5">
              {event.profiles?.avatar_url ? (
                <img src={event.profiles.avatar_url} alt="" className="w-5 h-5 rounded-full object-cover" />
              ) : (
                <div className="w-5 h-5 rounded-full bg-gray-300 flex items-center justify-center text-[10px] text-gray-600">
                  {(event.profiles?.display_name || event.profiles?.name || 'A').charAt(0).toUpperCase()}
                </div>
              )}
              <span className="text-xs text-gray-500 truncate max-w-[120px]">
                {event.profiles?.display_name || event.profiles?.name || 'Anonym'}
              </span>
            </div>

            <div className="flex items-center gap-1">
              <Users className="w-3.5 h-3.5 text-gray-400" />
              <span className="text-xs text-gray-500">
                {event.max_attendees
                  ? `${event.attendee_count} / ${event.max_attendees}`
                  : event.attendee_count}
              </span>
              {isFull && (
                <span className="text-[10px] font-bold text-red-600 bg-red-50 px-1.5 py-0.5 rounded">
                  Ausgebucht
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Right: attendance + cost */}
        <div className="flex flex-row sm:flex-col items-center sm:items-end gap-2 flex-shrink-0" onClick={(e) => e.stopPropagation()}>
          {/* Attendance button */}
          {!event.my_attendance ? (
            <button
              onClick={() => handleAttend('going')}
              disabled={attending || isFull}
              className={cn(
                'px-3 py-1.5 rounded-lg text-sm font-medium transition-all',
                isFull
                  ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                  : 'bg-primary-600 text-white hover:bg-primary-700 shadow-sm',
              )}
            >
              {isFull ? 'Voll' : 'Teilnehmen'}
            </button>
          ) : (
            <div className="relative" ref={menuRef}>
              <button
                onClick={() => setShowMenu(!showMenu)}
                className={cn(
                  'inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm font-medium border transition-all',
                  event.my_attendance === 'going'
                    ? 'text-primary-600 border-primary-300 bg-primary-50'
                    : event.my_attendance === 'interested'
                      ? 'text-amber-600 border-amber-300 bg-amber-50'
                      : 'text-gray-500 border-gray-300 bg-gray-50',
                )}
              >
                {event.my_attendance === 'going' && <><Check className="w-3.5 h-3.5" /> Dabei</>}
                {event.my_attendance === 'interested' && <><Star className="w-3.5 h-3.5" /> Interessiert</>}
                {event.my_attendance === 'declined' && <><XIcon className="w-3.5 h-3.5" /> Abgesagt</>}
                <ChevronDown className="w-3 h-3 ml-0.5" />
              </button>

              {showMenu && (
                <div className="absolute right-0 top-full mt-1 bg-white rounded-lg shadow-lg border border-gray-200 z-20 min-w-[160px] py-1">
                  {event.my_attendance !== 'going' && (
                    <button onClick={() => handleAttend('going')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50">
                      <Check className="w-3.5 h-3.5 text-primary-600" /> Teilnehmen
                    </button>
                  )}
                  {event.my_attendance !== 'interested' && (
                    <button onClick={() => handleAttend('interested')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50">
                      <Star className="w-3.5 h-3.5 text-amber-600" /> Interessiert
                    </button>
                  )}
                  {event.my_attendance !== 'declined' && (
                    <button onClick={() => handleAttend('declined')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50">
                      <XIcon className="w-3.5 h-3.5 text-gray-500" /> Absagen
                    </button>
                  )}
                  <hr className="my-1 border-gray-100" />
                  <button onClick={handleRemove} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-red-50">
                    <XIcon className="w-3.5 h-3.5" /> Abmelden
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Cost */}
          <span className={cn(
            'text-xs font-medium',
            (!event.cost || event.cost === 'kostenlos') ? 'text-primary-600' : 'text-gray-700',
          )}>
            {(!event.cost || event.cost === 'kostenlos') ? 'Kostenlos' : event.cost}
          </span>
        </div>
      </div>
    </div>
  )
}
