'use client'

import { useState } from 'react'
import { Bone, Siren, MessageCircleHeart, Radio, Trash2, Plus, MapPin } from 'lucide-react'
import toast from 'react-hot-toast'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── animals: Futter-Spenden-Tracker ───────────────────────────── */

interface FoodNeed {
  id: string
  item: string
  animal: string
  createdAt: number
}

function AnimalsFoodTrackerInner() {
  const [needs, setNeeds] = useFeatureStorage<FoodNeed[]>('animals_food_tracker', [])
  const [item, setItem] = useState('')
  const [animal, setAnimal] = useState('Hund')

  const add = () => {
    if (item.trim().length < 2) return
    setNeeds(prev => [
      { id: crypto.randomUUID(), item: item.trim(), animal, createdAt: Date.now() },
      ...prev,
    ].slice(0, 20))
    setItem('')
    toast.success('Futterbedarf eingetragen')
  }

  const remove = (id: string) => setNeeds(prev => prev.filter(n => n.id !== id))

  return (
    <FeatureCard
      icon={<Bone className="w-5 h-5" />}
      title="Futter-Spenden-Tracker"
      subtitle="Trage ein, was fürs Tier gerade fehlt"
      accent="rose"
    >
      <div className="flex gap-2 mb-3">
        <input
          value={item}
          onChange={e => setItem(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && add()}
          placeholder="z.B. Trockenfutter 5kg"
          maxLength={60}
          className="input flex-1 py-2 text-sm"
        />
        <select value={animal} onChange={e => setAnimal(e.target.value)} className="input py-2 text-sm w-24">
          <option>Hund</option>
          <option>Katze</option>
          <option>Nager</option>
          <option>Vogel</option>
        </select>
        <PillButton onClick={add} disabled={item.trim().length < 2}>
          <Plus className="w-3.5 h-3.5" /> Add
        </PillButton>
      </div>
      {needs.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine offenen Bedarfe – super!</p>
      ) : (
        <ul className="space-y-1.5">
          {needs.map(n => (
            <li key={n.id} className="flex items-center justify-between gap-2 bg-rose-50/50 border border-rose-100 rounded-xl px-3 py-1.5 text-sm">
              <span className="truncate"><span className="text-rose-600 font-semibold">{n.animal}:</span> {n.item}</span>
              <button onClick={() => remove(n.id)} className="text-gray-400 hover:text-red-500">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function AnimalsFoodTracker() {
  return <FeatureFlag flag="animals_food_tracker"><AnimalsFoodTrackerInner /></FeatureFlag>
}

/* ───────────────────────────── crisis: Stiller Alarm-Button ───────────────────────────── */

interface TrustedContact {
  id: string
  name: string
  phone: string
}

function CrisisSilentAlarmInner() {
  const [contacts, setContacts] = useFeatureStorage<TrustedContact[]>('crisis_silent_alarm_contacts', [])
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [sending, setSending] = useState(false)

  const addContact = () => {
    if (!name.trim() || !phone.trim()) return
    setContacts(prev => [...prev, { id: crypto.randomUUID(), name: name.trim(), phone: phone.trim() }].slice(0, 5))
    setName('')
    setPhone('')
  }

  const triggerAlarm = () => {
    if (contacts.length === 0) {
      toast.error('Erst Vertrauenskontakte hinzufügen')
      return
    }
    setSending(true)
    navigator.geolocation?.getCurrentPosition(
      pos => {
        const link = `https://maps.google.com/?q=${pos.coords.latitude},${pos.coords.longitude}`
        contacts.forEach(c => {
          const body = encodeURIComponent(`Ich brauche Hilfe. Mein Standort: ${link}`)
          window.open(`sms:${c.phone}?body=${body}`, '_blank')
        })
        toast.success('Stiller Alarm an ' + contacts.length + ' Kontakte ausgelöst')
        setSending(false)
      },
      () => {
        toast.error('Standort nicht verfügbar')
        setSending(false)
      },
      { enableHighAccuracy: true, timeout: 7000 },
    )
  }

  return (
    <FeatureCard
      icon={<Siren className="w-5 h-5" />}
      title="Stiller Alarm"
      subtitle="Sendet Standort an deine Vertrauenskontakte"
      accent="red"
    >
      <div className="flex gap-2 mb-3">
        <input value={name} onChange={e => setName(e.target.value)} placeholder="Name" className="input py-2 text-sm flex-1" maxLength={30} />
        <input value={phone} onChange={e => setPhone(e.target.value)} placeholder="Telefon" className="input py-2 text-sm flex-1" maxLength={20} />
        <PillButton onClick={addContact} disabled={!name.trim() || !phone.trim()}>+</PillButton>
      </div>
      {contacts.length > 0 && (
        <ul className="space-y-1 mb-3">
          {contacts.map(c => (
            <li key={c.id} className="flex items-center justify-between text-xs text-gray-600 bg-stone-50 rounded-lg px-2 py-1">
              <span>{c.name} · {c.phone}</span>
              <button onClick={() => setContacts(prev => prev.filter(x => x.id !== c.id))} className="text-gray-400 hover:text-red-500">
                <Trash2 className="w-3 h-3" />
              </button>
            </li>
          ))}
        </ul>
      )}
      <button
        onClick={triggerAlarm}
        disabled={sending}
        className="w-full py-3 bg-red-600 hover:bg-red-700 text-white font-bold rounded-xl text-sm flex items-center justify-center gap-2 disabled:opacity-60"
      >
        <Siren className="w-4 h-4" /> {sending ? 'Sende Standort…' : 'Stillen Alarm auslösen'}
      </button>
    </FeatureCard>
  )
}

export function CrisisSilentAlarm() {
  return <FeatureFlag flag="crisis_silent_alarm"><CrisisSilentAlarmInner /></FeatureFlag>
}

/* ───────────────────────────── mental-support: Reden-Queue ───────────────────────────── */

function MentalSupportQueueInner() {
  const [queue, setQueue] = useFeatureStorage<{ id: string; topic: string; at: number }[]>('mental_support_queue', [])
  const [topic, setTopic] = useState('Allgemein')

  const enqueue = () => {
    setQueue(prev => [{ id: crypto.randomUUID(), topic, at: Date.now() }, ...prev].slice(0, 10))
    toast.success('Du stehst in der Warteschlange')
  }
  const leave = (id: string) => setQueue(prev => prev.filter(q => q.id !== id))

  return (
    <FeatureCard
      icon={<MessageCircleHeart className="w-5 h-5" />}
      title="Jemand zum Reden"
      subtitle="Anonyme Warteschlange – ein Zuhörer meldet sich bei dir"
      accent="sky"
    >
      <div className="flex gap-2 mb-3">
        <select value={topic} onChange={e => setTopic(e.target.value)} className="input py-2 text-sm flex-1">
          <option>Allgemein</option>
          <option>Einsamkeit</option>
          <option>Stress</option>
          <option>Trauer</option>
          <option>Angst</option>
        </select>
        <PillButton onClick={enqueue}>In Warteschlange</PillButton>
      </div>
      {queue.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Niemand wartet gerade.</p>
      ) : (
        <ul className="space-y-1">
          {queue.map(q => (
            <li key={q.id} className="flex items-center justify-between text-xs bg-sky-50 border border-sky-100 rounded-lg px-3 py-1.5">
              <span className="text-sky-700 font-semibold">{q.topic}</span>
              <button onClick={() => leave(q.id)} className="text-gray-400 hover:text-red-500">
                <Trash2 className="w-3 h-3" />
              </button>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function MentalSupportQueue() {
  return <FeatureFlag flag="mental_support_queue"><MentalSupportQueueInner /></FeatureFlag>
}

/* ───────────────────────────── rescuer: Ersthelfer-Pager ───────────────────────────── */

function RescuerPagerInner() {
  const [isOnCall, setIsOnCall] = useFeatureStorage<boolean>('rescuer_pager_on_call', false)
  const [radius, setRadius] = useFeatureStorage<number>('rescuer_pager_radius_km', 2)

  return (
    <FeatureCard
      icon={<Radio className="w-5 h-5" />}
      title="Ersthelfer-Pager"
      subtitle="Werde benachrichtigt, wenn in deiner Nähe Hilfe gebraucht wird"
      accent="primary"
    >
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-gray-700">Im Dienst</span>
        <button
          onClick={() => { setIsOnCall(!isOnCall); toast.success(!isOnCall ? 'Du bist im Dienst' : 'Dienst beendet') }}
          className={`relative w-12 h-6 rounded-full transition-colors ${isOnCall ? 'bg-primary-500' : 'bg-gray-300'}`}
          aria-pressed={isOnCall}
        >
          <span className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${isOnCall ? 'translate-x-6' : 'translate-x-0.5'}`} />
        </button>
      </div>
      <label className="block text-xs text-gray-500 mb-1">Einsatz-Radius: {radius} km</label>
      <input type="range" min={1} max={10} value={radius} onChange={e => setRadius(Number(e.target.value))} className="w-full accent-primary-500" />
      {isOnCall && (
        <div className="mt-3 flex items-center gap-2 text-xs text-primary-700 bg-primary-50 border border-primary-100 rounded-xl px-3 py-2">
          <MapPin className="w-3.5 h-3.5" /> Du bist für einen Umkreis von {radius} km erreichbar.
        </div>
      )}
    </FeatureCard>
  )
}

export function RescuerPager() {
  return <FeatureFlag flag="rescuer_pager"><RescuerPagerInner /></FeatureFlag>
}
