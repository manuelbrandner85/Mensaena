'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ChevronLeft, ChevronRight, Calendar, MapPin, Clock, Car, Users, Plus } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import dynamic from 'next/dynamic'

const HolidayBadge = dynamic(() => import('@/components/calendar/HolidayBadge'), { ssr: false })

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
    let cancelled = false
    async function load() {
      setLoading(true)
      const supabase = createClient()
      const start = new Date(year, month, 1).toISOString().slice(0, 10)
      const end = new Date(year, month + 1, 0).toISOString().slice(0, 10)
      const { data, error } = await supabase
        .from('posts')
        .select('id, title, type, location_text, event_date, event_time, duration_hours, urgency, profiles(name)')
        .eq('status', 'active')
        .not('event_date', 'is', null)
        .gte('event_date', start)
        .lte('event_date', end)
        .order('event_date', { ascending: true })
      if (cancelled) return
      if (error) console.error('calendar load failed:', error.message)
      setEvents((data ?? []) as CalendarPost[])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
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

  // "Nächste Termine": ab heute bei aktuellem Monat, sonst ab Monatsanfang
  // (bei vergangenem Monat ist der Cutoff am Monatsende, sodass nichts angezeigt wird)
  const upcomingCutoff = (() => {
    const todayMidnight = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    const monthStart = new Date(year, month, 1)
    const monthEndPlus1 = new Date(year, month + 1, 1)
    if (todayMidnight >= monthEndPlus1) return monthEndPlus1   // viewed month is past → empty
    if (todayMidnight >= monthStart)     return todayMidnight  // current month → from today
    return monthStart                                          // future month → from start
  })()
  const upcomingEvents = events.filter(e => {
    const d = new Date(e.event_date)
    return d >= upcomingCutoff
  }).slice(0, 20)

  return (
    <div className="max-w-5xl mx-auto space-y-5">
      <HolidayBadge />
      {/* Editorial header */}
      <header>
        <div className="meta-label meta-label--subtle mb-4">§ 28 / Kalender</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Calendar className="w-6 h-6 text-primary-700" />
            </div>
            <div>
              <h1 className="page-title">Kalender</h1>
              <p className="page-subtitle mt-2">Veranstaltungen, Fahrten und <span className="text-accent">Termine</span>.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <div className="flex bg-paper border border-stone-200 rounded-full overflow-hidden text-xs shadow-soft">
              <button
                onClick={() => setView('month')}
                className={cn('px-4 py-2 font-medium tracking-wide transition-colors',
                  view === 'month' ? 'bg-ink-800 text-paper' : 'text-ink-500 hover:text-ink-800')}
              >
                Monat
              </button>
              <button
                onClick={() => setView('list')}
                className={cn('px-4 py-2 font-medium tracking-wide transition-colors',
                  view === 'list' ? 'bg-ink-800 text-paper' : 'text-ink-500 hover:text-ink-800')}
              >
                Liste
              </button>
            </div>
            <Link href="/dashboard/create?module=mobility&type=mobility" className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors">
              <Plus className="w-4 h-4" /> <span>Termin</span>
            </Link>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Calendar */}
        <div className="lg:col-span-2">
          <div className="bg-white rounded-2xl border border-warm-200 shadow-soft overflow-hidden">

            {/* Month Navigation */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-warm-100">
              <button onClick={prevMonth} aria-label="Vorheriger Monat" className="p-2 hover:bg-warm-100 rounded-xl transition-colors">
                <ChevronLeft className="w-5 h-5 text-ink-600" />
              </button>
              <h2 className="text-lg font-bold text-ink-900">
                {MONTHS_DE[month]} {year}
              </h2>
              <button onClick={nextMonth} aria-label="Nächster Monat" className="p-2 hover:bg-warm-100 rounded-xl transition-colors">
                <ChevronRight className="w-5 h-5 text-ink-600" />
              </button>
            </div>

            {view === 'month' ? (
              <>
                {/* Day headers */}
                <div className="grid grid-cols-7 border-b border-warm-100">
                  {DAYS_DE.map(d => (
                    <div key={d} className="py-2 text-center text-xs font-semibold text-ink-500">{d}</div>
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
                          day ? 'cursor-pointer hover:bg-primary-50/50' : 'bg-stone-50/50',
                          isSelected && 'bg-primary-50',
                          isWeekend && day ? 'bg-warm-50/50' : '',
                        )}
                      >
                        {day && (
                          <>
                            <div className={cn(
                              'w-7 h-7 flex items-center justify-center rounded-full text-sm font-medium mb-1',
                              isToday ? 'bg-primary-600 text-white' : 'text-ink-700'
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
                                    'block text-xs font-medium truncate rounded px-1 py-0.5 border leading-tight',
                                    TYPE_COLORS[e.type] ?? 'bg-stone-100 text-ink-600 border-stone-200'
                                  )}
                                >
                                  {e.event_time ? e.event_time.slice(0, 5) + ' ' : ''}{e.title}
                                </Link>
                              ))}
                              {dayEvents.length > 2 && (
                                <div className="text-xs text-ink-400 pl-1">+{dayEvents.length - 2} weitere</div>
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
                  <div className="py-8 text-center text-ink-400">Lädt…</div>
                ) : upcomingEvents.length === 0 ? (
                  <div className="py-12 text-center">
                    <Calendar className="w-10 h-10 text-stone-300 mx-auto mb-3" />
                    <p className="text-ink-500 font-medium">Keine Termine in diesem Monat</p>
                    <Link href="/dashboard/create?module=mobility&type=mobility" className="btn-primary text-sm mt-4 inline-flex items-center gap-1.5">
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
                        <p className="font-semibold text-ink-900 truncate">{e.title}</p>
                        <div className="flex flex-wrap items-center gap-2 mt-1 text-xs text-ink-500">
                          {e.event_time && <span className="flex items-center gap-1"><Clock className="w-3 h-3" />{e.event_time.slice(0, 5)}</span>}
                          {e.location_text && <span className="flex items-center gap-1"><MapPin className="w-3 h-3" />{e.location_text}</span>}
                          {e.duration_hours && <span className="flex items-center gap-1"><Clock className="w-3 h-3" />{e.duration_hours} Std.</span>}
                        </div>
                      </div>
                      <span className={cn('text-xs px-2 py-1 rounded-full border font-medium flex-shrink-0',
                        TYPE_COLORS[e.type] ?? 'bg-stone-100 text-ink-600 border-stone-200')}>
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
            <div className="bg-white rounded-2xl border border-warm-200 shadow-soft p-4">
              <h3 className="font-semibold text-ink-900 mb-3">
                {selectedDay}. {MONTHS_DE[month]} {year}
              </h3>
              {selectedDayEvents.length === 0 ? (
                <p className="text-sm text-ink-400">Keine Termine</p>
              ) : (
                <div className="space-y-2">
                  {selectedDayEvents.map(e => (
                    <Link key={e.id} href={`/dashboard/posts/${e.id}`}
                      className={cn('block p-3 rounded-xl border text-sm hover:shadow-sm transition-all',
                        TYPE_COLORS[e.type] ?? 'bg-stone-50 text-ink-700 border-stone-200')}>
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
          <div className="bg-white rounded-2xl border border-warm-200 shadow-soft p-4">
            <h3 className="font-semibold text-ink-900 mb-3 flex items-center gap-2">
              <Car className="w-4 h-4 text-primary-500" /> Nächste Termine
            </h3>
            {loading ? (
              <div className="space-y-2">
                {[1,2,3].map(i => <div key={i} className="h-12 bg-stone-100 rounded-xl animate-pulse" />)}
              </div>
            ) : upcomingEvents.length === 0 ? (
              <p className="text-sm text-ink-400">Keine Termine diesen Monat</p>
            ) : (
              <div className="space-y-2">
                {upcomingEvents.slice(0, 5).map(e => (
                  <Link key={e.id} href={`/dashboard/posts/${e.id}`}
                    className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-warm-50 transition-colors">
                    <div className="text-center flex-shrink-0">
                      <div className="text-sm font-bold text-primary-700">{new Date(e.event_date).getDate()}</div>
                      <div className="text-xs text-ink-400">{MONTHS_DE[new Date(e.event_date).getMonth()].slice(0, 3)}</div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-ink-800 truncate">{e.title}</p>
                      {e.event_time && <p className="text-xs text-ink-400">{e.event_time.slice(0, 5)} Uhr</p>}
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
            <h3 className="text-xs font-semibold text-ink-500 uppercase tracking-wide mb-2">Legende</h3>
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
                  <span className="text-xs text-ink-600">{label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
