'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ────────────────────────────────────────────────────────────
export type EventCategory =
  | 'meetup' | 'workshop' | 'sport' | 'food' | 'market'
  | 'culture' | 'kids' | 'seniors' | 'cleanup' | 'other'

export type EventStatus = 'upcoming' | 'ongoing' | 'completed' | 'cancelled'
export type AttendeeStatus = 'going' | 'interested' | 'declined'
export type ViewMode = 'list' | 'calendar' | 'map'

export interface EventItem {
  id: string
  author_id: string
  title: string
  description: string | null
  category: EventCategory
  start_date: string
  end_date: string | null
  is_all_day: boolean
  location_name: string | null
  location_address: string | null
  latitude: number | null
  longitude: number | null
  region_id: string | null
  image_url: string | null
  max_attendees: number | null
  cost: string | null
  what_to_bring: string | null
  contact_info: string | null
  is_recurring: boolean
  recurring_pattern: { frequency: string; until: string } | null
  recurring_parent_id: string | null
  status: EventStatus
  attendee_count: number
  created_at: string
  updated_at: string
  // Joined
  profiles?: {
    display_name: string | null
    name: string | null
    avatar_url: string | null
    trust_score: number | null
  }
  my_attendance?: AttendeeStatus | null
}

export interface EventAttendee {
  id: string
  event_id: string
  user_id: string
  status: AttendeeStatus
  reminder_set: boolean
  reminder_minutes: number
  created_at: string
  profiles?: {
    display_name: string | null
    name: string | null
    avatar_url: string | null
    trust_score: number | null
  }
}

export interface CreateEventInput {
  title: string
  description?: string | null
  category: EventCategory
  start_date: string
  end_date?: string | null
  is_all_day?: boolean
  location_name?: string | null
  location_address?: string | null
  latitude?: number | null
  longitude?: number | null
  image_url?: string | null
  max_attendees?: number | null
  cost?: string | null
  what_to_bring?: string | null
  contact_info?: string | null
  is_recurring?: boolean
  recurring_pattern?: { frequency: string; until: string } | null
}

// ── Category config ──────────────────────────────────────────────────
export const EVENT_CATEGORIES: Record<EventCategory, { label: string; emoji: string; color: string }> = {
  meetup:   { label: 'Treffen',        emoji: '👥', color: 'purple' },
  workshop: { label: 'Workshop',       emoji: '🎓', color: 'blue' },
  sport:    { label: 'Sport',          emoji: '🏃', color: 'emerald' },
  food:     { label: 'Essen & Trinken', emoji: '🍽️', color: 'orange' },
  market:   { label: 'Flohmarkt',     emoji: '🛍️', color: 'amber' },
  culture:  { label: 'Kultur',         emoji: '🎵', color: 'pink' },
  kids:     { label: 'Kinder',         emoji: '👶', color: 'cyan' },
  seniors:  { label: 'Senioren',       emoji: '❤️', color: 'rose' },
  cleanup:  { label: 'Aufräumaktion', emoji: '♻️', color: 'green' },
  other:    { label: 'Sonstiges',      emoji: '📌', color: 'gray' },
}

export function getCategoryBadgeClasses(cat: EventCategory): string {
  const map: Record<string, string> = {
    purple:  'bg-purple-100 text-purple-700',
    blue:    'bg-blue-100 text-blue-700',
    emerald: 'bg-emerald-100 text-emerald-700',
    orange:  'bg-orange-100 text-orange-700',
    amber:   'bg-amber-100 text-amber-700',
    pink:    'bg-pink-100 text-pink-700',
    cyan:    'bg-cyan-100 text-cyan-700',
    rose:    'bg-rose-100 text-rose-700',
    green:   'bg-green-100 text-green-700',
    gray:    'bg-gray-100 text-gray-700',
  }
  return map[EVENT_CATEGORIES[cat]?.color ?? 'gray'] || 'bg-gray-100 text-gray-700'
}

export function getCategoryDotColor(cat: EventCategory): string {
  const map: Record<string, string> = {
    purple: 'bg-purple-500', blue: 'bg-blue-500', emerald: 'bg-emerald-500',
    orange: 'bg-orange-500', amber: 'bg-amber-500', pink: 'bg-pink-500',
    cyan: 'bg-cyan-500', rose: 'bg-rose-500', green: 'bg-green-500', gray: 'bg-gray-500',
  }
  return map[EVENT_CATEGORIES[cat]?.color ?? 'gray'] || 'bg-gray-500'
}

// ── Date helpers ─────────────────────────────────────────────────────
const DE_WEEKDAYS_SHORT = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']
const DE_MONTHS = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember']
const DE_MONTHS_SHORT = ['Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez']

export function formatEventDate(startDate: string, endDate?: string | null, isAllDay?: boolean): string {
  const s = new Date(startDate)
  const wd = DE_WEEKDAYS_SHORT[s.getDay()]
  const day = s.getDate()
  const mon = DE_MONTHS_SHORT[s.getMonth()]
  const year = s.getFullYear()

  if (isAllDay) {
    if (endDate) {
      const e = new Date(endDate)
      if (e.toDateString() !== s.toDateString()) {
        return `${day}. – ${e.getDate()}. ${DE_MONTHS_SHORT[e.getMonth()]} ${year} · Ganztägig`
      }
    }
    return `${wd}, ${day}. ${mon} ${year} · Ganztägig`
  }

  const timeS = s.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })

  if (endDate) {
    const e = new Date(endDate)
    const timeE = e.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
    if (e.toDateString() !== s.toDateString()) {
      return `${day}. ${mon}, ${timeS} – ${e.getDate()}. ${DE_MONTHS_SHORT[e.getMonth()]}, ${timeE} Uhr`
    }
    return `${wd}, ${day}. ${mon} ${year} · ${timeS} – ${timeE} Uhr`
  }

  return `${wd}, ${day}. ${mon} ${year} · ${timeS} Uhr`
}

export function formatEventDateShort(startDate: string, isAllDay?: boolean): string {
  const s = new Date(startDate)
  const wd = DE_WEEKDAYS_SHORT[s.getDay()]
  const day = s.getDate()
  const mon = DE_MONTHS_SHORT[s.getMonth()]
  if (isAllDay) return `${wd}, ${day}. ${mon} · Ganztägig`
  const time = s.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
  return `${wd}, ${day}. ${mon} · ${time}`
}

export function getEventMonth(date: Date): string {
  return `${DE_MONTHS[date.getMonth()]} ${date.getFullYear()}`
}

export function isToday(date: Date): boolean {
  const t = new Date()
  return date.getFullYear() === t.getFullYear() && date.getMonth() === t.getMonth() && date.getDate() === t.getDate()
}
export function isTomorrow(date: Date): boolean {
  const t = new Date()
  t.setDate(t.getDate() + 1)
  return date.getFullYear() === t.getFullYear() && date.getMonth() === t.getMonth() && date.getDate() === t.getDate()
}
export function isThisWeek(date: Date): boolean {
  const now = new Date()
  const startOfWeek = new Date(now)
  startOfWeek.setDate(now.getDate() - now.getDay() + 1)
  startOfWeek.setHours(0, 0, 0, 0)
  const endOfWeek = new Date(startOfWeek)
  endOfWeek.setDate(startOfWeek.getDate() + 6)
  endOfWeek.setHours(23, 59, 59, 999)
  return date >= startOfWeek && date <= endOfWeek
}
export function isNextWeek(date: Date): boolean {
  const now = new Date()
  const startNext = new Date(now)
  startNext.setDate(now.getDate() - now.getDay() + 8)
  startNext.setHours(0, 0, 0, 0)
  const endNext = new Date(startNext)
  endNext.setDate(startNext.getDate() + 6)
  endNext.setHours(23, 59, 59, 999)
  return date >= startNext && date <= endNext
}
export function isThisMonth(date: Date): boolean {
  const now = new Date()
  return date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear()
}

export function getTimeGroup(date: Date): string {
  if (isToday(date)) return 'Heute'
  if (isTomorrow(date)) return 'Morgen'
  if (isThisWeek(date)) return 'Diese Woche'
  if (isNextWeek(date)) return 'Nächste Woche'
  if (isThisMonth(date)) return 'Dieser Monat'
  return 'Später'
}

const PAGE_SIZE = 20

// ── Hook ─────────────────────────────────────────────────────────────
export function useEvents(userId: string | undefined) {
  const supabase = createClient()
  const [events, setEvents] = useState<EventItem[]>([])
  const [loading, setLoading] = useState(true)
  const [hasMore, setHasMore] = useState(true)
  const [page, setPage] = useState(0)
  const [activeView, setActiveView] = useState<ViewMode>('list')
  const [activeFilter, setActiveFilter] = useState<EventCategory | 'all'>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [activeMonth, setActiveMonth] = useState(new Date())
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)
  const [refreshing, setRefreshing] = useState(false)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)

  // ── Fetch events ──
  const fetchEvents = useCallback(
    async (pageNum: number = 0, append: boolean = false) => {
      if (!userId) return
      setLoading(true)
      try {
        let query = supabase
          .from('events')
          .select('*, profiles!events_author_id_fkey(display_name, name, avatar_url, trust_score)')
          .in('status', ['upcoming', 'ongoing'])
          .order('start_date', { ascending: true })
          .range(pageNum * PAGE_SIZE, (pageNum + 1) * PAGE_SIZE - 1)

        if (activeFilter !== 'all') {
          query = query.eq('category', activeFilter)
        }
        if (searchQuery.trim()) {
          query = query.or(`title.ilike.%${searchQuery.trim()}%,description.ilike.%${searchQuery.trim()}%,location_name.ilike.%${searchQuery.trim()}%`)
        }

        const { data, error } = await query
        if (error) throw error

        // Load my attendance status
        const eventIds = (data ?? []).map((e: Record<string, unknown>) => (e as { id: string }).id)
        let myAttendanceMap: Record<string, AttendeeStatus> = {}
        if (eventIds.length > 0) {
          const { data: att } = await supabase
            .from('event_attendees')
            .select('event_id, status')
            .eq('user_id', userId)
            .in('event_id', eventIds)
          if (att) {
            myAttendanceMap = Object.fromEntries(att.map((a) => [a.event_id, a.status as AttendeeStatus]))
          }
        }

        const typed = (data ?? []).map((e: Record<string, unknown>) => ({
          ...e,
          my_attendance: myAttendanceMap[(e as { id: string }).id] || null,
        })) as EventItem[]

        if (append) {
          setEvents((prev) => [...prev, ...typed])
        } else {
          setEvents(typed)
        }
        setHasMore(typed.length >= PAGE_SIZE)
      } catch (err) {
        console.error('fetchEvents error:', err)
      } finally {
        setLoading(false)
      }
    },
    [supabase, userId, activeFilter, searchQuery],
  )

  // ── Fetch events for calendar month ──
  const fetchEventsForMonth = useCallback(
    async (year: number, month: number) => {
      if (!userId) return
      setLoading(true)
      try {
        const start = new Date(year, month, 1)
        start.setDate(start.getDate() - start.getDay() + (start.getDay() === 0 ? -6 : 1))
        const end = new Date(year, month + 1, 0)
        end.setDate(end.getDate() + (7 - end.getDay()))
        end.setHours(23, 59, 59, 999)

        let query = supabase
          .from('events')
          .select('*, profiles!events_author_id_fkey(display_name, name, avatar_url, trust_score)')
          .in('status', ['upcoming', 'ongoing'])
          .gte('start_date', start.toISOString())
          .lte('start_date', end.toISOString())
          .order('start_date', { ascending: true })

        if (activeFilter !== 'all') {
          query = query.eq('category', activeFilter)
        }

        const { data, error } = await query
        if (error) throw error

        const eventIds = (data ?? []).map((e: Record<string, unknown>) => (e as { id: string }).id)
        let myAttendanceMap: Record<string, AttendeeStatus> = {}
        if (eventIds.length > 0) {
          const { data: att } = await supabase
            .from('event_attendees')
            .select('event_id, status')
            .eq('user_id', userId)
            .in('event_id', eventIds)
          if (att) {
            myAttendanceMap = Object.fromEntries(att.map((a) => [a.event_id, a.status as AttendeeStatus]))
          }
        }

        const typed = (data ?? []).map((e: Record<string, unknown>) => ({
          ...e,
          my_attendance: myAttendanceMap[(e as { id: string }).id] || null,
        })) as EventItem[]

        setEvents(typed)
      } catch (err) {
        console.error('fetchEventsForMonth error:', err)
      } finally {
        setLoading(false)
      }
    },
    [supabase, userId, activeFilter],
  )

  // ── Initial load ──
  useEffect(() => {
    if (!userId) return
    setPage(0)
    if (activeView === 'calendar') {
      fetchEventsForMonth(activeMonth.getFullYear(), activeMonth.getMonth())
    } else {
      fetchEvents(0, false)
    }
  }, [userId, activeView, activeFilter, searchQuery]) // eslint-disable-line react-hooks/exhaustive-deps

  // Calendar month change
  useEffect(() => {
    if (activeView === 'calendar' && userId) {
      fetchEventsForMonth(activeMonth.getFullYear(), activeMonth.getMonth())
    }
  }, [activeMonth]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Load more ──
  const loadMore = useCallback(() => {
    if (loading || !hasMore) return
    const next = page + 1
    setPage(next)
    fetchEvents(next, true)
  }, [loading, hasMore, page, fetchEvents])

  // ── Refresh ──
  const refresh = useCallback(async () => {
    setRefreshing(true)
    setPage(0)
    if (activeView === 'calendar') {
      await fetchEventsForMonth(activeMonth.getFullYear(), activeMonth.getMonth())
    } else {
      await fetchEvents(0, false)
    }
    setRefreshing(false)
  }, [activeView, activeMonth, fetchEvents, fetchEventsForMonth])

  // ── Create event ──
  const createEvent = useCallback(
    async (input: CreateEventInput): Promise<EventItem> => {
      if (!userId) throw new Error('Nicht angemeldet')
      const allowed = await checkRateLimit(userId, 'create_event', 5, 60)
      if (!allowed) throw new Error('Zu viele Events in kurzer Zeit. Bitte warte etwas.')
      const { data, error } = await supabase
        .from('events')
        .insert({
          author_id: userId,
          title: input.title,
          description: input.description ?? null,
          category: input.category,
          start_date: input.start_date,
          end_date: input.end_date ?? null,
          is_all_day: input.is_all_day ?? false,
          location_name: input.location_name ?? null,
          location_address: input.location_address ?? null,
          latitude: input.latitude ?? null,
          longitude: input.longitude ?? null,
          image_url: input.image_url ?? null,
          max_attendees: input.max_attendees ?? null,
          cost: input.cost || 'kostenlos',
          what_to_bring: input.what_to_bring ?? null,
          contact_info: input.contact_info ?? null,
          is_recurring: input.is_recurring ?? false,
          recurring_pattern: input.recurring_pattern ?? null,
        })
        .select('*, profiles!events_author_id_fkey(display_name, name, avatar_url, trust_score)')
        .single()
      if (error) throw error

      const newEvent = data as unknown as EventItem

      // Create recurring instances if needed
      if (input.is_recurring && input.recurring_pattern) {
        await createRecurringInstances(newEvent, input.recurring_pattern)
      }

      setEvents((prev) => [newEvent, ...prev].sort((a, b) =>
        new Date(a.start_date).getTime() - new Date(b.start_date).getTime()
      ))
      return newEvent
    },
    [supabase, userId], // eslint-disable-line react-hooks/exhaustive-deps
  )

  // ── Create recurring instances ──
  const createRecurringInstances = useCallback(
    async (parent: EventItem, pattern: { frequency: string; until: string }) => {
      const instances: Record<string, unknown>[] = []
      const start = new Date(parent.start_date)
      const until = new Date(pattern.until)
      const duration = parent.end_date
        ? new Date(parent.end_date).getTime() - start.getTime()
        : 0
      let current = new Date(start)

      const advance = () => {
        if (pattern.frequency === 'weekly') current.setDate(current.getDate() + 7)
        else if (pattern.frequency === 'biweekly') current.setDate(current.getDate() + 14)
        else current.setMonth(current.getMonth() + 1)
      }

      advance() // skip the parent
      let count = 0
      while (current <= until && count < 52) {
        const endDate = duration ? new Date(current.getTime() + duration).toISOString() : null
        instances.push({
          author_id: parent.author_id,
          title: parent.title,
          description: parent.description,
          category: parent.category,
          start_date: current.toISOString(),
          end_date: endDate,
          is_all_day: parent.is_all_day,
          location_name: parent.location_name,
          location_address: parent.location_address,
          latitude: parent.latitude,
          longitude: parent.longitude,
          image_url: parent.image_url,
          max_attendees: parent.max_attendees,
          cost: parent.cost,
          what_to_bring: parent.what_to_bring,
          contact_info: parent.contact_info,
          is_recurring: true,
          recurring_pattern: pattern,
          recurring_parent_id: parent.id,
        })
        advance()
        count++
      }

      if (instances.length > 0) {
        await supabase.from('events').insert(instances)
      }
    },
    [supabase],
  )

  // ── Cancel event ──
  const cancelEvent = useCallback(
    async (eventId: string) => {
      const { error } = await supabase
        .from('events')
        .update({ status: 'cancelled' })
        .eq('id', eventId)
      if (error) throw error
      setEvents((prev) => prev.filter((e) => e.id !== eventId))
    },
    [supabase],
  )

  // ── Delete event ──
  const deleteEvent = useCallback(
    async (eventId: string) => {
      const { error } = await supabase
        .from('events')
        .delete()
        .eq('id', eventId)
      if (error) throw error
      setEvents((prev) => prev.filter((e) => e.id !== eventId))
    },
    [supabase],
  )

  // ── Set attendance ──
  const setAttendance = useCallback(
    async (eventId: string, status: AttendeeStatus): Promise<boolean> => {
      if (!userId) return false
      const event = events.find((e) => e.id === eventId)
      if (status === 'going' && event?.max_attendees && event.attendee_count >= event.max_attendees) {
        return false // full
      }

      const { error } = await supabase
        .from('event_attendees')
        .upsert({ event_id: eventId, user_id: userId, status }, { onConflict: 'event_id,user_id' })
      if (error) throw error

      setEvents((prev) =>
        prev.map((e) => {
          if (e.id !== eventId) return e
          const waGoing = e.my_attendance === 'going'
          const isGoing = status === 'going'
          let newCount = e.attendee_count
          if (!waGoing && isGoing) newCount++
          if (waGoing && !isGoing) newCount = Math.max(0, newCount - 1)
          return { ...e, my_attendance: status, attendee_count: newCount }
        }),
      )
      return true
    },
    [supabase, userId, events],
  )

  // ── Remove attendance ──
  const removeAttendance = useCallback(
    async (eventId: string) => {
      if (!userId) return
      const event = events.find((e) => e.id === eventId)
      const wasGoing = event?.my_attendance === 'going'

      const { error } = await supabase
        .from('event_attendees')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId)
      if (error) throw error

      setEvents((prev) =>
        prev.map((e) => {
          if (e.id !== eventId) return e
          return {
            ...e,
            my_attendance: null,
            attendee_count: wasGoing ? Math.max(0, e.attendee_count - 1) : e.attendee_count,
          }
        }),
      )
    },
    [supabase, userId, events],
  )

  // ── Load attendees ──
  const loadAttendees = useCallback(
    async (eventId: string): Promise<EventAttendee[]> => {
      const { data, error } = await supabase
        .from('event_attendees')
        .select('*, profiles!event_attendees_user_id_fkey(display_name, name, avatar_url, trust_score)')
        .eq('event_id', eventId)
        .order('status', { ascending: true })
        .order('created_at', { ascending: true })
      if (error) throw error
      return (data ?? []) as unknown as EventAttendee[]
    },
    [supabase],
  )

  // ── Load event detail ──
  const loadEventDetail = useCallback(
    async (eventId: string): Promise<EventItem | null> => {
      if (!userId) return null
      const { data, error } = await supabase
        .from('events')
        .select('*, profiles!events_author_id_fkey(display_name, name, avatar_url, trust_score)')
        .eq('id', eventId)
        .single()
      if (error) return null

      // Load my attendance
      const { data: att } = await supabase
        .from('event_attendees')
        .select('status')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle()

      return {
        ...(data as unknown as EventItem),
        my_attendance: (att?.status as AttendeeStatus) || null,
      }
    },
    [supabase, userId],
  )

  // ── Set reminder ──
  const setReminder = useCallback(
    async (eventId: string, minutes: number) => {
      if (!userId) return
      const { error } = await supabase
        .from('event_attendees')
        .update({ reminder_set: true, reminder_minutes: minutes })
        .eq('event_id', eventId)
        .eq('user_id', userId)
      if (error) throw error
    },
    [supabase, userId],
  )

  // ── Remove reminder ──
  const removeReminder = useCallback(
    async (eventId: string) => {
      if (!userId) return
      const { error } = await supabase
        .from('event_attendees')
        .update({ reminder_set: false })
        .eq('event_id', eventId)
        .eq('user_id', userId)
      if (error) throw error
    },
    [supabase, userId],
  )

  // ── Image upload ──
  const uploadImage = useCallback(
    async (file: File): Promise<string> => {
      if (!userId) throw new Error('Nicht angemeldet')
      if (file.size > 5 * 1024 * 1024) throw new Error('Bild darf max. 5 MB groß sein')
      const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
      if (!allowed.includes(file.type)) throw new Error('Nur JPEG, PNG, WebP oder GIF erlaubt')

      const ext = file.name.split('.').pop() || 'jpg'
      const path = `${userId}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`

      const { error } = await supabase.storage.from('event-images').upload(path, file, {
        cacheControl: '3600',
        upsert: false,
      })
      if (error) throw error

      const { data } = supabase.storage.from('event-images').getPublicUrl(path)
      return data.publicUrl
    },
    [supabase, userId],
  )

  // ── Realtime ──
  useEffect(() => {
    if (!userId) return

    const channel = supabase
      .channel('events-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'events' },
        () => { refresh() },
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'event_attendees' },
        (payload) => {
          const ea = payload.new as { event_id?: string }
          if (ea?.event_id) {
            // Update attendee count locally
            setEvents((prev) =>
              prev.map((e) => {
                if (e.id !== ea.event_id) return e
                return e // will be updated via events channel
              }),
            )
          }
        },
      )
      .subscribe()

    channelRef.current = channel
    return () => { channel.unsubscribe() }
  }, [supabase, userId]) // eslint-disable-line react-hooks/exhaustive-deps

  // View change handler
  const setView = useCallback((view: ViewMode) => {
    setActiveView(view)
  }, [])

  const setFilter = useCallback((filter: EventCategory | 'all') => {
    setActiveFilter(filter)
    setPage(0)
  }, [])

  const setSearch = useCallback((q: string) => {
    setSearchQuery(q)
    setPage(0)
  }, [])

  const setMonth = useCallback((date: Date) => {
    setActiveMonth(date)
  }, [])

  return {
    events,
    loading,
    hasMore,
    refreshing,
    activeView,
    setView,
    activeFilter,
    setFilter,
    searchQuery,
    setSearch,
    activeMonth,
    setMonth,
    selectedDate,
    setSelectedDate,
    loadMore,
    refresh,
    createEvent,
    cancelEvent,
    deleteEvent,
    setAttendance,
    removeAttendance,
    loadAttendees,
    loadEventDetail,
    setReminder,
    removeReminder,
    uploadImage,
  }
}
