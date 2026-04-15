'use client'

import { useCallback, useEffect, useState } from 'react'
import { Car, Plus, MapPin, Clock, User, Loader2, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

interface Rideshare {
  id: string
  event_id: string
  user_id: string
  role: 'offer' | 'seek'
  seats: number
  from_location: string | null
  departure_time: string | null
  notes: string | null
  created_at: string
  profile?: { name: string | null; display_name: string | null; avatar_url: string | null } | null
}

interface Props {
  eventId: string
  currentUserId?: string
}

export default function EventRideshares({ eventId, currentUserId }: Props) {
  const [items, setItems] = useState<Rideshare[]>([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [submitting, setSubmitting] = useState(false)

  const [role, setRole] = useState<'offer' | 'seek'>('offer')
  const [seats, setSeats] = useState(1)
  const [fromLocation, setFromLocation] = useState('')
  const [departureTime, setDepartureTime] = useState('')
  const [notes, setNotes] = useState('')

  const load = useCallback(async () => {
    const supabase = createClient()
    setLoading(true)
    const { data, error } = await supabase
      .from('event_rideshares')
      .select('id, event_id, user_id, role, seats, from_location, departure_time, notes, created_at, profile:profiles(name, display_name, avatar_url)')
      .eq('event_id', eventId)
      .order('created_at', { ascending: false })
    if (error) {
      console.error('rideshares load failed:', error.message)
      setItems([])
    } else {
      const normalized: Rideshare[] = (data ?? []).map((d: Record<string, unknown>) => ({
        id: String(d.id),
        event_id: String(d.event_id),
        user_id: String(d.user_id),
        role: d.role as 'offer' | 'seek',
        seats: Number(d.seats),
        from_location: (d.from_location as string | null) ?? null,
        departure_time: (d.departure_time as string | null) ?? null,
        notes: (d.notes as string | null) ?? null,
        created_at: String(d.created_at),
        profile: Array.isArray(d.profile) ? (d.profile[0] as Rideshare['profile']) : (d.profile as Rideshare['profile']),
      }))
      setItems(normalized)
    }
    setLoading(false)
  }, [eventId])

  useEffect(() => { load() }, [load])

  const submit = async () => {
    if (!currentUserId) { toast.error('Nicht angemeldet'); return }
    setSubmitting(true)
    const supabase = createClient()
    const { error } = await supabase.from('event_rideshares').insert({
      event_id: eventId,
      user_id: currentUserId,
      role, seats,
      from_location: fromLocation.trim() || null,
      departure_time: departureTime || null,
      notes: notes.trim() || null,
    })
    setSubmitting(false)
    if (handleSupabaseError(error)) return
    toast.success(role === 'offer' ? 'Sitzplatz-Angebot eingetragen' : 'Mitfahr-Gesuch eingetragen')
    setShowForm(false)
    setFromLocation(''); setDepartureTime(''); setNotes(''); setSeats(1); setRole('offer')
    load()
  }

  const remove = async (id: string) => {
    if (!confirm('Eintrag wirklich löschen?')) return
    const supabase = createClient()
    const { error } = await supabase.from('event_rideshares').delete().eq('id', id)
    if (handleSupabaseError(error)) return
    toast.success('Gelöscht')
    load()
  }

  const offers = items.filter(i => i.role === 'offer')
  const seeks = items.filter(i => i.role === 'seek')

  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-5 sm:p-6 shadow-soft">
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-primary-50">
            <Car className="w-4 h-4 text-primary-600" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-gray-900">Fahrgemeinschaften</h3>
            <p className="text-xs text-gray-500">Sitze anbieten oder Mitfahrt suchen</p>
          </div>
        </div>
        {currentUserId && !showForm && (
          <button
            type="button"
            onClick={() => setShowForm(true)}
            className="shine inline-flex items-center gap-1.5 h-9 px-3.5 text-xs font-semibold border border-primary-200 text-primary-700 rounded-xl hover:bg-primary-50 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> Eintrag
          </button>
        )}
      </div>

      {/* Form */}
      {showForm && (
        <div className="mb-5 border border-primary-100 rounded-2xl p-4 bg-primary-50/30">
          {/* Role toggle */}
          <div className="flex items-center gap-2 mb-4">
            <button
              type="button"
              onClick={() => setRole('offer')}
              className={`flex-1 h-9 text-xs font-semibold rounded-xl border transition-all ${
                role === 'offer'
                  ? 'bg-primary-600 text-white border-primary-600 shadow-soft'
                  : 'bg-white text-gray-700 border-gray-200 hover:border-primary-300'
              }`}
            >
              Ich biete Sitze an
            </button>
            <button
              type="button"
              onClick={() => setRole('seek')}
              className={`flex-1 h-9 text-xs font-semibold rounded-xl border transition-all ${
                role === 'seek'
                  ? 'bg-primary-600 text-white border-primary-600 shadow-soft'
                  : 'bg-white text-gray-700 border-gray-200 hover:border-primary-300'
              }`}
            >
              Ich suche Mitfahrt
            </button>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <label className="text-xs">
              <span className="block text-gray-600 mb-1.5 font-medium">{role === 'offer' ? 'Freie Sitze' : 'Benötigte Sitze'}</span>
              <input
                type="number" min={1} max={8}
                value={seats}
                onChange={e => setSeats(Math.max(1, Math.min(8, parseInt(e.target.value || '1', 10))))}
                className="w-full h-10 px-3 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400 focus:border-transparent"
              />
            </label>
            <label className="text-xs">
              <span className="block text-gray-600 mb-1.5 font-medium">Abfahrtszeit</span>
              <input
                type="datetime-local"
                value={departureTime}
                onChange={e => setDepartureTime(e.target.value)}
                className="w-full h-10 px-3 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400 focus:border-transparent"
              />
            </label>
          </div>

          <label className="text-xs block mt-3">
            <span className="block text-gray-600 mb-1.5 font-medium">{role === 'offer' ? 'Abfahrtsort' : 'Startort'}</span>
            <input
              type="text"
              value={fromLocation}
              onChange={e => setFromLocation(e.target.value)}
              placeholder="z.B. Bahnhof Süd, Musterstraße 3"
              className="w-full h-10 px-3 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-400 focus:border-transparent"
            />
          </label>

          <label className="text-xs block mt-3">
            <span className="block text-gray-600 mb-1.5 font-medium">Notiz (optional)</span>
            <textarea
              value={notes}
              onChange={e => setNotes(e.target.value)}
              rows={2}
              maxLength={200}
              placeholder="z.B. Hunde ok, kein Rauchen"
              className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary-400 focus:border-transparent"
            />
          </label>

          <div className="mt-4 flex justify-end gap-2">
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="h-9 px-4 text-xs font-semibold text-gray-600 rounded-xl hover:bg-gray-100 transition-colors"
            >
              Abbrechen
            </button>
            <button
              type="button"
              disabled={submitting}
              onClick={submit}
              className="shine inline-flex items-center gap-1.5 h-9 px-5 text-xs font-semibold bg-primary-600 text-white rounded-xl hover:bg-primary-700 transition-colors disabled:opacity-60 shadow-soft"
            >
              {submitting && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
              Eintragen
            </button>
          </div>
        </div>
      )}

      {/* Content */}
      {loading ? (
        <div className="text-xs text-gray-400 py-8 text-center">
          <Loader2 className="w-5 h-5 animate-spin mx-auto mb-2 text-primary-400" />
          Lade Fahrgemeinschaften …
        </div>
      ) : items.length === 0 ? (
        <div className="text-xs text-gray-400 py-8 text-center border border-dashed border-gray-200 rounded-2xl">
          <Car className="w-6 h-6 mx-auto mb-2 text-gray-300" />
          Noch keine Fahrgemeinschaften für dieses Event.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <RideColumn title="Angebote" variant="offer" items={offers} currentUserId={currentUserId} onRemove={remove} />
          <RideColumn title="Gesuche" variant="seek" items={seeks} currentUserId={currentUserId} onRemove={remove} />
        </div>
      )}
    </div>
  )
}

function RideColumn({ title, variant, items, currentUserId, onRemove }: {
  title: string
  variant: 'offer' | 'seek'
  items: Rideshare[]
  currentUserId?: string
  onRemove: (id: string) => void
}) {
  const isOffer = variant === 'offer'
  return (
    <div className={`rounded-2xl border p-3 ${isOffer ? 'bg-primary-50/40 border-primary-100' : 'bg-[#4F6D8A]/5 border-[#4F6D8A]/20'}`}>
      <h4 className="text-[11px] font-semibold uppercase tracking-wider text-gray-500 mb-3">
        {title} ({items.length})
      </h4>
      {items.length === 0 ? (
        <p className="text-xs text-gray-400 italic py-2">–</p>
      ) : (
        <ul className="space-y-2">
          {items.map(item => {
            const name = item.profile?.display_name || item.profile?.name || 'Nachbar'
            const dep = item.departure_time
              ? new Date(item.departure_time).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
              : null
            return (
              <li key={item.id} className="bg-white rounded-xl border border-gray-100 p-3 relative shadow-soft hover:shadow-card transition-shadow">
                <div className="flex items-start gap-2.5">
                  {item.profile?.avatar_url ? (
                    <img src={item.profile.avatar_url} alt="" className="w-7 h-7 rounded-full object-cover ring-1 ring-primary-100" />
                  ) : (
                    <div className="w-7 h-7 rounded-full bg-primary-50 flex items-center justify-center">
                      <User className="w-3.5 h-3.5 text-primary-500" />
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <p className="text-xs font-semibold text-gray-900 truncate">{name}</p>
                    <p className="text-[11px] text-gray-600 mt-0.5 font-medium">
                      {item.seats} {item.seats === 1 ? 'Sitz' : 'Sitze'}
                    </p>
                    {item.from_location && (
                      <p className="text-[11px] text-gray-500 mt-0.5 flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-primary-400" /> {item.from_location}
                      </p>
                    )}
                    {dep && (
                      <p className="text-[11px] text-gray-500 mt-0.5 flex items-center gap-1">
                        <Clock className="w-3 h-3 text-primary-400" /> {dep}
                      </p>
                    )}
                    {item.notes && (
                      <p className="text-[11px] text-gray-500 mt-1 italic">„{item.notes}"</p>
                    )}
                  </div>
                  {currentUserId === item.user_id && (
                    <button
                      type="button"
                      onClick={() => onRemove(item.id)}
                      className="p-1 text-gray-300 hover:text-red-500 transition-colors"
                      aria-label="Löschen"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}
