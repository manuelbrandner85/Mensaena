'use client'

import { useState, useEffect, useMemo } from 'react'
import { CalendarDays, Flame, Home, Bike, Sparkles, RotateCcw, Plus, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── calendar: Geteilter Kalender ───────────────────────────── */

interface SharedEvent {
  id: string
  title: string
  date: string // ISO date (YYYY-MM-DD)
  host: string
}

function CalendarSharedInner() {
  const [events, setEvents] = useFeatureStorage<SharedEvent[]>('calendar_shared', [])
  const [title, setTitle] = useState('')
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [host, setHost] = useState('')

  const add = () => {
    if (!title.trim() || !host.trim()) return
    setEvents(prev => [{ id: crypto.randomUUID(), title: title.trim(), date, host: host.trim() }, ...prev].slice(0, 20))
    setTitle('')
    setHost('')
    toast.success('Termin geteilt')
  }

  const remove = (id: string) => setEvents(prev => prev.filter(e => e.id !== id))

  const sorted = [...events].sort((a, b) => a.date.localeCompare(b.date))

  return (
    <FeatureCard icon={<CalendarDays className="w-5 h-5" />} title="Geteilter Kalender" subtitle="Termine mit Nachbarn teilen" accent="amber">
      <div className="grid grid-cols-2 gap-2 mb-2">
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Termin" className="input py-2 text-sm" maxLength={50} />
        <input type="date" value={date} onChange={e => setDate(e.target.value)} className="input py-2 text-sm" />
      </div>
      <div className="flex gap-2 mb-3">
        <input value={host} onChange={e => setHost(e.target.value)} placeholder="Gastgeber" className="input py-2 text-sm flex-1" maxLength={30} />
        <PillButton onClick={add} disabled={!title.trim() || !host.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {sorted.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine geteilten Termine.</p>
      ) : (
        <ul className="space-y-1">
          {sorted.map(e => (
            <li key={e.id} className="flex items-center justify-between text-sm bg-amber-50/60 border border-amber-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{new Date(e.date).toLocaleDateString('de-DE', { day: '2-digit', month: 'short' })} · {e.title} <span className="text-gray-500">– {e.host}</span></span>
              <button onClick={() => remove(e.id)} className="text-gray-400 hover:text-red-500">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function CalendarShared() {
  return <FeatureFlag flag="calendar_shared"><CalendarSharedInner /></FeatureFlag>
}

/* ───────────────────────────── map: Activity Heatmap ───────────────────────────── */

function MapActivityHeatmapInner() {
  const [hourlyActivity, setHourlyActivity] = useState<number[]>(Array(24).fill(0))
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      try {
        const supabase = createClient()
        const sinceIso = new Date(Date.now() - 24 * 3600_000).toISOString()
        const { data, error } = await supabase
          .from('posts')
          .select('created_at')
          .gte('created_at', sinceIso)
          .limit(500)
        if (cancelled) return
        if (!error && data) {
          const buckets = Array(24).fill(0)
          data.forEach(p => {
            const h = new Date(p.created_at as string).getHours()
            buckets[h]++
          })
          setHourlyActivity(buckets)
        }
      } catch {
        /* ignore */
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => { cancelled = true }
  }, [])

  const max = Math.max(1, ...hourlyActivity)

  return (
    <FeatureCard icon={<Flame className="w-5 h-5" />} title="Aktivitäts-Heatmap" subtitle="Wann ist gerade was los? (letzte 24h)" accent="red">
      {loading ? (
        <div className="h-14 bg-gray-100 rounded-xl animate-pulse" />
      ) : (
        <div className="grid grid-cols-24 gap-0.5" style={{ gridTemplateColumns: 'repeat(24, minmax(0, 1fr))' }}>
          {hourlyActivity.map((count, h) => {
            const intensity = count / max
            const bg = intensity === 0
              ? 'bg-gray-100'
              : intensity < 0.33 ? 'bg-red-100'
              : intensity < 0.66 ? 'bg-red-300'
              : 'bg-red-500'
            return (
              <div
                key={h}
                className={`h-8 rounded ${bg} transition-colors`}
                title={`${h}:00 – ${count} Aktivitäten`}
              />
            )
          })}
        </div>
      )}
      <div className="flex justify-between text-[10px] text-gray-400 mt-1.5">
        <span>0:00</span><span>12:00</span><span>23:00</span>
      </div>
    </FeatureCard>
  )
}

export function MapActivityHeatmap() {
  return <FeatureFlag flag="map_activity_heatmap"><MapActivityHeatmapInner /></FeatureFlag>
}

/* ───────────────────────────── housing: Room share ───────────────────────────── */

interface Room {
  id: string
  title: string
  rent: number
  from: string
}

function HousingRoomShareInner() {
  const [rooms, setRooms] = useFeatureStorage<Room[]>('housing_room_share', [])
  const [title, setTitle] = useState('')
  const [rent, setRent] = useState(0)
  const [from, setFrom] = useState(() => new Date().toISOString().slice(0, 10))

  const add = () => {
    if (!title.trim()) return
    setRooms(prev => [{ id: crypto.randomUUID(), title: title.trim(), rent, from }, ...prev].slice(0, 15))
    setTitle('')
    toast.success('Zimmer eingetragen')
  }

  return (
    <FeatureCard icon={<Home className="w-5 h-5" />} title="WG-Zimmer-Weitergabe" subtitle="Nur für deine Nachbarschaft sichtbar" accent="primary">
      <div className="grid grid-cols-3 gap-2 mb-2">
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="WG-Zimmer 18m²" className="input py-2 text-sm col-span-2" maxLength={50} />
        <input type="number" min={0} value={rent} onChange={e => setRent(Number(e.target.value))} placeholder="€/Mt" className="input py-2 text-sm" />
      </div>
      <div className="flex gap-2 mb-3">
        <input type="date" value={from} onChange={e => setFrom(e.target.value)} className="input py-2 text-sm flex-1" />
        <PillButton onClick={add} disabled={!title.trim()}>Eintragen</PillButton>
      </div>
      {rooms.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine offenen Zimmer.</p>
      ) : (
        <ul className="space-y-1">
          {rooms.map(r => (
            <li key={r.id} className="flex items-center justify-between text-sm bg-primary-50/50 border border-primary-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{r.title}</span>
              <span className="text-xs text-primary-700 font-semibold">{r.rent}€ · ab {new Date(r.from).toLocaleDateString('de-DE')}</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function HousingRoomShare() {
  return <FeatureFlag flag="housing_room_share"><HousingRoomShareInner /></FeatureFlag>
}

/* ───────────────────────────── mobility: Cargo bike slots ───────────────────────────── */

function MobilityCargoBikeInner() {
  const [bookings, setBookings] = useFeatureStorage<Record<string, string>>('mobility_cargo_bike', {})
  const [name, setName] = useState('')

  const days = useMemo(() => {
    const arr: { key: string; label: string }[] = []
    for (let i = 0; i < 7; i++) {
      const d = new Date(Date.now() + i * 86400_000)
      arr.push({
        key: d.toISOString().slice(0, 10),
        label: d.toLocaleDateString('de-DE', { weekday: 'short', day: '2-digit' }),
      })
    }
    return arr
  }, [])

  const book = (key: string) => {
    if (!name.trim()) {
      toast.error('Bitte Namen eingeben')
      return
    }
    if (bookings[key]) {
      toast.error('Slot bereits vergeben')
      return
    }
    setBookings(prev => ({ ...prev, [key]: name.trim() }))
    toast.success('Slot gebucht')
  }

  const cancel = (key: string) =>
    setBookings(prev => {
      const copy = { ...prev }
      delete copy[key]
      return copy
    })

  return (
    <FeatureCard icon={<Bike className="w-5 h-5" />} title="Lastenrad-Slots" subtitle="Tageweise buchen – nächste 7 Tage" accent="sky">
      <input value={name} onChange={e => setName(e.target.value)} placeholder="Dein Name" className="input py-2 text-sm w-full mb-2" maxLength={30} />
      <div className="grid grid-cols-7 gap-1">
        {days.map(d => {
          const taken = bookings[d.key]
          return (
            <button
              key={d.key}
              onClick={() => (taken ? cancel(d.key) : book(d.key))}
              className={`flex flex-col items-center py-2 rounded-lg border text-[10px] transition-colors ${
                taken ? 'bg-sky-500 text-white border-sky-600' : 'bg-sky-50/60 border-sky-100 text-sky-700 hover:bg-sky-100'
              }`}
              title={taken ? `Gebucht von ${taken}` : 'Frei'}
            >
              <span className="font-semibold">{d.label}</span>
              <span className="mt-0.5 truncate w-full px-0.5">{taken ?? 'frei'}</span>
            </button>
          )
        })}
      </div>
    </FeatureCard>
  )
}

export function MobilityCargoBike() {
  return <FeatureFlag flag="mobility_cargo_bike"><MobilityCargoBikeInner /></FeatureFlag>
}

/* ───────────────────────────── matching: Interests ───────────────────────────── */

const INTEREST_POOL = ['Gärtnern', 'Kochen', 'Hunde', 'Kinder', 'Handwerk', 'Musik', 'Sport', 'Lesen', 'Reisen', 'Film', 'Spiele', 'Nachhaltigkeit']

function MatchingInterestsInner() {
  const [mine, setMine] = useFeatureStorage<string[]>('matching_interests_mine', [])
  const [pool, setPool] = useFeatureStorage<{ name: string; tags: string[] }[]>('matching_interests_pool', [
    { name: 'Anna', tags: ['Gärtnern', 'Nachhaltigkeit', 'Kochen'] },
    { name: 'Ben',  tags: ['Handwerk', 'Sport', 'Hunde'] },
    { name: 'Clara', tags: ['Lesen', 'Film', 'Musik'] },
  ])

  const toggle = (t: string) =>
    setMine(prev => (prev.includes(t) ? prev.filter(x => x !== t) : [...prev, t]))

  const matches = pool
    .map(p => ({ ...p, score: p.tags.filter(t => mine.includes(t)).length }))
    .filter(p => p.score > 0)
    .sort((a, b) => b.score - a.score)

  return (
    <FeatureCard icon={<Sparkles className="w-5 h-5" />} title="Interessen-Matching" subtitle="Wähle deine Interessen und finde passende Nachbarn" accent="violet">
      <div className="flex flex-wrap gap-1.5 mb-3">
        {INTEREST_POOL.map(t => (
          <button
            key={t}
            onClick={() => toggle(t)}
            className={`px-3 py-1 rounded-full text-xs font-semibold border transition-colors ${
              mine.includes(t) ? 'bg-violet-500 text-white border-violet-600' : 'bg-violet-50/60 text-violet-700 border-violet-100 hover:bg-violet-100'
            }`}
          >
            {t}
          </button>
        ))}
      </div>
      {matches.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Matches – wähle Interessen.</p>
      ) : (
        <ul className="space-y-1">
          {matches.map(m => (
            <li key={m.name} className="flex items-center justify-between text-sm bg-violet-50/50 border border-violet-100 rounded-xl px-3 py-1.5">
              <span>{m.name}</span>
              <span className="text-xs text-violet-700 font-semibold">{m.score} gemeinsam</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function MatchingInterests() {
  return <FeatureFlag flag="matching_interests"><MatchingInterestsInner /></FeatureFlag>
}

/* ───────────────────────────── interactions: Reminders ───────────────────────────── */

interface Reminder {
  id: string
  contact: string
  remindAt: number
}

function InteractionsReminderInner() {
  const [reminders, setReminders] = useFeatureStorage<Reminder[]>('interactions_reminder', [])
  const [contact, setContact] = useState('')
  const [days, setDays] = useState(14)

  const add = () => {
    if (!contact.trim()) return
    setReminders(prev => [{ id: crypto.randomUUID(), contact: contact.trim(), remindAt: Date.now() + days * 86400_000 }, ...prev].slice(0, 20))
    setContact('')
    toast.success('Erinnerung gesetzt')
  }

  const snooze = (id: string) =>
    setReminders(prev => prev.map(r => (r.id === id ? { ...r, remindAt: Date.now() + 7 * 86400_000 } : r)))
  const remove = (id: string) => setReminders(prev => prev.filter(r => r.id !== id))

  return (
    <FeatureCard icon={<RotateCcw className="w-5 h-5" />} title={'„Wieder melden"-Erinnerung'} subtitle="Lasse dich an frühere Kontakte erinnern" accent="sky">
      <div className="flex gap-2 mb-3">
        <input value={contact} onChange={e => setContact(e.target.value)} placeholder="Kontakt" className="input py-2 text-sm flex-1" maxLength={40} />
        <select value={days} onChange={e => setDays(Number(e.target.value))} className="input py-2 text-sm w-24">
          <option value={7}>in 7 T</option>
          <option value={14}>in 14 T</option>
          <option value={30}>in 30 T</option>
          <option value={90}>in 90 T</option>
        </select>
        <PillButton onClick={add} disabled={!contact.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {reminders.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine aktiven Erinnerungen.</p>
      ) : (
        <ul className="space-y-1">
          {reminders.map(r => {
            const due = r.remindAt <= Date.now()
            const daysLeft = Math.max(0, Math.ceil((r.remindAt - Date.now()) / 86400_000))
            return (
              <li key={r.id} className={`flex items-center justify-between text-sm border rounded-xl px-3 py-1.5 ${due ? 'bg-red-50 border-red-100' : 'bg-sky-50/60 border-sky-100'}`}>
                <span className="truncate">{r.contact}</span>
                <span className="flex items-center gap-2">
                  <span className={`text-xs font-semibold ${due ? 'text-red-600' : 'text-sky-700'}`}>
                    {due ? 'fällig' : `in ${daysLeft} T`}
                  </span>
                  <button onClick={() => snooze(r.id)} className="text-xs text-sky-600 hover:text-sky-800">+7</button>
                  <button onClick={() => remove(r.id)} className="text-gray-400 hover:text-red-500">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </span>
              </li>
            )
          })}
        </ul>
      )}
    </FeatureCard>
  )
}

export function InteractionsReminder() {
  return <FeatureFlag flag="interactions_reminder"><InteractionsReminderInner /></FeatureFlag>
}
