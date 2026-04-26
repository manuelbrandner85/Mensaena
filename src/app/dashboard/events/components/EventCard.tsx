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

// Category → accent color for top border
const CATEGORY_ACCENT: Record<string, string> = {
  community:   '#1EAAA6',
  sports:      '#3B82F6',
  culture:     '#8B5CF6',
  education:   '#F59E0B',
  nature:      '#10B981',
  food:        '#EF4444',
  music:       '#EC4899',
  volunteer:   '#1EAAA6',
  kids:        '#F97316',
  other:       '#4F6D8A',
}

export default function EventCard({ event, onAttend, onRemove, compact }: EventCardProps) {
  const router = useRouter()
  const [showMenu, setShowMenu] = useState(false)
  const [attending, setAttending] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const catInfo = EVENT_CATEGORIES[event.category]
  const startDate = new Date(event.start_date)
  const isFull = !!event.max_attendees && event.attendee_count >= event.max_attendees
  const accent = CATEGORY_ACCENT[event.category] ?? '#1EAAA6'

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
        className="w-full flex items-center gap-3 p-2 rounded-xl hover:bg-primary-50/50 transition text-left group"
      >
        <div
          className="w-2 h-2 rounded-full flex-shrink-0 group-hover:scale-125 transition-transform"
          style={{ backgroundColor: accent }}
        />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-ink-900 truncate">{event.title}</p>
          <p className="text-xs text-ink-500">
            {event.is_all_day ? 'Ganztägig' : startDate.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}
            {event.attendee_count > 0 && ` · ${event.attendee_count} Teilnehmer`}
          </p>
        </div>
      </button>
    )
  }

  return (
    <div
      className={cn(
        'hover-lift relative bg-white rounded-2xl border border-stone-100 overflow-hidden cursor-pointer',
        'transition-all duration-300',
        'shadow-soft hover:shadow-card',
      )}
      onClick={() => router.push(`/dashboard/events/${event.id}`)}
    >
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{ background: `linear-gradient(90deg, ${accent}, ${accent}33)` }}
      />

      {/* Event image (wenn vorhanden) */}
      {event.image_url && (
        <div className="relative h-36 overflow-hidden bg-stone-100">
          <img
            src={event.image_url}
            alt={event.title}
            className="w-full h-full object-cover"
            loading="lazy"
            onError={(e) => { e.currentTarget.parentElement!.style.display = 'none' }}
          />
          <div className="absolute inset-0 bg-gradient-to-b from-black/10 to-black/40 pointer-events-none" />
          {isToday(startDate) && (
            <span className="absolute top-2 right-2 px-2 py-0.5 rounded-full text-[10px] font-bold bg-primary-100 text-primary-700">
              Heute
            </span>
          )}
        </div>
      )}

      {/* Today ring (nur wenn kein Bild vorhanden) */}
      {isToday(startDate) && !event.image_url && (
        <div className="absolute top-0 right-0 m-3 px-2 py-0.5 rounded-full text-[10px] font-bold bg-primary-100 text-primary-700">
          Heute
        </div>
      )}

      <div className="flex flex-col sm:flex-row gap-4 p-4 pt-5">
        {/* Date box */}
        <div
          className={cn(
            'w-14 h-14 sm:w-16 sm:h-16 rounded-xl flex flex-col items-center justify-center flex-shrink-0',
            'border-2 relative overflow-hidden',
          )}
          style={{
            background: `${accent}12`,
            borderColor: `${accent}33`,
            boxShadow: `0 0 0 3px ${accent}08`,
          }}
        >
          <span
            className="text-[10px] font-bold uppercase tracking-wide"
            style={{ color: accent }}
          >
            {DE_MONTHS_SHORT[startDate.getMonth()]}
          </span>
          <span
            className="text-2xl font-bold leading-none"
            style={{ color: accent }}
          >
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
          <h3 className="text-base font-semibold text-ink-900 mt-1.5 line-clamp-1 leading-snug">{event.title}</h3>

          {/* Time */}
          <div className="flex items-center gap-1.5 mt-1.5">
            <Clock className="w-3.5 h-3.5 text-ink-400 flex-shrink-0" />
            <span className="text-sm text-ink-600 truncate">
              {formatEventDate(event.start_date, event.end_date, event.is_all_day)}
            </span>
          </div>

          {/* Location */}
          {event.location_name && (
            <div className="flex items-center gap-1.5 mt-0.5">
              <MapPin className="w-3.5 h-3.5 text-ink-400 flex-shrink-0" />
              <span className="text-sm text-ink-600 truncate">{event.location_name}</span>
            </div>
          )}

          {/* Author + Attendees */}
          <div className="flex items-center gap-3 mt-2.5 flex-wrap">
            <div className="flex items-center gap-1.5">
              {event.profiles?.avatar_url ? (
                <img src={event.profiles.avatar_url} alt="" className="w-5 h-5 rounded-full object-cover ring-1 ring-gray-100" />
              ) : (
                <div className="w-5 h-5 rounded-full bg-stone-200 flex items-center justify-center text-[10px] text-ink-600">
                  {(event.profiles?.display_name || event.profiles?.name || 'A').charAt(0).toUpperCase()}
                </div>
              )}
              <span className="text-xs text-ink-500 truncate max-w-[120px]">
                {event.profiles?.display_name || event.profiles?.name || 'Anonym'}
              </span>
            </div>

            <div className="flex items-center gap-1">
              <Users className="w-3.5 h-3.5 text-ink-400" />
              <span className="text-xs text-ink-500">
                {event.max_attendees
                  ? `${event.attendee_count} / ${event.max_attendees}`
                  : event.attendee_count}
              </span>
              {isFull && (
                <span className="text-[10px] font-bold text-red-600 bg-red-50 px-1.5 py-0.5 rounded-full">
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
                'shine px-3 py-1.5 rounded-xl text-sm font-medium transition-all',
                isFull
                  ? 'bg-stone-100 text-ink-400 cursor-not-allowed'
                  : 'bg-primary-600 text-white hover:bg-primary-700 shadow-sm hover:shadow-md',
              )}
            >
              {isFull ? 'Voll' : 'Teilnehmen'}
            </button>
          ) : (
            <div className="relative" ref={menuRef}>
              <button
                onClick={() => setShowMenu(!showMenu)}
                className={cn(
                  'inline-flex items-center gap-1 px-3 py-1.5 rounded-xl text-sm font-medium border transition-all',
                  event.my_attendance === 'going'
                    ? 'text-primary-600 border-primary-300 bg-primary-50'
                    : event.my_attendance === 'interested'
                      ? 'text-amber-600 border-amber-300 bg-amber-50'
                      : 'text-ink-500 border-stone-300 bg-stone-50',
                )}
              >
                {event.my_attendance === 'going' && <><Check className="w-3.5 h-3.5" /> Dabei</>}
                {event.my_attendance === 'interested' && <><Star className="w-3.5 h-3.5" /> Interessiert</>}
                {event.my_attendance === 'declined' && <><XIcon className="w-3.5 h-3.5" /> Abgesagt</>}
                <ChevronDown className="w-3 h-3 ml-0.5" />
              </button>

              {showMenu && (
                <div className="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-card border border-stone-100 z-20 min-w-[160px] py-1">
                  {event.my_attendance !== 'going' && (
                    <button onClick={() => handleAttend('going')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-ink-700 hover:bg-primary-50 rounded-t-xl">
                      <Check className="w-3.5 h-3.5 text-primary-600" /> Teilnehmen
                    </button>
                  )}
                  {event.my_attendance !== 'interested' && (
                    <button onClick={() => handleAttend('interested')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-ink-700 hover:bg-amber-50">
                      <Star className="w-3.5 h-3.5 text-amber-600" /> Interessiert
                    </button>
                  )}
                  {event.my_attendance !== 'declined' && (
                    <button onClick={() => handleAttend('declined')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-ink-700 hover:bg-stone-50">
                      <XIcon className="w-3.5 h-3.5 text-ink-500" /> Absagen
                    </button>
                  )}
                  <hr className="my-1 border-stone-100" />
                  <button onClick={handleRemove} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-red-50 rounded-b-xl">
                    <XIcon className="w-3.5 h-3.5" /> Abmelden
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Cost */}
          <span className={cn(
            'text-xs font-semibold',
            (!event.cost || event.cost === 'kostenlos') ? 'text-primary-600' : 'text-ink-700',
          )}>
            {(!event.cost || event.cost === 'kostenlos') ? 'Kostenlos' : event.cost}
          </span>
        </div>
      </div>
    </div>
  )
}
