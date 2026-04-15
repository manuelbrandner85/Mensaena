'use client'

import { useState, useEffect } from 'react'
import { BookOpen, Library, GraduationCap, Target, Award, Bookmark, Plus, Trash2, Check } from 'lucide-react'
import toast from 'react-hot-toast'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── knowledge: Bookmarks ───────────────────────────── */

interface Tutorial {
  id: string
  title: string
  minutes: number
  bookmarked: boolean
}

const SEED_TUTORIALS: Tutorial[] = [
  { id: 't1', title: 'Erste Hilfe am Kind – Kompakt', minutes: 3, bookmarked: false },
  { id: 't2', title: 'Hochbeet anlegen in 3 Schritten', minutes: 2, bookmarked: false },
  { id: 't3', title: 'Kompost richtig schichten', minutes: 3, bookmarked: false },
  { id: 't4', title: 'Energiespar-Tipps für den Winter', minutes: 2, bookmarked: false },
]

function KnowledgeBookmarksInner() {
  const [items, setItems] = useFeatureStorage<Tutorial[]>('knowledge_bookmarks', SEED_TUTORIALS)

  const toggle = (id: string) =>
    setItems(prev => prev.map(t => (t.id === id ? { ...t, bookmarked: !t.bookmarked } : t)))

  return (
    <FeatureCard icon={<BookOpen className="w-5 h-5" />} title="Kurz-Tutorials" subtitle="Unter 3 Minuten Lesezeit – merken mit einem Klick" accent="violet">
      <ul className="space-y-1.5">
        {items.map(t => (
          <li key={t.id} className="flex items-center justify-between text-sm bg-violet-50/50 border border-violet-100 rounded-xl px-3 py-2">
            <div className="min-w-0">
              <p className="text-gray-900 font-medium truncate">{t.title}</p>
              <p className="text-xs text-gray-500">{t.minutes} Min. Lesezeit</p>
            </div>
            <button
              onClick={() => toggle(t.id)}
              className={`ml-2 flex-shrink-0 p-2 rounded-lg transition-colors ${
                t.bookmarked ? 'bg-violet-500 text-white' : 'bg-white text-violet-400 border border-violet-200'
              }`}
              aria-pressed={t.bookmarked}
            >
              <Bookmark className="w-4 h-4" />
            </button>
          </li>
        ))}
      </ul>
    </FeatureCard>
  )
}

export function KnowledgeBookmarks() {
  return <FeatureFlag flag="knowledge_bookmarks"><KnowledgeBookmarksInner /></FeatureFlag>
}

/* ───────────────────────────── wiki: Local entries ───────────────────────────── */

interface WikiEntry {
  id: string
  topic: string
  info: string
}

const SEED_WIKI: WikiEntry[] = [
  { id: 'w1', topic: 'Müllabfuhr', info: 'Restmüll jeden 2. Dienstag' },
  { id: 'w2', topic: 'Notarzt', info: '112 – Stadtklinik Süd' },
]

function WikiLocalEntriesInner() {
  const [entries, setEntries] = useFeatureStorage<WikiEntry[]>('wiki_local_entries', SEED_WIKI)
  const [topic, setTopic] = useState('')
  const [info, setInfo] = useState('')

  const add = () => {
    if (!topic.trim() || !info.trim()) return
    setEntries(prev => [{ id: crypto.randomUUID(), topic: topic.trim(), info: info.trim() }, ...prev].slice(0, 30))
    setTopic('')
    setInfo('')
    toast.success('Wiki-Eintrag gespeichert')
  }

  const remove = (id: string) => setEntries(prev => prev.filter(e => e.id !== id))

  return (
    <FeatureCard icon={<Library className="w-5 h-5" />} title="Nachbarschafts-Wiki" subtitle="Kurze Infos zu Müll, Ärzten, Öffnungszeiten" accent="sky">
      <div className="flex gap-2 mb-3">
        <input value={topic} onChange={e => setTopic(e.target.value)} placeholder="Thema" className="input py-2 text-sm w-28" maxLength={30} />
        <input value={info} onChange={e => setInfo(e.target.value)} placeholder="Info" className="input py-2 text-sm flex-1" maxLength={120} />
        <PillButton onClick={add} disabled={!topic.trim() || !info.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      <ul className="space-y-1">
        {entries.map(e => (
          <li key={e.id} className="flex items-center justify-between text-sm bg-sky-50/60 border border-sky-100 rounded-xl px-3 py-1.5">
            <span className="truncate"><span className="text-sky-700 font-semibold">{e.topic}:</span> {e.info}</span>
            <button onClick={() => remove(e.id)} className="text-gray-400 hover:text-red-500">
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          </li>
        ))}
      </ul>
    </FeatureCard>
  )
}

export function WikiLocalEntries() {
  return <FeatureFlag flag="wiki_local_entries"><WikiLocalEntriesInner /></FeatureFlag>
}

/* ───────────────────────────── skills: Matching ───────────────────────────── */

interface SkillRequest {
  id: string
  skill: string
  learner: string
  matched?: string
}

function SkillsMatchingInner() {
  const [requests, setRequests] = useFeatureStorage<SkillRequest[]>('skills_matching', [])
  const [skill, setSkill] = useState('')
  const [learner, setLearner] = useState('')

  const add = () => {
    if (!skill.trim() || !learner.trim()) return
    setRequests(prev => [{ id: crypto.randomUUID(), skill: skill.trim(), learner: learner.trim() }, ...prev].slice(0, 20))
    setSkill('')
    setLearner('')
    toast.success('Suche angelegt')
  }

  const offer = (id: string) => {
    const name = window.prompt('Dein Name als Lehrer:innen-Kontakt?')
    if (!name?.trim()) return
    setRequests(prev => prev.map(r => (r.id === id ? { ...r, matched: name.trim() } : r)))
    toast.success('Match angeboten')
  }

  return (
    <FeatureCard icon={<GraduationCap className="w-5 h-5" />} title="Skill-Matching" subtitle={'„Wer kann mir X beibringen?"'} accent="violet">
      <div className="flex gap-2 mb-3">
        <input value={skill} onChange={e => setSkill(e.target.value)} placeholder="Skill (z.B. Nähen)" className="input py-2 text-sm flex-1" maxLength={40} />
        <input value={learner} onChange={e => setLearner(e.target.value)} placeholder="Dein Name" className="input py-2 text-sm w-32" maxLength={30} />
        <PillButton onClick={add} disabled={!skill.trim() || !learner.trim()}>Suchen</PillButton>
      </div>
      {requests.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Anfragen.</p>
      ) : (
        <ul className="space-y-1">
          {requests.map(r => (
            <li key={r.id} className="flex items-center justify-between text-sm bg-violet-50/50 border border-violet-100 rounded-xl px-3 py-1.5">
              <span className="truncate"><span className="text-violet-700 font-semibold">{r.skill}</span> — {r.learner}</span>
              {r.matched ? (
                <span className="text-xs text-primary-600 font-semibold flex items-center gap-1"><Check className="w-3 h-3" /> {r.matched}</span>
              ) : (
                <button onClick={() => offer(r.id)} className="text-xs text-violet-600 hover:text-violet-800 font-semibold">Anbieten</button>
              )}
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function SkillsMatching() {
  return <FeatureFlag flag="skills_matching"><SkillsMatchingInner /></FeatureFlag>
}

/* ───────────────────────────── challenges: Weekly ───────────────────────────── */

const WEEKLY_CHALLENGES = [
  'Sprich mit einem bisher unbekannten Nachbarn',
  'Hilf jemandem mit den Einkaufstüten',
  'Teile etwas aus deinem Haushalt',
  'Gieße die Pflanzen eines Nachbarn',
  'Schreibe einer älteren Person eine Karte',
  'Räume gemeinsam einen öffentlichen Platz auf',
]

function ChallengesWeeklyInner() {
  const [done, setDone] = useFeatureStorage<Record<string, boolean>>('challenges_weekly', {})
  const [week, setWeek] = useState(() => Math.floor(Date.now() / (7 * 86400_000)))

  useEffect(() => {
    const w = Math.floor(Date.now() / (7 * 86400_000))
    setWeek(w)
  }, [])

  const toggle = (title: string) => setDone(prev => ({ ...prev, [title]: !prev[title] }))
  const completedCount = Object.values(done).filter(Boolean).length

  // Rotate: show 3 challenges based on current week
  const slice = WEEKLY_CHALLENGES.slice((week * 3) % WEEKLY_CHALLENGES.length, ((week * 3) % WEEKLY_CHALLENGES.length) + 3)
  const rotated = slice.length === 3 ? slice : [...slice, ...WEEKLY_CHALLENGES.slice(0, 3 - slice.length)]

  return (
    <FeatureCard icon={<Target className="w-5 h-5" />} title="Wochen-Challenges" subtitle={`Diese Woche · ${completedCount} abgeschlossen`} accent="primary">
      <ul className="space-y-1.5">
        {rotated.map(c => (
          <li key={c} className="flex items-center justify-between text-sm bg-primary-50/50 border border-primary-100 rounded-xl px-3 py-2">
            <span className={`truncate ${done[c] ? 'line-through text-gray-400' : 'text-gray-800'}`}>{c}</span>
            <button
              onClick={() => toggle(c)}
              className={`ml-2 flex-shrink-0 w-6 h-6 rounded-full border-2 flex items-center justify-center transition-colors ${
                done[c] ? 'bg-primary-500 border-primary-500 text-white' : 'border-primary-300'
              }`}
              aria-pressed={!!done[c]}
            >
              {done[c] && <Check className="w-3.5 h-3.5" />}
            </button>
          </li>
        ))}
      </ul>
    </FeatureCard>
  )
}

export function ChallengesWeekly() {
  return <FeatureFlag flag="challenges_weekly"><ChallengesWeeklyInner /></FeatureFlag>
}

/* ───────────────────────────── badges: Seasonal ───────────────────────────── */

function getCurrentSeason(): { name: string; emoji: string; accent: string } {
  const m = new Date().getMonth()
  if (m >= 2 && m <= 4) return { name: 'Frühling', emoji: '🌱', accent: 'bg-primary-100 text-primary-700' }
  if (m >= 5 && m <= 7) return { name: 'Sommer',   emoji: '☀️', accent: 'bg-amber-100 text-amber-700' }
  if (m >= 8 && m <= 10) return { name: 'Herbst',  emoji: '🍂', accent: 'bg-orange-100 text-orange-700' }
  return { name: 'Winter', emoji: '❄️', accent: 'bg-sky-100 text-sky-700' }
}

function BadgesSeasonalInner() {
  const season = getCurrentSeason()
  const [earned, setEarned] = useFeatureStorage<string[]>('badges_seasonal', [])
  const badgeId = `${season.name}-${new Date().getFullYear()}`
  const has = earned.includes(badgeId)

  const claim = () => {
    if (has) return
    setEarned(prev => [...prev, badgeId])
    toast.success(`Abzeichen „${season.name} ${new Date().getFullYear()}" freigeschaltet`)
  }

  return (
    <FeatureCard icon={<Award className="w-5 h-5" />} title="Saison-Abzeichen" subtitle="Sammle jedes Quartal ein neues Badge" accent="amber">
      <div className="flex items-center gap-4 mb-3">
        <div className={`w-16 h-16 rounded-2xl ${season.accent} flex items-center justify-center text-3xl border`}>
          {season.emoji}
        </div>
        <div className="flex-1">
          <p className="font-bold text-gray-900">{season.name} {new Date().getFullYear()}</p>
          <p className="text-xs text-gray-500">{earned.length} Abzeichen gesammelt</p>
        </div>
        <PillButton onClick={claim} disabled={has}>{has ? 'Erhalten' : 'Freischalten'}</PillButton>
      </div>
      {earned.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {earned.map(id => (
            <span key={id} className="text-xs px-2.5 py-1 rounded-full bg-amber-50 border border-amber-100 text-amber-700 font-semibold">
              {id}
            </span>
          ))}
        </div>
      )}
    </FeatureCard>
  )
}

export function BadgesSeasonal() {
  return <FeatureFlag flag="badges_seasonal"><BadgesSeasonalInner /></FeatureFlag>
}
