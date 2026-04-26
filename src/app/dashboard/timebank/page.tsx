'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Clock, Users, Search, CheckCircle2, XCircle, AlertCircle,
  Loader2, HandCoins, History,
  Calendar, Plus, ChevronDown,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

// ── Types ──────────────────────────────────────────────────────────────────────
interface Profile {
  id: string
  name: string | null
  nickname: string | null
  avatar_url: string | null
}

interface TimebankEntry {
  id: string
  giver_id: string
  receiver_id: string
  hours: number
  description: string
  category: string
  status: 'pending' | 'confirmed' | 'cancelled'
  confirmed_at: string | null
  created_at: string
  help_date: string | null
  giver: Profile
  receiver: Profile
}

// ── Sanitize helpers für PostgREST .or()/ilike ───────────────────────────────
function escapeIlike(s: string): string {
  // Escape ilike-Wildcards: %, _, \
  return s.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
}
function sanitizeForOrFilter(s: string): string {
  // Entferne Zeichen, die die .or()-Syntax brechen würden: , ( ) " \
  return s.replace(/[,()"\\]/g, '').trim()
}

// ── Konstanten ─────────────────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'general',   label: 'Garten & Natur'        },
  { value: 'skills',    label: 'Handwerk & Reparatur'   },
  { value: 'knowledge', label: 'Nachhilfe & Lernen'     },
  { value: 'mental',    label: 'Pflege & Fürsorge'      },
  { value: 'everyday',  label: 'Alltag & Haushalt'      },
  { value: 'food',      label: 'Einkaufen & Versorgung' },
  { value: 'mobility',  label: 'Transport & Mobilität'  },
  { value: 'sharing',   label: 'Teilen & Helfen'        },
]

// ── Hilfsfunktionen ────────────────────────────────────────────────────────────
function initials(p: Profile | null) {
  return ((p?.name ?? p?.nickname ?? '?')[0] ?? '?').toUpperCase()
}

function displayName(p: Profile | null) {
  return p?.name ?? p?.nickname ?? 'Unbekannt'
}

function formatDate(s: string | null) {
  if (!s) return ''
  return new Date(s).toLocaleDateString('de-AT', {
    day: '2-digit', month: '2-digit', year: 'numeric',
  })
}

function formatHours(h: number) {
  const full = Math.floor(h)
  const half = h % 1 >= 0.5
  if (full === 0) return '30 Min.'
  if (half) return `${full} Std. 30 Min.`
  return `${full} Std.`
}

function todayISO() {
  return new Date().toISOString().split('T')[0]
}

// ── Avatar ─────────────────────────────────────────────────────────────────────
function Avatar({ profile, size = 'md' }: { profile: Profile | null; size?: 'sm' | 'md' }) {
  const cls = size === 'sm'
    ? 'w-8 h-8 text-xs'
    : 'w-9 h-9 text-sm'
  return (
    <div className={`${cls} rounded-full bg-amber-100 flex items-center justify-center text-amber-700 font-bold flex-shrink-0 border border-amber-200`}>
      {initials(profile)}
    </div>
  )
}

// ── StatusBadge ────────────────────────────────────────────────────────────────
function StatusBadge({ status }: { status: TimebankEntry['status'] }) {
  const styles = {
    pending:   'bg-amber-50 text-amber-600 border-amber-200',
    confirmed: 'bg-primary-50 text-primary-700 border-primary-200',
    cancelled: 'bg-stone-100 text-ink-400 border-stone-200',
  }
  const labels = {
    pending:   'Ausstehend',
    confirmed: 'Bestätigt',
    cancelled: 'Abgelehnt',
  }
  return (
    <span className={`inline-flex items-center text-xs px-2 py-0.5 rounded-full font-medium border ${styles[status]}`}>
      {labels[status]}
    </span>
  )
}

// ── HilfeForm ──────────────────────────────────────────────────────────────────
function HilfeForm({ userId, onSuccess }: { userId: string; onSuccess: () => void }) {
  const [receiver, setReceiver]       = useState<Profile | null>(null)
  const [query, setQuery]             = useState('')
  const [results, setResults]         = useState<Profile[]>([])
  const [searching, setSearching]     = useState(false)
  const [description, setDescription] = useState('')
  const [category, setCategory]       = useState('general')
  const [stunden, setStunden]         = useState(1)
  const [minuten, setMinuten]         = useState<0 | 30>(0)
  const [date, setDate]               = useState(todayISO())
  const [submitting, setSubmitting]   = useState(false)

  // Debounced Suche
  useEffect(() => {
    const sanitized = sanitizeForOrFilter(query)
    if (sanitized.length < 2) { setResults([]); return }
    let cancelled = false
    const t = setTimeout(async () => {
      setSearching(true)
      const sb = createClient()
      const term = escapeIlike(sanitized)
      const { data, error } = await sb
        .from('profiles')
        .select('id, name, nickname, avatar_url')
        .neq('id', userId)
        .or(`name.ilike.%${term}%,nickname.ilike.%${term}%`)
        .limit(6)
      if (cancelled) return
      if (error) console.error('timebank profile search failed:', error.message)
      setResults((data ?? []) as Profile[])
      setSearching(false)
    }, 300)
    return () => { cancelled = true; clearTimeout(t) }
  }, [query, userId])

  const totalHours = stunden + minuten / 60

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!receiver)          { toast.error('Bitte wähle eine Person aus'); return }
    if (!description.trim()) { toast.error('Bitte beschreibe die geleistete Hilfe'); return }
    if (totalHours <= 0)    { toast.error('Bitte gib eine Zeit an'); return }

    setSubmitting(true)
    const sb = createClient()
    const { error } = await sb.from('timebank_entries').insert({
      giver_id:    userId,
      receiver_id: receiver.id,
      hours:       totalHours,
      description: description.trim(),
      category,
      status:      'pending',
      help_date:   date,
    })

    if (error) {
      toast.error('Fehler: ' + error.message)
    } else {
      toast.success(
        `${formatHours(totalHours)} eingetragen! ${displayName(receiver)} muss noch bestätigen.`
      )
      setReceiver(null)
      setQuery('')
      setDescription('')
      setStunden(1)
      setMinuten(0)
      setDate(todayISO())
      onSuccess()
    }
    setSubmitting(false)
  }

  return (
    <section className="relative bg-white rounded-2xl border border-stone-200 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{ background: 'linear-gradient(90deg, #F59E0B, #F59E0B33)' }}
      />
      {/* Header */}
      <div className="relative bg-gradient-to-r from-amber-500 to-yellow-500 px-6 py-4 overflow-hidden">
        <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />
        <div
          className="absolute inset-0 pointer-events-none"
          style={{ background: 'radial-gradient(circle at 15% 0%, rgba(255,255,255,0.25), transparent 60%)' }}
        />
        <h2 className="relative text-white font-bold text-lg flex items-center gap-2">
          <Plus className="w-5 h-5 float-idle" />
          Hilfe eintragen
        </h2>
        <p className="relative text-amber-100 text-sm mt-0.5">
          Trage deine geleistete Hilfe ein – die andere Person bestätigt.
        </p>
      </div>

      {/* Formular */}
      <form onSubmit={handleSubmit} className="p-6 space-y-5">

        {/* 1. Wem hast du geholfen? */}
        <div>
          <label className="block text-sm font-semibold text-ink-700 mb-1.5">
            Wem hast du geholfen? <span className="text-red-400">*</span>
          </label>
          {receiver ? (
            <div className="flex items-center justify-between p-3 bg-primary-50 border border-primary-200 rounded-xl shadow-soft">
              <div className="flex items-center gap-2.5">
                <Avatar profile={receiver} />
                <div>
                  <p className="text-sm font-semibold text-ink-900">{displayName(receiver)}</p>
                  {receiver.nickname && (
                    <p className="text-xs text-ink-400">@{receiver.nickname}</p>
                  )}
                </div>
              </div>
              <button
                type="button"
                onClick={() => { setReceiver(null); setQuery('') }}
                className="text-xs text-ink-400 hover:text-red-500 transition-colors px-2 py-1 rounded"
              >
                Ändern
              </button>
            </div>
          ) : (
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
              <input
                type="text"
                value={query}
                onChange={e => setQuery(e.target.value)}
                placeholder="Name oder Nickname eingeben…"
                className="w-full pl-9 pr-9 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent"
              />
              {searching && (
                <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-ink-400" />
              )}
              {results.length > 0 && (
                <div className="absolute z-20 w-full mt-1 bg-white border border-stone-200 rounded-xl shadow-card overflow-hidden">
                  {results.map(p => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => { setReceiver(p); setQuery(''); setResults([]) }}
                      className="w-full flex items-center gap-2.5 px-3 py-2.5 hover:bg-amber-50 transition-colors text-left"
                    >
                      <Avatar profile={p} size="sm" />
                      <div>
                        <p className="text-sm font-medium text-ink-900">{displayName(p)}</p>
                        {p.nickname && <p className="text-xs text-ink-400">@{p.nickname}</p>}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* 2. Was hast du gemacht? */}
        <div>
          <label className="block text-sm font-semibold text-ink-700 mb-1.5">
            Was hast du gemacht? <span className="text-red-400">*</span>
          </label>
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="z.B. Garten umgegraben, Einkauf erledigt, Nachhilfe gegeben…"
            rows={3}
            maxLength={300}
            className="w-full px-3 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent resize-none"
          />
          <div className="flex items-center justify-between mt-1.5">
            <div className="relative">
              <select
                value={category}
                onChange={e => setCategory(e.target.value)}
                aria-label="Kategorie wählen"
                className="text-xs text-ink-500 border border-stone-200 rounded-lg px-2 py-1 pr-6 appearance-none focus:outline-none focus:ring-1 focus:ring-amber-400 bg-white"
              >
                {CATEGORIES.map(c => (
                  <option key={c.value} value={c.value}>{c.label}</option>
                ))}
              </select>
              <ChevronDown className="absolute right-1.5 top-1/2 -translate-y-1/2 w-3 h-3 text-ink-400 pointer-events-none" />
            </div>
            <p className="text-xs text-ink-400">{description.length}/300</p>
          </div>
        </div>

        {/* 3 + 4. Wie lange + Datum */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">

          {/* Wie lange? */}
          <div>
            <label className="block text-sm font-semibold text-ink-700 mb-1.5">
              Wie lange?
            </label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <select
                  value={stunden}
                  onChange={e => setStunden(Number(e.target.value))}
                  className="w-full px-3 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 appearance-none bg-white"
                >
                  {Array.from({ length: 9 }, (_, i) => i).map(h => (
                    <option key={h} value={h}>{h} Std.</option>
                  ))}
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 pointer-events-none" />
              </div>
              <div className="relative flex-1">
                <select
                  value={minuten}
                  onChange={e => setMinuten(Number(e.target.value) as 0 | 30)}
                  className="w-full px-3 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 appearance-none bg-white"
                >
                  <option value={0}>0 Min.</option>
                  <option value={30}>30 Min.</option>
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 pointer-events-none" />
              </div>
            </div>
            {totalHours > 0 && (
              <p className="text-xs text-amber-600 font-medium mt-1.5">
                = {formatHours(totalHours)}
              </p>
            )}
          </div>

          {/* Datum */}
          <div>
            <label className="block text-sm font-semibold text-ink-700 mb-1.5">
              Datum
            </label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
              <input
                type="date"
                value={date}
                max={todayISO()}
                onChange={e => setDate(e.target.value)}
                className="w-full pl-9 pr-3 py-2.5 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
              />
            </div>
          </div>
        </div>

        {/* Info-Hinweis */}
        <div className="bg-amber-50 border border-amber-100 rounded-xl p-3 flex items-start gap-2">
          <AlertCircle className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">
            Der Eintrag wird als <strong>ausstehend</strong> gespeichert. Erst wenn{' '}
            {receiver
              ? <strong>{displayName(receiver)}</strong>
              : 'die andere Person'
            }{' '}
            bestätigt, werden die Stunden auf dein Zeitkonto gutgeschrieben.
          </p>
        </div>

        {/* Absenden */}
        <button
          type="submit"
          disabled={submitting || !receiver || !description.trim() || totalHours <= 0}
          className="shine w-full flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 disabled:from-stone-100 disabled:to-stone-100 disabled:text-ink-400 text-white font-semibold rounded-xl transition-all disabled:cursor-not-allowed active:scale-[0.98]"
          style={submitting || !receiver || !description.trim() || totalHours <= 0 ? undefined : { boxShadow: '0 4px 16px -4px rgba(245,158,11,0.5)' }}
        >
          {submitting
            ? <Loader2 className="w-5 h-5 animate-spin" />
            : <CheckCircle2 className="w-5 h-5" />}
          {submitting ? 'Wird eingetragen…' : 'Hilfe eintragen'}
        </button>

      </form>
    </section>
  )
}

// ── HilfeHistorie ──────────────────────────────────────────────────────────────
function HilfeHistorie({
  userId,
  refresh,
  onRefresh,
}: {
  userId: string
  refresh: number
  onRefresh: () => void
}) {
  const [entries, setEntries]   = useState<TimebankEntry[]>([])
  const [loading, setLoading]   = useState(true)
  const [actionId, setActionId] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const sb = createClient()
    const { data } = await sb
      .from('timebank_entries')
      .select(`
        *,
        giver:giver_id(id, name, nickname, avatar_url),
        receiver:receiver_id(id, name, nickname, avatar_url)
      `)
      .or(`giver_id.eq.${userId},receiver_id.eq.${userId}`)
      .order('created_at', { ascending: false })
      .limit(50)
    setEntries((data ?? []) as unknown as TimebankEntry[])
    setLoading(false)
  }, [userId])

  useEffect(() => { load() }, [load, refresh])

  // ── Realtime: Status-Änderungen sofort anzeigen ───────────────────
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`timebank-history:${userId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'timebank_entries',
      }, (payload) => {
        const e = payload.new as { giver_id: string; receiver_id: string }
        if (e.giver_id === userId || e.receiver_id === userId) load()
      })
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'timebank_entries',
      }, (payload) => {
        const e = payload.new as { giver_id: string; receiver_id: string }
        if (e.giver_id === userId || e.receiver_id === userId) load()
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [userId, load])

  const handleAction = async (entry: TimebankEntry, action: 'confirmed' | 'cancelled') => {
    setActionId(entry.id)
    const sb = createClient()
    const { error } = await sb
      .from('timebank_entries')
      .update({
        status: action,
        ...(action === 'confirmed' ? { confirmed_at: new Date().toISOString() } : {}),
      })
      .eq('id', entry.id)

    if (error) {
      toast.error('Fehler: ' + error.message)
    } else if (action === 'confirmed') {
      toast.success(`Bestätigt! ${entry.hours} Std. für ${displayName(entry.giver)} gutgeschrieben.`)
      onRefresh()
    } else {
      toast('Eintrag abgelehnt.', { icon: '🚫' })
    }
    setActionId(null)
    load()
  }

  return (
    <section className="relative bg-white rounded-2xl border border-stone-200 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{ background: 'linear-gradient(90deg, #F59E0B, #F59E0B33)' }}
      />
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-stone-100">
        <div className="flex items-center gap-2">
          <History className="w-5 h-5 text-ink-400" />
          <h2 className="font-bold text-ink-900">Meine Hilfe-Historie</h2>
        </div>
        {!loading && (
          <span className="text-xs text-ink-400 bg-stone-100 px-2 py-0.5 rounded-full">
            {entries.length} Einträge
          </span>
        )}
      </div>

      {/* Inhalt */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-6 h-6 animate-spin text-stone-400" />
        </div>
      ) : entries.length === 0 ? (
        <div className="text-center py-12 px-6">
          <Clock className="w-10 h-10 text-stone-300 mx-auto mb-3" />
          <p className="text-sm text-ink-400 font-medium">Noch keine Einträge</p>
          <p className="text-xs text-stone-400 mt-1">Trage deine erste Hilfe oben ein!</p>
        </div>
      ) : (
        <div className="divide-y divide-stone-100">
          {entries.map(entry => {
            const isGiver           = entry.giver_id === userId
            const other             = isGiver ? entry.receiver : entry.giver
            const isPendingReceived = !isGiver && entry.status === 'pending'
            const displayDateStr    = entry.help_date ?? entry.created_at

            return (
              <div key={entry.id} className="px-6 py-4">
                <div className="flex items-start gap-3">
                  <Avatar profile={other} />

                  <div className="flex-1 min-w-0">
                    {/* Kopfzeile */}
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <span className="text-sm font-semibold text-ink-900">
                        {isGiver
                          ? `Du → ${displayName(other)}`
                          : `${displayName(other)} → Du`}
                      </span>
                      <StatusBadge status={entry.status} />
                    </div>

                    {/* Beschreibung */}
                    <p className="text-sm text-ink-600 mb-2 line-clamp-2">{entry.description}</p>

                    {/* Meta */}
                    <div className="flex items-center gap-3 text-xs text-ink-400 flex-wrap">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {formatHours(entry.hours)}
                      </span>
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        {formatDate(displayDateStr)}
                      </span>
                    </div>

                    {/* Bestätigen / Ablehnen – nur bei empfangener, ausstehender Hilfe */}
                    {isPendingReceived && (
                      <div className="flex gap-2 mt-3">
                        <button
                          onClick={() => handleAction(entry, 'confirmed')}
                          disabled={actionId === entry.id}
                          className="shine flex items-center gap-1.5 px-3 py-1.5 bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-xs font-semibold rounded-lg disabled:opacity-50 transition-all shadow-glow-teal"
                        >
                          {actionId === entry.id
                            ? <Loader2 className="w-3 h-3 animate-spin" />
                            : <CheckCircle2 className="w-3 h-3" />}
                          Bestätigen
                        </button>
                        <button
                          onClick={() => handleAction(entry, 'cancelled')}
                          disabled={actionId === entry.id}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-stone-100 hover:bg-red-50 hover:text-red-600 text-ink-600 text-xs font-semibold rounded-lg disabled:opacity-50 transition-colors"
                        >
                          <XCircle className="w-3 h-3" />
                          Ablehnen
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Stunden-Indikator */}
                  <div className={`display-numeral text-right flex-shrink-0 font-bold text-base tabular-nums ${
                    entry.status === 'confirmed'
                      ? isGiver ? 'text-primary-600' : 'text-blue-600'
                      : entry.status === 'cancelled'
                        ? 'text-stone-400 line-through'
                        : 'text-amber-500'
                  }`}>
                    {isGiver ? '+' : '−'}{entry.hours}h
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}

// ── Zeitkonto ──────────────────────────────────────────────────────────────────
function Zeitkonto({ userId, refresh }: { userId: string; refresh: number }) {
  const [given, setGiven]         = useState(0)
  const [received, setReceived]   = useState(0)
  const [pending, setPending]     = useState(0)
  const [awaiting, setAwaiting]   = useState(0)
  const [community, setCommunity] = useState(0)
  const [loading, setLoading]     = useState(true)

  useEffect(() => {
    const load = async () => {
      const sb = createClient()
      const [givenRes, receivedRes, pendingRes, awaitingRes, commRes] = await Promise.all([
        sb.from('timebank_entries').select('hours').eq('giver_id', userId).eq('status', 'confirmed'),
        sb.from('timebank_entries').select('hours').eq('receiver_id', userId).eq('status', 'confirmed'),
        sb.from('timebank_entries').select('*', { count: 'exact', head: true }).eq('giver_id', userId).eq('status', 'pending'),
        sb.from('timebank_entries').select('*', { count: 'exact', head: true }).eq('receiver_id', userId).eq('status', 'pending'),
        sb.from('timebank_entries').select('hours').eq('status', 'confirmed'),
      ])

      const sum = (rows: { hours: number }[] | null) =>
        Math.round(((rows ?? []).reduce((s, r) => s + r.hours, 0)) * 10) / 10

      setGiven(sum(givenRes.data))
      setReceived(sum(receivedRes.data))
      setPending(pendingRes.count ?? 0)
      setAwaiting(awaitingRes.count ?? 0)
      setCommunity(sum(commRes.data))
      setLoading(false)
    }
    load()
  }, [userId, refresh])

  const balance = Math.round((given - received) * 10) / 10

  return (
    <section className="relative bg-white rounded-2xl border border-stone-200 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{ background: 'linear-gradient(90deg, #F59E0B, #F59E0B33)' }}
      />
      {/* Header */}
      <div className="flex items-center gap-2 px-6 py-4 border-b border-stone-100">
        <HandCoins className="w-5 h-5 text-amber-500 float-idle" />
        <h2 className="font-bold text-ink-900">Mein Zeitkonto</h2>
      </div>

      <div className="p-6 space-y-5">

        {loading ? (
          <div className="flex items-center justify-center py-6">
            <Loader2 className="w-5 h-5 animate-spin text-stone-400" />
          </div>
        ) : (
          <>
            {/* Fortschritts-Ring */}
            <div className="flex flex-col items-center gap-3 py-1">
              {(() => {
                const total = given + received
                const r = 40
                const circ = 2 * Math.PI * r
                const givenDash = total > 0 ? circ * (given / total) : 0
                return (
                  <div className="relative w-32 h-32">
                    <svg className="w-32 h-32 -rotate-90" viewBox="0 0 100 100">
                      {/* Track */}
                      <circle cx="50" cy="50" r={r} fill="none" stroke="#dbeafe" strokeWidth="12" />
                      {/* Given arc */}
                      {total > 0 && (
                        <circle
                          cx="50" cy="50" r={r} fill="none"
                          stroke="#1EAAA6" strokeWidth="12"
                          strokeDasharray={`${givenDash} ${circ}`}
                          strokeLinecap="round"
                        />
                      )}
                    </svg>
                    <div className="absolute inset-0 flex flex-col items-center justify-center">
                      <span className={`display-numeral text-2xl font-bold tabular-nums leading-none ${balance >= 0 ? 'text-amber-600' : 'text-red-500'}`}>
                        {balance >= 0 ? `+${balance}` : balance}
                      </span>
                      <span className="text-[10px] text-ink-400 uppercase tracking-wider mt-0.5">Saldo</span>
                    </div>
                  </div>
                )
              })()}
              <div className="flex items-center gap-6 text-xs text-ink-500">
                <span className="flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-primary-500 inline-block shadow-glow" />
                  <span className="display-numeral tabular-nums font-semibold text-primary-700">{given}h</span> gegeben
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-blue-200 inline-block" />
                  <span className="display-numeral tabular-nums font-semibold text-blue-500">{received}h</span> erhalten
                </span>
              </div>
            </div>

            {/* Sekundäre Kennzahlen */}
            <div className="grid grid-cols-2 gap-3">
              <div className="flex items-center gap-3 p-3 bg-stone-50 rounded-xl border border-stone-100">
                <AlertCircle className="w-4 h-4 text-amber-400 flex-shrink-0" />
                <div>
                  <p className="display-numeral text-base font-bold text-ink-900 tabular-nums">{pending}</p>
                  <p className="text-xs text-ink-400">Ausstehend</p>
                </div>
              </div>
              <div className={`flex items-center gap-3 p-3 rounded-xl border ${
                awaiting > 0
                  ? 'bg-orange-50 border-orange-100'
                  : 'bg-stone-50 border-stone-100'
              }`}>
                <Clock className={`w-4 h-4 flex-shrink-0 ${awaiting > 0 ? 'text-orange-400' : 'text-stone-400'}`} />
                <div>
                  <p className={`display-numeral text-base font-bold tabular-nums ${awaiting > 0 ? 'text-orange-600' : 'text-ink-900'}`}>
                    {awaiting}
                  </p>
                  <p className="text-xs text-ink-400">Zu bestätigen</p>
                </div>
              </div>
            </div>

            {/* Community */}
            <div className="flex items-center justify-between py-3 border-t border-stone-100">
              <div className="flex items-center gap-2">
                <Users className="w-4 h-4 text-primary-500" />
                <span className="text-sm text-ink-600">Community-Stunden gesamt</span>
              </div>
              <span className="display-numeral text-sm font-bold text-primary-600 tabular-nums">
                {community} Std.
              </span>
            </div>

            {/* So funktioniert es */}
            <div className="bg-stone-50 rounded-xl p-4">
              <p className="text-xs font-semibold text-ink-400 uppercase tracking-wide mb-3">
                So funktioniert die Zeitbank
              </p>
              <div className="space-y-2.5">
                {[
                  { n: '1', text: 'Du hilfst jemandem in deiner Nachbarschaft' },
                  { n: '2', text: 'Trage die Zeit ein – die Person bestätigt' },
                  { n: '3', text: 'Nutze dein Guthaben für Hilfe, die du brauchst' },
                ].map(s => (
                  <div key={s.n} className="flex items-start gap-2.5 text-sm text-ink-600">
                    <span className="w-5 h-5 rounded-full bg-amber-200 text-amber-800 flex items-center justify-center text-xs font-bold flex-shrink-0 mt-0.5">
                      {s.n}
                    </span>
                    <span>{s.text}</span>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </section>
  )
}

// ── TimebankPage ───────────────────────────────────────────────────────────────
export default function TimebankPage() {
  const [userId, setUserId]   = useState<string | null>(null)
  const [refresh, setRefresh] = useState(0)
  const bump = useCallback(() => setRefresh(r => r + 1), [])

  useEffect(() => {
    createClient().auth.getUser().then(({ data }) => {
      setUserId(data.user?.id ?? null)
    })
  }, [])

  return (
    <div className="max-w-3xl mx-auto px-1 py-2 space-y-8">
      {/* Editorial Header */}
      <header>
        <div className="meta-label meta-label--subtle mb-4">§ 12 / Zeit statt Geld</div>
        <div className="flex items-start gap-4">
          <div className="w-14 h-14 rounded-2xl bg-amber-50 border border-amber-100 flex items-center justify-center flex-shrink-0 float-idle">
            <Clock className="w-6 h-6 text-amber-600" />
          </div>
          <div>
            <h1 className="page-title">Zeitbank</h1>
            <p className="page-subtitle mt-2">Tausche <span className="text-accent">Zeit</span> statt Geld – Nachbarschaftshilfe auf Augenhöhe.</p>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

        {/* 1. Hilfe eintragen */}
        {userId ? (
          <HilfeForm userId={userId} onSuccess={bump} />
        ) : (
          <div className="bg-amber-50 border border-amber-200 rounded-2xl p-5 text-center">
            <p className="text-sm text-amber-700">Bitte melde dich an, um Hilfe einzutragen.</p>
          </div>
        )}

        {/* 2. Meine Hilfe-Historie */}
        {userId && (
          <HilfeHistorie userId={userId} refresh={refresh} onRefresh={bump} />
        )}

        {/* 3. Mein Zeitkonto */}
        {userId && (
          <Zeitkonto userId={userId} refresh={refresh} />
        )}

    </div>
  )
}
