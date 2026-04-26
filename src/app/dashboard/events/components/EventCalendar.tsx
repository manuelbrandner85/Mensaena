'use client'

import { useMemo, useCallback, useState } from 'react'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { EventItem, AttendeeStatus } from '../hooks/useEvents'
import { getEventMonth, isToday as checkIsToday } from '../hooks/useEvents'
import EventCalendarDay from './EventCalendarDay'
import EventCard from './EventCard'
import HolidayCalendarOverlay, {
  useHolidayMap,
  HolidayDetailDialog,
} from '@/components/calendar/HolidayCalendarOverlay'
import {
  plzToBundesland,
  coordsToBundesland,
  type Holiday,
  type BundeslandCode,
} from '@/lib/api/holidays'

interface EventCalendarProps {
  events: EventItem[]
  activeMonth: Date
  selectedDate: Date | null
  onMonthChange: (date: Date) => void
  onDateSelect: (date: Date | null) => void
  onAttend: (eventId: string, status: AttendeeStatus) => Promise<boolean>
  onRemove: (eventId: string) => void
  /** Optional: Bundesland-Code für Feiertags-Overlay (Vorrang vor PLZ/coords) */
  state?: BundeslandCode
  /** Optional: PLZ aus User-Profil */
  plz?: string | null
  /** Optional: Geo-Koordinaten als Fallback */
  lat?: number | null
  /** Optional: Geo-Koordinaten als Fallback */
  lng?: number | null
}

const WEEKDAYS = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']

export default function EventCalendar({
  events, activeMonth, selectedDate, onMonthChange, onDateSelect, onAttend, onRemove,
  state, plz, lat, lng,
}: EventCalendarProps) {
  // Bundesland aus Props ableiten (Priorität: state > plz > coords > NATIONAL)
  const resolvedState: BundeslandCode = useMemo(() => {
    if (state) return state
    if (plz) return plzToBundesland(plz)
    if (lat != null && lng != null) return coordsToBundesland(lat, lng)
    return 'NATIONAL'
  }, [state, plz, lat, lng])

  const { holidayMap } = useHolidayMap(resolvedState)
  const [activeHoliday, setActiveHoliday] = useState<Holiday | null>(null)

  // Build calendar grid
  const calendarDays = useMemo(() => {
    const year = activeMonth.getFullYear()
    const month = activeMonth.getMonth()

    // First day of month
    const firstDay = new Date(year, month, 1)
    // Adjust to Monday start (0=Sun -> 6, 1=Mon -> 0, etc.)
    let startOffset = firstDay.getDay() - 1
    if (startOffset < 0) startOffset = 6

    const start = new Date(firstDay)
    start.setDate(start.getDate() - startOffset)

    const days: Date[] = []
    const current = new Date(start)
    // Always show 6 weeks = 42 days for consistency
    for (let i = 0; i < 42; i++) {
      days.push(new Date(current))
      current.setDate(current.getDate() + 1)
    }
    return days
  }, [activeMonth])

  // Map events to dates
  const eventsByDate = useMemo(() => {
    const map = new Map<string, EventItem[]>()
    for (const event of events) {
      const d = new Date(event.start_date)
      const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
      if (!map.has(key)) map.set(key, [])
      map.get(key)!.push(event)
    }
    return map
  }, [events])

  const getEventsForDate = useCallback(
    (date: Date) => {
      const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`
      return eventsByDate.get(key) || []
    },
    [eventsByDate],
  )

  const getHolidayForDate = useCallback(
    (date: Date): Holiday | null => {
      const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`
      return holidayMap.get(key) ?? null
    },
    [holidayMap],
  )

  /**
   * Wenn der User auf einen Tag klickt:
   * - Hat der Tag Events → onDateSelect (Standard-Verhalten, Modal öffnet)
   * - Hat der Tag NUR einen Feiertag → öffne Holiday-Detail-Dialog
   * - Hat der Tag beides → onDateSelect (Events haben Vorrang im Modal)
   */
  const handleDayClick = useCallback(
    (date: Date) => {
      const events = getEventsForDate(date)
      if (events.length > 0) {
        onDateSelect(date)
        return
      }
      const holiday = getHolidayForDate(date)
      if (holiday) setActiveHoliday(holiday)
    },
    [getEventsForDate, getHolidayForDate, onDateSelect],
  )

  const prevMonth = () => {
    const d = new Date(activeMonth)
    d.setMonth(d.getMonth() - 1)
    onMonthChange(d)
  }

  const nextMonth = () => {
    const d = new Date(activeMonth)
    d.setMonth(d.getMonth() + 1)
    onMonthChange(d)
  }

  const goToday = () => {
    onMonthChange(new Date())
  }

  const selectedEvents = selectedDate ? getEventsForDate(selectedDate) : []

  return (
    <div>
      {/* Navigation */}
      <div className="flex items-center justify-between mb-4">
        <button onClick={prevMonth} className="p-2 rounded-lg hover:bg-stone-100 transition">
          <ChevronLeft className="w-5 h-5 text-ink-600" />
        </button>
        <div className="flex items-center gap-3">
          <h3 className="text-lg font-semibold text-ink-900">{getEventMonth(activeMonth)}</h3>
          {!checkIsToday(activeMonth) && (
            <button onClick={goToday} className="text-sm text-primary-600 hover:text-primary-700 font-medium">
              Heute
            </button>
          )}
        </div>
        <button onClick={nextMonth} className="p-2 rounded-lg hover:bg-stone-100 transition">
          <ChevronRight className="w-5 h-5 text-ink-600" />
        </button>
      </div>

      {/* Weekday headers */}
      <div className="grid grid-cols-7 mb-1">
        {WEEKDAYS.map((day) => (
          <div key={day} className="text-xs font-semibold text-ink-500 text-center py-2">
            {day}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7 bg-stone-100 rounded-xl overflow-hidden gap-px">
        {calendarDays.map((date, i) => (
          <EventCalendarDay
            key={i}
            date={date}
            events={getEventsForDate(date)}
            holiday={getHolidayForDate(date)}
            isCurrentMonth={date.getMonth() === activeMonth.getMonth()}
            onSelect={handleDayClick}
          />
        ))}
      </div>

      {/* Holiday overlay – Pillen-Übersicht aller Feiertage des Monats */}
      <HolidayCalendarOverlay
        activeMonth={activeMonth}
        state={resolvedState}
        onSelect={(h) => setActiveHoliday(h)}
      />

      {/* Holiday Detail Dialog */}
      {activeHoliday && (
        <HolidayDetailDialog
          holiday={activeHoliday}
          onClose={() => setActiveHoliday(null)}
        />
      )}

      {/* Selected day events modal/list */}
      {selectedDate && selectedEvents.length > 0 && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
          <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={() => onDateSelect(null)} />
          <div className="relative w-full sm:max-w-md max-h-[70vh] bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl overflow-hidden animate-in slide-in-from-bottom-4 duration-300">
            <div className="flex items-center justify-between p-4 border-b bg-purple-50">
              <h3 className="font-semibold text-ink-900">
                {selectedDate.toLocaleDateString('de-DE', { weekday: 'long', day: 'numeric', month: 'long' })}
              </h3>
              <button onClick={() => onDateSelect(null)} className="text-sm text-ink-500 hover:text-ink-700">
                Schließen
              </button>
            </div>
            <div className="overflow-y-auto max-h-[55vh] p-3 space-y-2">
              {selectedEvents.map((event) => (
                <EventCard key={event.id} event={event} onAttend={onAttend} onRemove={onRemove} compact />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
