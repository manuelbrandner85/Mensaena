'use client'

import { useState, useEffect, useCallback } from 'react'
import { useRouter, useParams } from 'next/navigation'
import {
  ArrowLeft, Clock, MapPin, Users, Wallet, Package,
  Phone, Repeat, Trash2, Ban, CalendarDays, LoaderCircle,
  Check, Star, X as XIcon, ChevronDown,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { showToast } from '@/components/ui/Toast'
import { useEvents } from '../hooks/useEvents'
import type { EventItem, AttendeeStatus, EventAttendee } from '../hooks/useEvents'
import { EVENT_CATEGORIES, getCategoryBadgeClasses, formatEventDate } from '../hooks/useEvents'
import EventCountdown from '../components/EventCountdown'
import EventAttendees from '../components/EventAttendees'
import EventShareCard from '../components/EventShareCard'
import EventReminder from '../components/EventReminder'
import EventRideshares from '@/components/features/EventRideshares'

// Category → accent color
const CATEGORY_ACCENT: Record<string, string> = {
  community: '#1EAAA6', sports: '#3B82F6', culture: '#8B5CF6',
  education: '#F59E0B', nature: '#10B981', food: '#EF4444',
  music: '#EC4899', volunteer: '#1EAAA6', kids: '#F97316', other: '#4F6D8A',
}

export default function EventDetailPage() {
  const router = useRouter()
  const params = useParams()
  const eventId = params.id as string
  const supabase = createClient()

  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)
  const [event, setEvent] = useState<EventItem | null>(null)
  const [loading, setLoading] = useState(true)
  const [showAttMenu, setShowAttMenu] = useState(false)
  const [attending, setAttending] = useState(false)
  const [myAttendee, setMyAttendee] = useState<EventAttendee | null>(null)

  useEffect(() => {
    const check = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) { router.replace('/auth?mode=login'); return }
      setUserId(session.user.id)
      setAuthLoading(false)
    }
    check()
  }, [supabase, router])

  const events = useEvents(userId)

  const loadDetail = useCallback(async () => {
    if (!userId || !eventId) return
    setLoading(true)
    try {
      const detail = await events.loadEventDetail(eventId)
      setEvent(detail)
      if (detail) {
        const { data: att } = await supabase
          .from('event_attendees').select('*')
          .eq('event_id', eventId).eq('user_id', userId).maybeSingle()
        setMyAttendee(att as EventAttendee | null)
      }
    } catch { showToast.error('Fehler beim Laden') }
    finally { setLoading(false) }
  }, [userId, eventId, events, supabase])

  useEffect(() => {
    if (userId && eventId) loadDetail()
  }, [userId, eventId]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleAttend = async (status: AttendeeStatus) => {
    if (!event || attending) return
    setAttending(true); setShowAttMenu(false)
    try {
      const ok = await events.setAttendance(event.id, status)
      if (!ok) { showToast.warning('Veranstaltung ist ausgebucht.'); return }
      const msgs: Record<AttendeeStatus, string> = {
        going: 'Du nimmst teil!', interested: 'Als interessiert markiert', declined: 'Absage eingetragen',
      }
      showToast.success(msgs[status])
      setEvent((prev) => prev ? {
        ...prev, my_attendance: status,
        attendee_count: prev.my_attendance === 'going' && status !== 'going'
          ? Math.max(0, prev.attendee_count - 1)
          : prev.my_attendance !== 'going' && status === 'going'
            ? prev.attendee_count + 1 : prev.attendee_count,
      } : null)
      const { data: att } = await supabase.from('event_attendees').select('*')
        .eq('event_id', eventId).eq('user_id', userId!).maybeSingle()
      setMyAttendee(att as EventAttendee | null)
    } catch { showToast.error('Fehler') }
    finally { setAttending(false) }
  }

  const handleRemoveAttendance = async () => {
    if (!event) return
    try {
      await events.removeAttendance(event.id)
      showToast.info('Teilnahme entfernt')
      setEvent((prev) => prev ? {
        ...prev, my_attendance: null,
        attendee_count: prev.my_attendance === 'going' ? Math.max(0, prev.attendee_count - 1) : prev.attendee_count,
      } : null)
      setMyAttendee(null)
    } catch { showToast.error('Fehler') }
  }

  const handleCancel = async () => {
    if (!event || !confirm('Veranstaltung wirklich absagen?')) return
    try { await events.cancelEvent(event.id); showToast.success('Abgesagt'); router.push('/dashboard/events') }
    catch { showToast.error('Fehler') }
  }

  const handleDelete = async () => {
    if (!event || !confirm('Veranstaltung unwiderruflich löschen?')) return
    try { await events.deleteEvent(event.id); showToast.success('Gelöscht'); router.push('/dashboard/events') }
    catch { showToast.error('Fehler') }
  }

  if (authLoading || loading) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-6">
        <div className="animate-pulse space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-stone-200 rounded-xl" />
            <div className="h-6 w-48 bg-stone-200 rounded" />
          </div>
          <div className="bg-white rounded-2xl border border-stone-100 p-6 space-y-4">
            <div className="h-5 w-24 bg-stone-200 rounded-full" />
            <div className="h-7 w-3/4 bg-stone-200 rounded" />
            <div className="h-4 w-1/2 bg-stone-200 rounded" />
            <div className="h-20 w-full bg-stone-200 rounded-xl" />
          </div>
        </div>
      </div>
    )
  }

  if (!event) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <div className="p-4 rounded-2xl bg-stone-100 inline-block mb-4">
          <CalendarDays className="w-10 h-10 text-ink-400" />
        </div>
        <h2 className="text-lg font-semibold text-ink-700 mb-1">Veranstaltung nicht gefunden</h2>
        <p className="text-sm text-ink-500 mb-4">Diese Veranstaltung existiert nicht mehr oder wurde gelöscht.</p>
        <button
          onClick={() => router.push('/dashboard/events')}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary-600 text-white text-sm font-medium hover:bg-primary-700 transition"
        >
          Zurück zu Veranstaltungen
        </button>
      </div>
    )
  }

  const isAuthor = userId === event.author_id
  const catInfo = EVENT_CATEGORIES[event.category]
  const isFull = !!event.max_attendees && event.attendee_count >= event.max_attendees
  const startDate = new Date(event.start_date)
  const accent = CATEGORY_ACCENT[event.category] ?? '#1EAAA6'

  return (
    <div className="max-w-3xl mx-auto px-4 py-6 space-y-4">
      {/* Back button */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.push('/dashboard/events')}
          className="p-2 rounded-xl border border-stone-200 hover:bg-stone-50 transition hover:-translate-x-0.5 duration-200"
        >
          <ArrowLeft className="w-4 h-4 text-ink-600" />
        </button>
        <span className="text-sm text-ink-500">Zurück zu Veranstaltungen</span>
      </div>

      {/* Main card */}
      <div className="bg-white rounded-2xl border border-stone-100 overflow-hidden shadow-soft">
        {/* Top accent */}
        <div className="h-1" style={{ background: `linear-gradient(90deg, ${accent}, ${accent}44)` }} />

        {/* Hero image */}
        {event.image_url && (
          <div className="relative w-full h-52 sm:h-72">
            <img src={event.image_url} alt={event.title} className="w-full h-full object-cover" />
            <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-black/10 to-transparent" />
            {/* Floating category badge on image */}
            <div className="absolute bottom-4 left-4">
              <span className={cn(
                'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold backdrop-blur-sm',
                getCategoryBadgeClasses(event.category),
              )}>
                <span>{catInfo.emoji}</span>
                {catInfo.label}
              </span>
            </div>
          </div>
        )}

        <div className="p-5 sm:p-7 space-y-5">
          {/* Category + Status (if no image) */}
          {!event.image_url && (
            <div className="flex items-center gap-2 flex-wrap">
              <span className={cn(
                'inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium',
                getCategoryBadgeClasses(event.category),
              )}>
                <span>{catInfo.emoji}</span>
                {catInfo.label}
              </span>
              {event.status === 'ongoing' && (
                <span className="px-2 py-0.5 rounded-full text-xs font-bold bg-green-100 text-green-700 animate-pulse">
                  Jetzt live
                </span>
              )}
              {event.status === 'cancelled' && (
                <span className="px-2 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-700">Abgesagt</span>
              )}
              {event.is_recurring && (
                <span className="inline-flex items-center gap-1 text-xs text-ink-500">
                  <Repeat className="w-3 h-3" /> Wiederkehrend
                </span>
              )}
            </div>
          )}

          {/* Title */}
          <h1 className="text-2xl sm:text-3xl font-bold text-ink-900 leading-tight">{event.title}</h1>

          {/* Countdown */}
          <EventCountdown startDate={event.start_date} status={event.status} />

          {/* Info rows */}
          <div className="space-y-3">
            {/* Date */}
            <div className="flex items-start gap-3">
              <div className="p-2 rounded-xl flex-shrink-0 mt-0.5" style={{ background: `${accent}15` }}>
                <Clock className="w-4 h-4" style={{ color: accent }} />
              </div>
              <div>
                <p className="text-sm font-semibold text-ink-900">
                  {formatEventDate(event.start_date, event.end_date, event.is_all_day)}
                </p>
                <p className="text-xs text-ink-500 mt-0.5">
                  {startDate.toLocaleDateString('de-DE', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
                </p>
              </div>
            </div>

            {/* Location */}
            {(event.location_name || event.location_address) && (
              <div className="flex items-start gap-3">
                <div className="p-2 rounded-xl bg-blue-50 flex-shrink-0 mt-0.5">
                  <MapPin className="w-4 h-4 text-blue-600" />
                </div>
                <div>
                  {event.location_name && <p className="text-sm font-semibold text-ink-900">{event.location_name}</p>}
                  {event.location_address && <p className="text-xs text-ink-500 mt-0.5">{event.location_address}</p>}
                </div>
              </div>
            )}

            {/* Attendees */}
            <div className="flex items-start gap-3">
              <div className="p-2 rounded-xl bg-primary-50 flex-shrink-0 mt-0.5">
                <Users className="w-4 h-4 text-primary-600" />
              </div>
              <div>
                <p className="text-sm font-semibold text-ink-900">
                  {event.attendee_count} Teilnehmer{event.max_attendees && ` von ${event.max_attendees}`}
                </p>
                {isFull && <p className="text-xs text-red-600 font-medium mt-0.5">Ausgebucht</p>}
              </div>
            </div>

            {/* Cost */}
            <div className="flex items-start gap-3">
              <div className="p-2 rounded-xl bg-amber-50 flex-shrink-0 mt-0.5">
                <Wallet className="w-4 h-4 text-amber-600" />
              </div>
              <p className={cn('text-sm font-semibold mt-1',
                (!event.cost || event.cost === 'kostenlos') ? 'text-primary-600' : 'text-ink-900',
              )}>
                {(!event.cost || event.cost === 'kostenlos') ? 'Kostenlos' : event.cost}
              </p>
            </div>

            {/* What to bring */}
            {event.what_to_bring && (
              <div className="flex items-start gap-3">
                <div className="p-2 rounded-xl bg-orange-50 flex-shrink-0 mt-0.5">
                  <Package className="w-4 h-4 text-orange-600" />
                </div>
                <div>
                  <p className="text-xs font-medium text-ink-500 mb-0.5">Mitbringen</p>
                  <p className="text-sm text-ink-700">{event.what_to_bring}</p>
                </div>
              </div>
            )}

            {/* Contact */}
            {event.contact_info && (
              <div className="flex items-start gap-3">
                <div className="p-2 rounded-xl bg-stone-100 flex-shrink-0 mt-0.5">
                  <Phone className="w-4 h-4 text-ink-600" />
                </div>
                <div>
                  <p className="text-xs font-medium text-ink-500 mb-0.5">Kontakt</p>
                  <p className="text-sm text-ink-700">{event.contact_info}</p>
                </div>
              </div>
            )}
          </div>

          {/* Description */}
          {event.description && (
            <div className="pt-4 border-t border-stone-100">
              <p className="text-sm text-ink-700 whitespace-pre-line leading-relaxed">{event.description}</p>
            </div>
          )}

          {/* Author */}
          <div className="flex items-center gap-3 pt-4 border-t border-stone-100">
            {event.profiles?.avatar_url ? (
              <img src={event.profiles.avatar_url} alt="" className="w-10 h-10 rounded-full object-cover ring-2 ring-primary-100" />
            ) : (
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white"
                style={{ background: `linear-gradient(135deg, ${accent}, ${accent}88)` }}
              >
                {(event.profiles?.display_name || event.profiles?.name || 'A').charAt(0).toUpperCase()}
              </div>
            )}
            <div>
              <p className="text-sm font-semibold text-ink-900">
                {event.profiles?.display_name || event.profiles?.name || 'Anonym'}
              </p>
              <p className="text-xs text-ink-500">Veranstalter</p>
            </div>
          </div>

          {/* Action bar */}
          <div className="flex flex-wrap items-center gap-3 pt-4 border-t border-stone-100">
            {event.status !== 'cancelled' && (
              <>
                {!event.my_attendance ? (
                  <button
                    onClick={() => handleAttend('going')}
                    disabled={attending || isFull}
                    className={cn(
                      'shine inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all',
                      isFull
                        ? 'bg-stone-100 text-ink-400 cursor-not-allowed'
                        : 'bg-primary-600 text-white hover:bg-primary-700 shadow-soft hover:shadow-card',
                    )}
                  >
                    {attending ? <LoaderCircle className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                    {isFull ? 'Ausgebucht' : 'Teilnehmen'}
                  </button>
                ) : (
                  <div className="relative">
                    <button
                      onClick={() => setShowAttMenu(!showAttMenu)}
                      className={cn(
                        'inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-semibold border transition-all',
                        event.my_attendance === 'going'
                          ? 'text-primary-600 border-primary-300 bg-primary-50'
                          : event.my_attendance === 'interested'
                            ? 'text-amber-600 border-amber-300 bg-amber-50'
                            : 'text-ink-500 border-stone-300 bg-stone-50',
                      )}
                    >
                      {event.my_attendance === 'going' && <><Check className="w-4 h-4" /> Dabei</>}
                      {event.my_attendance === 'interested' && <><Star className="w-4 h-4" /> Interessiert</>}
                      {event.my_attendance === 'declined' && <><XIcon className="w-4 h-4" /> Abgesagt</>}
                      <ChevronDown className="w-3.5 h-3.5 ml-0.5" />
                    </button>

                    {showAttMenu && (
                      <>
                        <div className="fixed inset-0 z-10" onClick={() => setShowAttMenu(false)} />
                        <div className="absolute left-0 top-full mt-1 bg-white rounded-xl shadow-card border border-stone-100 z-20 min-w-[170px] py-1">
                          {event.my_attendance !== 'going' && (
                            <button onClick={() => handleAttend('going')} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-ink-700 hover:bg-primary-50">
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
                          <button onClick={handleRemoveAttendance} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-red-50">
                            <XIcon className="w-3.5 h-3.5" /> Abmelden
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                )}
              </>
            )}

            <EventReminder
              eventId={event.id}
              isAttending={event.my_attendance === 'going' || event.my_attendance === 'interested'}
              reminderSet={myAttendee?.reminder_set ?? false}
              reminderMinutes={myAttendee?.reminder_minutes ?? 60}
              onSetReminder={events.setReminder}
              onRemoveReminder={events.removeReminder}
            />

            <EventShareCard event={event} />

            {isAuthor && event.status !== 'cancelled' && (
              <div className="flex items-center gap-2 ml-auto">
                <button
                  onClick={handleCancel}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium text-amber-600 border border-amber-200 hover:bg-amber-50 transition"
                >
                  <Ban className="w-3.5 h-3.5" /> Absagen
                </button>
                <button
                  onClick={handleDelete}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium text-red-600 border border-red-200 hover:bg-red-50 transition"
                >
                  <Trash2 className="w-3.5 h-3.5" /> Löschen
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Attendees section */}
      <div className="bg-white rounded-2xl border border-stone-100 p-5 sm:p-6 shadow-soft">
        <EventAttendees
          eventId={event.id}
          authorId={event.author_id}
          loadAttendees={events.loadAttendees}
        />
      </div>

      {/* Rideshares section */}
      <EventRideshares eventId={event.id} currentUserId={userId} />
    </div>
  )
}
