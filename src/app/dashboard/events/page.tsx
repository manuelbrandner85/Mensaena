'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { CalendarDays, Plus, RefreshCw } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { showToast } from '@/components/ui/Toast'
import { useEvents } from './hooks/useEvents'
import type { AttendeeStatus } from './hooks/useEvents'
import EventFilters from './components/EventFilters'
import EventsList from './components/EventsList'
import EventCalendar from './components/EventCalendar'
import EventMap from './components/EventMap'
import EventSkeleton from './components/EventSkeleton'

export default function EventsPage() {
  const router = useRouter()
  const supabase = createClient()
  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)
  const touchStartY = useRef(0)

  // Auth guard
  useEffect(() => {
    const check = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    }
    check()
  }, [supabase, router])

  const events = useEvents(userId)

  // Pull to refresh
  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartY.current = e.touches[0].clientY
  }
  const handleTouchEnd = (e: React.TouchEvent) => {
    const delta = e.changedTouches[0].clientY - touchStartY.current
    if (delta > 80 && window.scrollY < 10) {
      events.refresh()
    }
  }

  const handleAttend = async (eventId: string, status: AttendeeStatus): Promise<boolean> => {
    try {
      const ok = await events.setAttendance(eventId, status)
      if (!ok) {
        showToast.warning('Veranstaltung ist leider ausgebucht.')
        return false
      }
      const msgs: Record<AttendeeStatus, string> = {
        going: 'Du nimmst teil!',
        interested: 'Als interessiert markiert',
        declined: 'Absage eingetragen',
      }
      showToast.success(msgs[status])
      return true
    } catch {
      showToast.error('Fehler beim Aktualisieren')
      return false
    }
  }

  const handleRemoveAttendance = async (eventId: string) => {
    try {
      await events.removeAttendance(eventId)
      showToast.info('Teilnahme entfernt')
    } catch {
      showToast.error('Fehler beim Entfernen')
    }
  }

  if (authLoading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-6">
        <EventSkeleton variant="list" />
      </div>
    )
  }

  return (
    <div
      className="max-w-4xl mx-auto px-4 py-6"
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
    >
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 05 / Termine</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-purple-50 border border-purple-100 flex items-center justify-center flex-shrink-0 float-idle">
              <CalendarDays className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <h1 className="page-title">Veranstaltungen</h1>
              <p className="page-subtitle mt-2">Entdecke <span className="text-accent">Events</span> in deiner Nachbarschaft.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <button
              onClick={() => events.refresh()}
              disabled={events.refreshing}
              className="p-2.5 rounded-full text-ink-400 hover:bg-stone-100 hover:text-ink-700 transition disabled:opacity-50"
              title="Aktualisieren"
            >
              <RefreshCw className={cn('w-4 h-4', events.refreshing && 'animate-spin')} />
            </button>
            <button
              onClick={() => router.push('/dashboard/events/create')}
              className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span>Event erstellen</span>
            </button>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      {/* Refresh indicator */}
      {events.refreshing && (
        <div className="flex items-center justify-center py-2 mb-3">
          <div className="w-5 h-5 border-2 border-primary-400 border-t-transparent rounded-full animate-spin" />
          <span className="ml-2 text-sm text-gray-500">Aktualisiere...</span>
        </div>
      )}

      {/* Filters & View switcher */}
      <EventFilters
        activeView={events.activeView}
        onViewChange={events.setView}
        activeFilter={events.activeFilter}
        onFilterChange={events.setFilter}
        searchQuery={events.searchQuery}
        onSearchChange={events.setSearch}
      />

      {/* Content */}
      <div className="mt-4">
        {events.loading && events.events.length === 0 ? (
          <EventSkeleton variant={events.activeView} />
        ) : events.activeView === 'calendar' ? (
          <EventCalendar
            events={events.events}
            activeMonth={events.activeMonth}
            selectedDate={events.selectedDate}
            onMonthChange={events.setMonth}
            onDateSelect={events.setSelectedDate}
            onAttend={handleAttend}
            onRemove={handleRemoveAttendance}
          />
        ) : events.activeView === 'map' ? (
          <EventMap
            events={events.events}
            onAttend={handleAttend}
            onRemove={handleRemoveAttendance}
          />
        ) : (
          <EventsList
            events={events.events}
            loading={events.loading}
            hasMore={events.hasMore}
            onLoadMore={events.loadMore}
            onAttend={handleAttend}
            onRemove={handleRemoveAttendance}
          />
        )}
      </div>
    </div>
  )
}
