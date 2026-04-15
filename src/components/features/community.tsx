'use client'

import { useState } from 'react'
import { CalendarClock, Trophy, Car, Lock, Heart, Mic, Trash2, Plus, Square } from 'lucide-react'
import toast from 'react-hot-toast'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── board: Ablaufdatum ───────────────────────────── */

interface BoardEntry {
  id: string
  title: string
  expiresAt: number
}

function BoardExpiryInner() {
  const [entries, setEntries] = useFeatureStorage<BoardEntry[]>('board_expiry', [])
  const [title, setTitle] = useState('')
  const [days, setDays] = useState(7)

  const now = Date.now()
  const visible = entries.filter(e => e.expiresAt > now)

  const add = () => {
    if (title.trim().length < 3) return
    setEntries(prev => [
      { id: crypto.randomUUID(), title: title.trim(), expiresAt: now + days * 86400_000 },
      ...prev,
    ].slice(0, 20))
    setTitle('')
    toast.success('Eintrag mit Ablauf angelegt')
  }

  return (
    <FeatureCard
      icon={<CalendarClock className="w-5 h-5" />}
      title="Ablaufdatum"
      subtitle="Einträge verschwinden automatisch nach X Tagen"
      accent="amber"
    >
      <div className="flex gap-2 mb-3">
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="z.B. Flohmarkt am Samstag" className="input py-2 text-sm flex-1" maxLength={60} />
        <select value={days} onChange={e => setDays(Number(e.target.value))} className="input py-2 text-sm w-20">
          <option value={1}>1 T</option>
          <option value={3}>3 T</option>
          <option value={7}>7 T</option>
          <option value={14}>14 T</option>
          <option value={30}>30 T</option>
        </select>
        <PillButton onClick={add} disabled={title.trim().length < 3}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {visible.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine aktiven Einträge.</p>
      ) : (
        <ul className="space-y-1">
          {visible.map(e => {
            const daysLeft = Math.max(0, Math.ceil((e.expiresAt - now) / 86400_000))
            return (
              <li key={e.id} className="flex items-center justify-between text-sm bg-amber-50/60 border border-amber-100 rounded-xl px-3 py-1.5">
                <span className="truncate">{e.title}</span>
                <span className="text-xs text-amber-700 font-semibold whitespace-nowrap">noch {daysLeft} T</span>
              </li>
            )
          })}
        </ul>
      )}
    </FeatureCard>
  )
}

export function BoardExpiry() {
  return <FeatureFlag flag="board_expiry"><BoardExpiryInner /></FeatureFlag>
}

/* ───────────────────────────── community: Nachbar des Monats ───────────────────────────── */

interface Vote {
  name: string
  count: number
}

function CommunityVotingInner() {
  const [votes, setVotes] = useFeatureStorage<Vote[]>('community_voting', [])
  const [name, setName] = useState('')

  const vote = (n: string) => {
    const trimmed = n.trim()
    if (trimmed.length < 2) return
    setVotes(prev => {
      const idx = prev.findIndex(v => v.name.toLowerCase() === trimmed.toLowerCase())
      if (idx >= 0) {
        const copy = [...prev]
        copy[idx] = { ...copy[idx], count: copy[idx].count + 1 }
        return copy
      }
      return [...prev, { name: trimmed, count: 1 }]
    })
    setName('')
    toast.success('Stimme gezählt')
  }

  const sorted = [...votes].sort((a, b) => b.count - a.count).slice(0, 5)

  return (
    <FeatureCard
      icon={<Trophy className="w-5 h-5" />}
      title="Nachbar des Monats"
      subtitle="Wähle den hilfreichsten Nachbarn"
      accent="amber"
    >
      <div className="flex gap-2 mb-3">
        <input value={name} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && vote(name)} placeholder="Name des Nachbarn" className="input py-2 text-sm flex-1" maxLength={40} />
        <PillButton onClick={() => vote(name)} disabled={name.trim().length < 2}>Stimmen</PillButton>
      </div>
      {sorted.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Stimmen abgegeben.</p>
      ) : (
        <ol className="space-y-1">
          {sorted.map((v, i) => (
            <li key={v.name} className="flex items-center justify-between text-sm bg-amber-50/60 border border-amber-100 rounded-xl px-3 py-1.5">
              <span className="flex items-center gap-2">
                <span className="text-amber-700 font-bold">#{i + 1}</span>
                {v.name}
              </span>
              <span className="text-xs font-semibold text-amber-700">{v.count} Stimmen</span>
            </li>
          ))}
        </ol>
      )}
    </FeatureCard>
  )
}

export function CommunityVoting() {
  return <FeatureFlag flag="community_voting"><CommunityVotingInner /></FeatureFlag>
}

/* ───────────────────────────── events: Carpooling ───────────────────────────── */

interface Ride {
  id: string
  driver: string
  from: string
  seats: number
}

function EventsCarpoolingInner() {
  const [rides, setRides] = useFeatureStorage<Ride[]>('events_carpooling', [])
  const [driver, setDriver] = useState('')
  const [from, setFrom] = useState('')
  const [seats, setSeats] = useState(3)

  const add = () => {
    if (!driver.trim() || !from.trim()) return
    setRides(prev => [{ id: crypto.randomUUID(), driver: driver.trim(), from: from.trim(), seats }, ...prev].slice(0, 15))
    setDriver('')
    setFrom('')
    toast.success('Fahrt angeboten')
  }

  const claim = (id: string) => setRides(prev => prev.map(r => r.id === id && r.seats > 0 ? { ...r, seats: r.seats - 1 } : r))
  const remove = (id: string) => setRides(prev => prev.filter(r => r.id !== id))

  return (
    <FeatureCard icon={<Car className="w-5 h-5" />} title="Event-Carpooling" subtitle="Biete oder nimm eine Mitfahrgelegenheit" accent="primary">
      <div className="grid grid-cols-2 gap-2 mb-2">
        <input value={driver} onChange={e => setDriver(e.target.value)} placeholder="Dein Name" className="input py-2 text-sm" maxLength={30} />
        <input value={from} onChange={e => setFrom(e.target.value)} placeholder="Abfahrtsort" className="input py-2 text-sm" maxLength={40} />
      </div>
      <div className="flex items-center gap-2 mb-3">
        <label className="text-xs text-gray-500">Freie Plätze</label>
        <input type="number" min={1} max={8} value={seats} onChange={e => setSeats(Math.max(1, Math.min(8, Number(e.target.value))))} className="input py-1.5 text-sm w-16" />
        <PillButton onClick={add} disabled={!driver.trim() || !from.trim()}>Anbieten</PillButton>
      </div>
      {rides.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine Fahrten eingetragen.</p>
      ) : (
        <ul className="space-y-1">
          {rides.map(r => (
            <li key={r.id} className="flex items-center justify-between text-sm bg-primary-50/50 border border-primary-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{r.driver} ab {r.from}</span>
              <span className="flex items-center gap-2">
                <button onClick={() => claim(r.id)} disabled={r.seats === 0} className="text-xs font-semibold text-primary-700 disabled:text-gray-300">
                  {r.seats} frei
                </button>
                <button onClick={() => remove(r.id)} className="text-gray-400 hover:text-red-500">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function EventsCarpooling() {
  return <FeatureFlag flag="events_carpooling"><EventsCarpoolingInner /></FeatureFlag>
}

/* ───────────────────────────── groups: Private Chats ───────────────────────────── */

interface GroupThread {
  id: string
  title: string
  moderator: string
  createdAt: number
}

function GroupsPrivateChatsInner() {
  const [threads, setThreads] = useFeatureStorage<GroupThread[]>('groups_private_chats', [])
  const [title, setTitle] = useState('')
  const [mod, setMod] = useState('')

  const add = () => {
    if (!title.trim() || !mod.trim()) return
    setThreads(prev => [{ id: crypto.randomUUID(), title: title.trim(), moderator: mod.trim(), createdAt: Date.now() }, ...prev].slice(0, 10))
    setTitle('')
    setMod('')
    toast.success('Privater Chat erstellt')
  }

  return (
    <FeatureCard icon={<Lock className="w-5 h-5" />} title="Private Gruppen-Chats" subtitle="Moderierte Unterhaltungen innerhalb einer Gruppe" accent="violet">
      <div className="flex gap-2 mb-3">
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Chat-Titel" className="input py-2 text-sm flex-1" maxLength={40} />
        <input value={mod} onChange={e => setMod(e.target.value)} placeholder="Moderator" className="input py-2 text-sm w-32" maxLength={30} />
        <PillButton onClick={add} disabled={!title.trim() || !mod.trim()}>Erstellen</PillButton>
      </div>
      {threads.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine privaten Chats.</p>
      ) : (
        <ul className="space-y-1">
          {threads.map(t => (
            <li key={t.id} className="flex items-center justify-between text-sm bg-violet-50/60 border border-violet-100 rounded-xl px-3 py-1.5">
              <span className="truncate flex items-center gap-2"><Lock className="w-3 h-3 text-violet-500" /> {t.title}</span>
              <span className="text-xs text-violet-700 font-semibold">Mod: {t.moderator}</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function GroupsPrivateChats() {
  return <FeatureFlag flag="groups_private_chats"><GroupsPrivateChatsInner /></FeatureFlag>
}

/* ───────────────────────────── posts: Reactions ───────────────────────────── */

const REACTION_SET = [
  { key: 'thanks', emoji: '🙏', label: 'Danke' },
  { key: 'heart',  emoji: '💚', label: 'Herz' },
  { key: 'helpful',emoji: '💡', label: 'Hilfreich' },
  { key: 'hug',    emoji: '🤗', label: 'Umarmung' },
] as const

function PostsReactionsInner() {
  const [counts, setCounts] = useFeatureStorage<Record<string, number>>('posts_reactions', {})

  const bump = (k: string) => setCounts(prev => ({ ...prev, [k]: (prev[k] ?? 0) + 1 }))

  return (
    <FeatureCard icon={<Heart className="w-5 h-5" />} title="Dank-Reaktionen" subtitle="Drücke deinen Dank mit mehr als einem Like aus" accent="rose">
      <div className="grid grid-cols-4 gap-2">
        {REACTION_SET.map(r => (
          <button
            key={r.key}
            onClick={() => bump(r.key)}
            className="flex flex-col items-center py-3 rounded-xl border border-rose-100 bg-rose-50/50 hover:bg-rose-100 transition-colors"
          >
            <span className="text-2xl">{r.emoji}</span>
            <span className="text-[10px] mt-1 text-rose-700 font-semibold">{r.label}</span>
            <span className="text-xs tabular-nums text-rose-900 font-bold">{counts[r.key] ?? 0}</span>
          </button>
        ))}
      </div>
    </FeatureCard>
  )
}

export function PostsReactions() {
  return <FeatureFlag flag="posts_reactions"><PostsReactionsInner /></FeatureFlag>
}

/* ───────────────────────────── chat: Sprachnachrichten ───────────────────────────── */

function ChatVoiceMessagesInner() {
  const [recording, setRecording] = useState(false)
  const [elapsed, setElapsed] = useState(0)
  const [clips, setClips] = useFeatureStorage<{ id: string; duration: number; at: number }[]>('chat_voice_messages', [])

  const start = () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      toast.error('Dein Browser unterstützt keine Sprachaufnahme')
      return
    }
    navigator.mediaDevices.getUserMedia({ audio: true })
      .then(stream => {
        setRecording(true)
        setElapsed(0)
        const startAt = Date.now()
        const tick = setInterval(() => {
          const s = Math.floor((Date.now() - startAt) / 1000)
          setElapsed(s)
          if (s >= 60) finish(stream, tick)
        }, 250)
        ;(window as unknown as { __voiceTick?: ReturnType<typeof setInterval> }).__voiceTick = tick
        ;(window as unknown as { __voiceStream?: MediaStream }).__voiceStream = stream
      })
      .catch(() => toast.error('Mikrofon-Zugriff verweigert'))
  }

  const finish = (stream?: MediaStream, tick?: ReturnType<typeof setInterval>) => {
    const w = window as unknown as { __voiceTick?: ReturnType<typeof setInterval>; __voiceStream?: MediaStream }
    const t = tick ?? w.__voiceTick
    const s = stream ?? w.__voiceStream
    if (t) clearInterval(t)
    if (s) s.getTracks().forEach(tr => tr.stop())
    setRecording(false)
    setClips(prev => [{ id: crypto.randomUUID(), duration: elapsed, at: Date.now() }, ...prev].slice(0, 10))
    toast.success('Sprachnachricht aufgenommen (' + elapsed + 's)')
    setElapsed(0)
  }

  return (
    <FeatureCard icon={<Mic className="w-5 h-5" />} title="Sprachnachrichten" subtitle="Halte gedrückt und sprich – max. 60 Sek." accent="sky">
      <button
        onClick={() => (recording ? finish() : start())}
        className={`w-full py-3 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-colors ${
          recording ? 'bg-red-500 text-white hover:bg-red-600' : 'bg-sky-500 text-white hover:bg-sky-600'
        }`}
      >
        {recording ? <><Square className="w-4 h-4" /> Stop ({elapsed}s)</> : <><Mic className="w-4 h-4" /> Aufnehmen</>}
      </button>
      {clips.length > 0 && (
        <ul className="mt-3 space-y-1">
          {clips.map(c => (
            <li key={c.id} className="flex items-center justify-between text-xs bg-sky-50 border border-sky-100 rounded-lg px-3 py-1.5">
              <span className="flex items-center gap-1.5"><Mic className="w-3 h-3 text-sky-500" /> {c.duration}s Clip</span>
              <span className="text-gray-400">{new Date(c.at).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function ChatVoiceMessages() {
  return <FeatureFlag flag="chat_voice_messages"><ChatVoiceMessagesInner /></FeatureFlag>
}
