'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ChevronLeft, ChevronRight, Calendar, MapPin, Clock, Car, Users, Plus } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'

interface CalendarPost {
  id: string
  title: string
  type: string
  location_text?: string
  event_date: string
  event_time?: string
  duration_hours?: number
  urgency?: string
  profiles?: { name?: string }
}

const TYPE_COLORS: Record<string, string> = {
  mobility:     'bg-indigo-100 text-indigo-700 border-indigo-200',
  community:    'bg-violet-100 text-violet-700 border-violet-200',
  skill:        'bg-purple-100 text-purple-700 border-purple-200',
  help_request: 'bg-red-100 text-red-700 border-red-200',
  help_offered: 'bg-green-100 text-green-700 border-green-200',
  crisis:       'bg-red-200 text-red-800 border-red-400',
}

const MONTHS_DE = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
const DAYS_DE = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']

export default function CalendarPage() {
  const today = new Date()
  const [year, setYear] = useState(today.getFullYear())
  const [month, setMonth] = useState(today.getMonth())
  const [events, setEvents] = useState<CalendarPost[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedDay, setSelectedDay] = useState<number | null>(null)
  const [view, setView] = useState<'month' | 'list'>('month')

  useEffect(() => {
    async function load() {
      setLoading(true)
      const supabase = createClient()
      const start = new Date(year, month, 1).toISOString().slice(0, 10)
      const end = new Date(year, month + 1, 0).toISOString().slice(0, 10)
      const { data } = await supabase
        .from('posts')
        .select('id, title, type, location_text, event_date, event_time, duration_hours, urgency, profiles(name)')
        .eq('status', 'active')
        .not('event_date', 'is', null)
        .gte('event_date', start)
        .lte('event_date', end)
        .order('event_date', { ascending: true })
      setEvents((data ?? []) as CalendarPost[])
      setLoading(false)
    }
    load()
  }, [year, month])

  const prevMonth = () => {
    if (month === 0) { setYear(y => y - 1); setMonth(11) }
    else setMonth(m => m - 1)
    setSelectedDay(null)
  }

  const nextMonth = () => {
    if (month === 11) { setYear(y => y + 1); setMonth(0) }
    else setMonth(m => m + 1)
    setSelectedDay(null)
  }

  // Build calendar grid
  const firstDayOfMonth = new Date(year, month, 1)
  // Convert to Mon=0 (ISO)
  let startWeekday = firstDayOfMonth.getDay() - 1
  if (startWeekday < 0) startWeekday = 6
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const totalCells = Math.ceil((startWeekday + daysInMonth) / 7) * 7
  const cells: (number | null)[] = Array.from({ length: totalCells }, (_, i) => {
    const d = i - startWeekday + 1
    return d >= 1 && d <= daysInMonth ? d : null
  })

  const eventsForDay = (day: number) => {
    const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
    return events.filter(e => e.event_date?.slice(0, 10) === dateStr)
  }

  const selectedDayEvents = selectedDay ? eventsForDay(selectedDay) : []
  const todayDay = today.getFullYear() === year && today.getMonth() === month ? today.getDate() : null

  const upcomingEvents = events.filter(e => {
    const d = new Date(e.event_date)
    return d >= new Date(year, month, today.getDate() || 1)
  }).slice(0, 20)

  return (
    <div className="max-w-5xl mx-auto space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2 tracking-tight">
            <Calendar className="w-6 h-6 text-primary-600" />
            Kalender
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">Veranstaltungen, Fahrten & Termine</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <div className="flex bg-white border border-warm-200 rounded-xl overflow-hidden text-sm shadow-sm">
            <button
              onClick={() => setView('month')}
              className={cn('px-4 py-2.5 font-medium transition-all',
                view === 'month' ? 'bg-primary-600 text-white' : 'text-gray-600 hover:bg-warm-50')}
            >
              Monat
            </button>
            <button
              onClick={() => setView('list')}
              className={cn('px-4 py-2.5 font-medium transition-all',
                view === 'list' ? 'bg-primary-600 text-white' : 'text-gray-600 hover:bg-warm-50')}
            >
              Liste
            </button>
          </div>
          <Link href="/dashboard/create?type=mobility" className="btn-primary text-sm">
            <Plus className="w-4 h-4" /> Termin erstellen
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Calendar */}
        <div className="lg:col-span-2">
          <div className="bg-white rounded-2xl border border-warm-200 shadow-sm overflow-hidden">

            {/* Month Navigation */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-warm-100">
              <button onClick={prevMonth} className="p-2 hover:bg-warm-100 rounded-xl transition-colors">
                <ChevronLeft className="w-5 h-5 text-gray-600" />
              </button>
              <h2 className="text-lg font-bold text-gray-900">
                {MONTHS_DE[month]} {year}
              </h2>
              <button onClick={nextMonth} className="p-2 hover:bg-warm-100 rounded-xl transition-colors">
                <ChevronRight className="w-5 h-5 text-gray-600" />
              </button>
            </div>

            {view === 'month' ? (
              <>
                {/* Day headers */}
                <div className="grid grid-cols-7 border-b border-warm-100">
                  {DAYS_DE.map(d => (
                    <div key={d} className="py-2 text-center text-xs font-semibold text-gray-500">{d}</div>
                  ))}
                </div>

                {/* Calendar cells */}
                <div className="grid grid-cols-7">
                  {cells.map((day, idx) => {
                    const dayEvents = day ? eventsForDay(day) : []
                    const isToday = day === todayDay
                    const isSelected = day === selectedDay
                    const isWeekend = [5, 6].includes(idx % 7)
                    return (
                      <div
                        key={idx}
                        onClick={() => day && setSelectedDay(isSelected ? null : day)}
                        className={cn(
                          'min-h-[80px] p-1.5 border-b border-r border-warm-100 last:border-r-0 transition-colors',
                          day ? 'cursor-pointer hover:bg-primary-50/50' : 'bg-gray-50/50',
                          isSelected && 'bg-primary-50',
                          isWeekend && day ? 'bg-warm-50/50' : '',
                        )}
                      >
                        {day && (
                          <>
                            <div className={cn(
                              'w-7 h-7 flex items-center justify-center rounded-full text-sm font-medium mb-1',
                              isToday ? 'bg-primary-600 text-white' : 'text-gray-700'
                            )}>
                              {day}
                            </div>
                            <div className="space-y-0.5">
                              {dayEvents.slice(0, 2).map(e => (
                                <Link
                                  key={e.id}
                                  href={`/dashboard/posts/${e.id}`}
                                  onClick={ev => ev.stopPropagation()}
                                  className={cn(
                                    'block text-[10px] font-medium truncate rounded px-1 py-0.5 border leading-tight',
                                    TYPE_COLORS[e.type] ?? 'bg-gray-100 text-gray-600 border-gray-200'
                                  )}
                                >
                                  {e.event_time ? e.event_time.slice(0, 5) + ' ' : ''}{e.title}
                                </Link>
                              ))}
                              {dayEvents.length > 2 && (
                                <div className="text-[10px] text-gray-400 pl-1">+{dayEvents.length - 2} weitere</div>
                              )}
                            </div>
                          </>
                        )}
                      </div>
                    )
                  })}
                </div>
              </>
            ) : (
              /* List View */
              <div className="divide-y divide-warm-100">
                {loading ? (
                  <div className="py-8 text-center text-gray-400">Lädt…</div>
                ) : upcomingEvents.length === 0 ? (
                  <div className="py-12 text-center">
                    <Calendar className="w-10 h-10 text-gray-200 mx-auto mb-3" />
                    <p className="text-gray-500 font-medium">Keine Termine in diesem Monat</p>
                    <Link href="/dashboard/create?type=mobility" className="btn-primary text-sm mt-4 inline-flex items-center gap-1.5">
                      <Plus className="w-4 h-4" /> Termin erstellen
                    </Link>
                  </div>
                ) : (
                  upcomingEvents.map(e => (
                    <Link key={e.id} href={`/dashboard/posts/${e.id}`}
                      className="flex items-start gap-4 px-5 py-4 hover:bg-primary-50 transition-colors">
                      <div className="text-center bg-primary-50 rounded-xl px-3 py-2 flex-shrink-0 border border-primary-100">
                        <div className="text-lg font-bold text-primary-700">
                          {new Date(e.event_date).getDate()}
                        </div>
                        <div className="text-xs text-primary-500">
                          {MONTHS_DE[new Date(e.event_date).getMonth()].slice(0, 3)}
                        </div>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-gray-900 truncate">{e.title}</p>
                        <div className="flex flex-wrap items-center gap-2 mt-1 text-xs text-gray-500">
                          {e.event_time && <span className="flex items-center gap-1"><Clock className="w-3 h-3" />{e.event_time.slice(0, 5)}</span>}
                          {e.location_text && <span className="flex items-center gap-1"><MapPin className="w-3 h-3" />{e.location_text}</span>}
                          {e.duration_hours && <span className="flex items-center gap-1"><Clock className="w-3 h-3" />{e.duration_hours} Std.</span>}
                        </div>
                      </div>
                      <span className={cn('text-xs px-2 py-1 rounded-full border font-medium flex-shrink-0',
                        TYPE_COLORS[e.type] ?? 'bg-gray-100 text-gray-600 border-gray-200')}>
                        {e.type === 'mobility' ? '🚗' : e.type === 'community' ? '🗳️' : '📅'}
                      </span>
                    </Link>
                  ))
                )}
              </div>
            )}
          </div>
        </div>

        {/* Sidebar: Selected day + upcoming */}
        <div className="space-y-4">
          {/* Selected day detail */}
          {selectedDay && (
            <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4">
              <h3 className="font-semibold text-gray-900 mb-3">
                {selectedDay}. {MONTHS_DE[month]} {year}
              </h3>
              {selectedDayEvents.length === 0 ? (
                <p className="text-sm text-gray-400">Keine Termine</p>
              ) : (
                <div className="space-y-2">
                  {selectedDayEvents.map(e => (
                    <Link key={e.id} href={`/dashboard/posts/${e.id}`}
                      className={cn('block p-3 rounded-xl border text-sm hover:shadow-sm transition-all',
                        TYPE_COLORS[e.type] ?? 'bg-gray-50 text-gray-700 border-gray-200')}>
                      <div className="font-semibold truncate">{e.title}</div>
                      {e.event_time && <div className="text-xs mt-0.5 opacity-75">🕐 {e.event_time.slice(0, 5)}</div>}
                      {e.location_text && <div className="text-xs mt-0.5 opacity-75">📍 {e.location_text}</div>}
                      {e.profiles?.name && <div className="text-xs mt-0.5 opacity-75">👤 {e.profiles.name}</div>}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Upcoming this month */}
          <div className="bg-white rounded-2xl border border-warm-200 shadow-sm p-4">
            <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <Car className="w-4 h-4 text-primary-500" /> Nächste Termine
            </h3>
            {loading ? (
              <div className="space-y-2">
                {[1,2,3].map(i => <div key={i} className="h-12 bg-gray-100 rounded-xl animate-pulse" />)}
              </div>
            ) : upcomingEvents.length === 0 ? (
              <p className="text-sm text-gray-400">Keine Termine diesen Monat</p>
            ) : (
              <div className="space-y-2">
                {upcomingEvents.slice(0, 5).map(e => (
                  <Link key={e.id} href={`/dashboard/posts/${e.id}`}
                    className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-warm-50 transition-colors">
                    <div className="text-center flex-shrink-0">
                      <div className="text-sm font-bold text-primary-700">{new Date(e.event_date).getDate()}</div>
                      <div className="text-[10px] text-gray-400">{MONTHS_DE[new Date(e.event_date).getMonth()].slice(0, 3)}</div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-800 truncate">{e.title}</p>
                      {e.event_time && <p className="text-xs text-gray-400">{e.event_time.slice(0, 5)} Uhr</p>}
                    </div>
                  </Link>
                ))}
                {upcomingEvents.length > 5 && (
                  <button onClick={() => setView('list')} className="text-xs text-primary-600 hover:underline w-full text-center pt-1">
                    Alle {upcomingEvents.length} Termine anzeigen →
                  </button>
                )}
              </div>
            )}
          </div>

          {/* Legend */}
          <div className="bg-white rounded-2xl border border-warm-200 p-4">
            <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Legende</h3>
            <div className="space-y-1.5">
              {[
                { type: 'mobility', label: '🚗 Mobilität' },
                { type: 'community', label: '🗳️ Community' },
                { type: 'help_request', label: '🔴 Hilfe gesucht' },
                { type: 'help_offered', label: '🟢 Hilfe angeboten' },
                { type: 'crisis', label: '🚨 Notfall' },
              ].map(({ type, label }) => (
                <div key={type} className="flex items-center gap-2">
                  <div className={cn('w-3 h-3 rounded-sm', TYPE_COLORS[type]?.split(' ')[0])} />
                  <span className="text-xs text-gray-600">{label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
