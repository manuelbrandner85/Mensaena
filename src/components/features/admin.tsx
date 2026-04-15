'use client'

import { useState } from 'react'
import { Building2, ShieldCheck, FileText, Tag, Moon, Inbox, Plus, Trash2, Check, X, Copy } from 'lucide-react'
import toast from 'react-hot-toast'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── organizations: Invite links ───────────────────────────── */

interface Invite {
  id: string
  org: string
  code: string
  createdAt: number
}

function OrganizationsInviteInner() {
  const [invites, setInvites] = useFeatureStorage<Invite[]>('organizations_invite', [])
  const [org, setOrg] = useState('')

  const generate = () => {
    if (!org.trim()) return
    const code = Math.random().toString(36).slice(2, 10).toUpperCase()
    setInvites(prev => [{ id: crypto.randomUUID(), org: org.trim(), code, createdAt: Date.now() }, ...prev].slice(0, 10))
    setOrg('')
    toast.success('Einladung erstellt')
  }

  const copy = (code: string) => {
    navigator.clipboard?.writeText(`https://www.mensaena.de/invite/${code}`)
    toast.success('Link kopiert')
  }

  const revoke = (id: string) => setInvites(prev => prev.filter(i => i.id !== id))

  return (
    <FeatureCard icon={<Building2 className="w-5 h-5" />} title="Vereins-Einladungen" subtitle="Generiere Einladungs-Codes für neue Mitglieder" accent="violet">
      <div className="flex gap-2 mb-3">
        <input value={org} onChange={e => setOrg(e.target.value)} placeholder="Verein / Organisation" className="input py-2 text-sm flex-1" maxLength={50} />
        <PillButton onClick={generate} disabled={!org.trim()}>Einladen</PillButton>
      </div>
      {invites.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Einladungen.</p>
      ) : (
        <ul className="space-y-1">
          {invites.map(i => (
            <li key={i.id} className="flex items-center justify-between text-sm bg-violet-50/60 border border-violet-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{i.org}</span>
              <span className="flex items-center gap-2">
                <code className="text-xs text-violet-700 font-mono bg-white px-2 py-0.5 rounded border border-violet-100">{i.code}</code>
                <button onClick={() => copy(i.code)} className="text-violet-500 hover:text-violet-700"><Copy className="w-3.5 h-3.5" /></button>
                <button onClick={() => revoke(i.id)} className="text-gray-400 hover:text-red-500"><Trash2 className="w-3.5 h-3.5" /></button>
              </span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function OrganizationsInvite() {
  return <FeatureFlag flag="organizations_invite"><OrganizationsInviteInner /></FeatureFlag>
}

/* ───────────────────────────── admin: Moderation queue ───────────────────────────── */

interface Report {
  id: string
  target: string
  reason: string
  status: 'open' | 'resolved' | 'dismissed'
}

function AdminModerationQueueInner() {
  const [reports, setReports] = useFeatureStorage<Report[]>('admin_moderation_queue', [
    { id: 'r1', target: 'Post #1234',  reason: 'Spam',       status: 'open' },
    { id: 'r2', target: 'User @beatrix', reason: 'Beleidigung', status: 'open' },
  ])

  const update = (id: string, status: Report['status']) =>
    setReports(prev => prev.map(r => (r.id === id ? { ...r, status } : r)))

  const open = reports.filter(r => r.status === 'open')

  return (
    <FeatureCard icon={<ShieldCheck className="w-5 h-5" />} title="Moderations-Queue" subtitle={`${open.length} offene Meldungen`} accent="red">
      {reports.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine Meldungen.</p>
      ) : (
        <ul className="space-y-1">
          {reports.map(r => (
            <li key={r.id} className={`flex items-center justify-between text-sm border rounded-xl px-3 py-1.5 ${
              r.status === 'open' ? 'bg-red-50/60 border-red-100' :
              r.status === 'resolved' ? 'bg-primary-50/50 border-primary-100' :
              'bg-stone-50 border-stone-100 opacity-60'
            }`}>
              <span className="truncate"><span className="font-semibold">{r.target}</span> · {r.reason}</span>
              {r.status === 'open' ? (
                <span className="flex items-center gap-1">
                  <button onClick={() => update(r.id, 'resolved')} className="text-primary-600 hover:text-primary-800 p-1"><Check className="w-3.5 h-3.5" /></button>
                  <button onClick={() => update(r.id, 'dismissed')} className="text-gray-400 hover:text-red-500 p-1"><X className="w-3.5 h-3.5" /></button>
                </span>
              ) : (
                <span className="text-xs text-gray-500">{r.status === 'resolved' ? 'erledigt' : 'verworfen'}</span>
              )}
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function AdminModerationQueue() {
  return <FeatureFlag flag="admin_moderation_queue"><AdminModerationQueueInner /></FeatureFlag>
}

/* ───────────────────────────── create: Templates ───────────────────────────── */

const TEMPLATES = [
  { id: 'help_shopping', label: 'Einkaufs-Hilfe gesucht',         body: 'Ich suche Unterstützung beim Einkauf am …' },
  { id: 'offer_tools',   label: 'Werkzeug zu verleihen',          body: 'Ich verleihe gerne: …' },
  { id: 'event',         label: 'Nachbarschafts-Event ankündigen', body: 'Am … treffen wir uns zu: …' },
  { id: 'swap',          label: 'Tausch-Angebot',                  body: 'Ich biete … und suche … im Tausch.' },
  { id: 'thanks',        label: 'Dankeschön an Nachbarn',          body: 'Ein herzliches Dankeschön an …' },
]

function CreateTemplatesInner() {
  const [picked, setPicked] = useState<string | null>(null)
  const use = (id: string) => {
    setPicked(id)
    const t = TEMPLATES.find(x => x.id === id)
    if (t) {
      navigator.clipboard?.writeText(t.body)
      toast.success('Vorlage in Zwischenablage')
    }
  }

  return (
    <FeatureCard icon={<FileText className="w-5 h-5" />} title="Post-Vorlagen" subtitle="Starte schneller mit fertigen Bausteinen" accent="sky">
      <ul className="space-y-1">
        {TEMPLATES.map(t => (
          <li key={t.id} className={`flex items-center justify-between text-sm border rounded-xl px-3 py-1.5 ${picked === t.id ? 'bg-sky-100 border-sky-200' : 'bg-sky-50/60 border-sky-100'}`}>
            <span className="truncate">{t.label}</span>
            <button onClick={() => use(t.id)} className="text-xs text-sky-700 font-semibold hover:text-sky-900">Nutzen</button>
          </li>
        ))}
      </ul>
    </FeatureCard>
  )
}

export function CreateTemplates() {
  return <FeatureFlag flag="create_templates"><CreateTemplatesInner /></FeatureFlag>
}

/* ───────────────────────────── profile: Offer/Seek tags ───────────────────────────── */

function ProfileOfferSeekTagsInner() {
  const [offers, setOffers] = useFeatureStorage<string[]>('profile_offer_tags', [])
  const [seeks, setSeeks] = useFeatureStorage<string[]>('profile_seek_tags', [])
  const [input, setInput] = useState('')

  const add = (kind: 'offer' | 'seek') => {
    const t = input.trim()
    if (!t) return
    if (kind === 'offer') setOffers(prev => [...new Set([...prev, t])].slice(0, 10))
    else setSeeks(prev => [...new Set([...prev, t])].slice(0, 10))
    setInput('')
  }

  const removeOffer = (t: string) => setOffers(prev => prev.filter(x => x !== t))
  const removeSeek = (t: string) => setSeeks(prev => prev.filter(x => x !== t))

  return (
    <FeatureCard icon={<Tag className="w-5 h-5" />} title={'„Biete / Suche"-Tags'} subtitle="Zeig anderen, womit du helfen kannst und was du brauchst" accent="primary">
      <div className="flex gap-2 mb-3">
        <input value={input} onChange={e => setInput(e.target.value)} placeholder="z.B. Fahrradreparatur" className="input py-2 text-sm flex-1" maxLength={30} />
        <PillButton onClick={() => add('offer')}>+ Biete</PillButton>
        <PillButton variant="ghost" onClick={() => add('seek')}>+ Suche</PillButton>
      </div>
      <div className="mb-3">
        <p className="text-xs font-semibold text-primary-700 mb-1">Ich biete</p>
        <div className="flex flex-wrap gap-1.5">
          {offers.length === 0 ? (
            <span className="text-xs text-gray-400 italic">– noch keine –</span>
          ) : offers.map(t => (
            <button key={t} onClick={() => removeOffer(t)} className="group inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-primary-50 border border-primary-100 text-primary-700 hover:bg-primary-100">
              {t} <X className="w-3 h-3 opacity-0 group-hover:opacity-100" />
            </button>
          ))}
        </div>
      </div>
      <div>
        <p className="text-xs font-semibold text-amber-700 mb-1">Ich suche</p>
        <div className="flex flex-wrap gap-1.5">
          {seeks.length === 0 ? (
            <span className="text-xs text-gray-400 italic">– noch keine –</span>
          ) : seeks.map(t => (
            <button key={t} onClick={() => removeSeek(t)} className="group inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-amber-50 border border-amber-100 text-amber-700 hover:bg-amber-100">
              {t} <X className="w-3 h-3 opacity-0 group-hover:opacity-100" />
            </button>
          ))}
        </div>
      </div>
    </FeatureCard>
  )
}

export function ProfileOfferSeekTags() {
  return <FeatureFlag flag="profile_offer_seek_tags"><ProfileOfferSeekTagsInner /></FeatureFlag>
}

/* ───────────────────────────── settings: Quiet hours ───────────────────────────── */

interface QuietHours {
  enabled: boolean
  from: string
  to: string
}

function SettingsQuietHoursInner() {
  const [hours, setHours] = useFeatureStorage<QuietHours>('settings_quiet_hours', { enabled: false, from: '22:00', to: '07:00' })

  return (
    <FeatureCard icon={<Moon className="w-5 h-5" />} title="Ruhezeiten" subtitle="Keine Benachrichtigungen in diesem Zeitfenster" accent="violet">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-gray-700">Aktiv</span>
        <button
          onClick={() => setHours(prev => ({ ...prev, enabled: !prev.enabled }))}
          className={`relative w-12 h-6 rounded-full transition-colors ${hours.enabled ? 'bg-violet-500' : 'bg-gray-300'}`}
          aria-pressed={hours.enabled}
        >
          <span className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${hours.enabled ? 'translate-x-6' : 'translate-x-0.5'}`} />
        </button>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <label className="text-xs text-gray-500">
          Von
          <input type="time" value={hours.from} onChange={e => setHours(prev => ({ ...prev, from: e.target.value }))} className="input py-2 text-sm mt-1 w-full" />
        </label>
        <label className="text-xs text-gray-500">
          Bis
          <input type="time" value={hours.to} onChange={e => setHours(prev => ({ ...prev, to: e.target.value }))} className="input py-2 text-sm mt-1 w-full" />
        </label>
      </div>
      {hours.enabled && (
        <p className="mt-3 text-xs text-violet-700 bg-violet-50 border border-violet-100 rounded-xl px-3 py-2">
          Stumm von {hours.from} bis {hours.to} Uhr.
        </p>
      )}
    </FeatureCard>
  )
}

export function SettingsQuietHours() {
  return <FeatureFlag flag="settings_quiet_hours"><SettingsQuietHoursInner /></FeatureFlag>
}

/* ───────────────────────────── notifications: Digest ───────────────────────────── */

interface DigestSettings {
  enabled: boolean
  intervalHours: number
}

function NotificationsDigestInner() {
  const [digest, setDigest] = useFeatureStorage<DigestSettings>('notifications_digest', { enabled: true, intervalHours: 2 })

  return (
    <FeatureCard icon={<Inbox className="w-5 h-5" />} title="Notification-Digest" subtitle="Bündelt Benachrichtigungen statt sie sofort zu senden" accent="primary">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-gray-700">Digest aktiv</span>
        <button
          onClick={() => setDigest(prev => ({ ...prev, enabled: !prev.enabled }))}
          className={`relative w-12 h-6 rounded-full transition-colors ${digest.enabled ? 'bg-primary-500' : 'bg-gray-300'}`}
          aria-pressed={digest.enabled}
        >
          <span className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${digest.enabled ? 'translate-x-6' : 'translate-x-0.5'}`} />
        </button>
      </div>
      <label className="block text-xs text-gray-500 mb-1">Intervall: alle {digest.intervalHours}h</label>
      <input
        type="range"
        min={1}
        max={12}
        value={digest.intervalHours}
        onChange={e => setDigest(prev => ({ ...prev, intervalHours: Number(e.target.value) }))}
        className="w-full accent-primary-500"
      />
      {digest.enabled && (
        <p className="mt-2 text-xs text-primary-700 bg-primary-50 border border-primary-100 rounded-xl px-3 py-2">
          Du erhältst alle {digest.intervalHours} Stunden eine gebündelte Übersicht.
        </p>
      )}
    </FeatureCard>
  )
}

export function NotificationsDigest() {
  return <FeatureFlag flag="notifications_digest"><NotificationsDigestInner /></FeatureFlag>
}
