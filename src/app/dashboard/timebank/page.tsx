'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Clock, Users, Star, HandCoins, BookOpen, Wrench, Heart, Leaf,
  CheckCircle2, XCircle, AlertCircle, Search, ChevronDown,
  Loader2, TrendingUp, TrendingDown, History, Plus,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Modal from '@/components/ui/Modal'
import OnboardingHint from '@/components/shared/OnboardingHint'
import toast from 'react-hot-toast'

// ── Types ──────────────────────────────────────────────────────
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
  giver: Profile
  receiver: Profile
}

// ── Kategorie-Optionen ─────────────────────────────────────────
const ENTRY_CATEGORIES = [
  { value: 'general',   label: '🌿 Garten & Natur'           },
  { value: 'skills',    label: '🔧 Handwerk & Reparatur'      },
  { value: 'knowledge', label: '📚 Nachhilfe & Lernen'        },
  { value: 'mental',    label: '💙 Pflege & Fürsorge'         },
  { value: 'everyday',  label: '🏠 Alltag & Haushalt'         },
  { value: 'food',      label: '🍎 Einkaufen & Versorgung'    },
  { value: 'mobility',  label: '🚗 Transport & Mobilität'     },
  { value: 'sharing',   label: '🔄 Teilen & Helfen'           },
]

// Hilfsfunktion: Initialbuchstabe für Avatar
function initials(p: Profile | null) {
  return ((p?.name ?? p?.nickname ?? '?')[0] ?? '?').toUpperCase()
}

// ── "Hilfe eintragen" Modal ────────────────────────────────────
function LogHelpModal({
  open,
  onClose,
  userId,
  onSuccess,
}: {
  open: boolean
  onClose: () => void
  userId: string
  onSuccess: () => void
}) {
  const [description, setDescription]         = useState('')
  const [category, setCategory]               = useState('general')
  const [hours, setHours]                     = useState(1)
  const [searchQuery, setSearchQuery]         = useState('')
  const [searchResults, setSearchResults]     = useState<Profile[]>([])
  const [selectedReceiver, setSelectedReceiver] = useState<Profile | null>(null)
  const [searching, setSearching]             = useState(false)
  const [submitting, setSubmitting]           = useState(false)

  // Empfänger suchen (debounced)
  useEffect(() => {
    if (searchQuery.length < 2) { setSearchResults([]); return }
    const timer = setTimeout(async () => {
      setSearching(true)
      const supabase = createClient()
      const { data } = await supabase
        .from('profiles')
        .select('id, name, nickname, avatar_url')
        .neq('id', userId)
        .or(`name.ilike.%${searchQuery}%,nickname.ilike.%${searchQuery}%`)
        .limit(6)
      setSearchResults((data ?? []) as Profile[])
      setSearching(false)
    }, 300)
    return () => clearTimeout(timer)
  }, [searchQuery, userId])

  const reset = () => {
    setDescription('')
    setCategory('general')
    setHours(1)
    setSearchQuery('')
    setSearchResults([])
    setSelectedReceiver(null)
  }

  const handleClose = () => { reset(); onClose() }

  const handleSubmit = async () => {
    if (!description.trim()) {
      toast.error('Bitte beschreibe die geleistete Hilfe')
      return
    }
    if (!selectedReceiver) {
      toast.error('Bitte wähle die Person aus, der du geholfen hast')
      return
    }

    setSubmitting(true)
    const supabase = createClient()
    const { error } = await supabase.from('timebank_entries').insert({
      giver_id:    userId,
      receiver_id: selectedReceiver.id,
      hours,
      description: description.trim(),
      category,
      status: 'pending',
    })

    if (error) {
      toast.error('Fehler beim Speichern: ' + error.message)
    } else {
      const name = selectedReceiver.name ?? selectedReceiver.nickname ?? 'die Person'
      toast.success(
        `✅ ${hours} Stunde${hours !== 1 ? 'n' : ''} eingetragen!\n${name} muss noch bestätigen.`
      )
      reset()
      onSuccess()
      onClose()
    }
    setSubmitting(false)
  }

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title="Hilfe eintragen"
      description="Trage die Hilfe ein, die du geleistet hast. Die andere Person muss bestätigen, damit die Stunden gutgeschrieben werden."
      size="md"
      footer={
        <>
          <button
            onClick={handleClose}
            className="px-4 py-2 text-sm text-gray-600 hover:text-gray-900 transition-colors"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting || !selectedReceiver || !description.trim()}
            className="px-5 py-2 bg-amber-500 hover:bg-amber-600 text-white text-sm font-semibold rounded-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 transition-colors"
          >
            {submitting
              ? <Loader2 className="w-4 h-4 animate-spin" />
              : <CheckCircle2 className="w-4 h-4" />}
            Eintragen
          </button>
        </>
      }
    >
      <div className="space-y-4">

        {/* 1. Empfänger suchen */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Wer wurde geholfen? *
          </label>

          {selectedReceiver ? (
            <div className="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-xl">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-amber-200 flex items-center justify-center text-amber-800 font-bold text-sm">
                  {initials(selectedReceiver)}
                </div>
                <div>
                  <p className="text-sm font-semibold text-gray-900">
                    {selectedReceiver.name ?? selectedReceiver.nickname}
                  </p>
                  {selectedReceiver.nickname && (
                    <p className="text-xs text-gray-500">@{selectedReceiver.nickname}</p>
                  )}
                </div>
              </div>
              <button
                onClick={() => { setSelectedReceiver(null); setSearchQuery('') }}
                className="text-xs text-gray-400 hover:text-red-500 transition-colors"
              >
                Ändern
              </button>
            </div>
          ) : (
            <div className="relative">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  placeholder="Name oder Nickname eingeben…"
                  className="w-full pl-9 pr-9 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
                />
                {searching && (
                  <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-gray-400" />
                )}
              </div>
              {searchResults.length > 0 && (
                <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden">
                  {searchResults.map(profile => (
                    <button
                      key={profile.id}
                      onClick={() => {
                        setSelectedReceiver(profile)
                        setSearchQuery('')
                        setSearchResults([])
                      }}
                      className="w-full flex items-center gap-2 px-3 py-2.5 hover:bg-amber-50 transition-colors text-left"
                    >
                      <div className="w-8 h-8 rounded-full bg-amber-200 flex items-center justify-center text-amber-800 font-bold text-sm flex-shrink-0">
                        {initials(profile)}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">
                          {profile.name ?? profile.nickname}
                        </p>
                        {profile.nickname && (
                          <p className="text-xs text-gray-500">@{profile.nickname}</p>
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* 2. Beschreibung */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Was hast du gemacht? *
          </label>
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="z.B. Garten umgegraben, Einkauf erledigt, Möbel getragen, Nachhilfe gegeben…"
            rows={3}
            maxLength={300}
            className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 resize-none"
          />
          <p className="text-xs text-gray-400 mt-1 text-right">{description.length}/300</p>
        </div>

        {/* 3. Kategorie */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Kategorie</label>
          <div className="relative">
            <select
              value={category}
              onChange={e => setCategory(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 appearance-none bg-white"
            >
              {ENTRY_CATEGORIES.map(c => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
            <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
          </div>
        </div>

        {/* 4. Stunden (Slider) */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Geleistete Zeit:{' '}
            <span className="text-amber-600 font-bold">
              {hours === 0.5 ? '30 Minuten' : `${hours} Stunde${hours !== 1 ? 'n' : ''}`}
            </span>
          </label>
          <input
            type="range"
            min={0.5}
            max={8}
            step={0.5}
            value={hours}
            onChange={e => setHours(parseFloat(e.target.value))}
            className="w-full accent-amber-500"
          />
          <div className="flex justify-between text-xs text-gray-400 mt-1">
            <span>30 Min</span>
            <span>2 Std</span>
            <span>4 Std</span>
            <span>6 Std</span>
            <span>8 Std</span>
          </div>
        </div>

        {/* Info-Box */}
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex items-start gap-2">
          <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-800">
            Der Eintrag wird als <strong>ausstehend</strong> gespeichert. Erst wenn{' '}
            <strong>{selectedReceiver?.name ?? selectedReceiver?.nickname ?? 'die andere Person'}</strong>{' '}
            bestätigt, werden die Stunden auf dein Zeitkonto gutgeschrieben.
          </p>
        </div>

      </div>
    </Modal>
  )
}

// ── Zeitkonto-Widget (mit echten Daten aus timebank_entries) ───
function TimebankWidget({
  userId,
  refresh,
  onLogHelp,
}: {
  userId: string | null
  refresh: number
  onLogHelp: () => void
}) {
  const [given, setGiven]       = useState(0)  // bestätigte Stunden als Geber
  const [received, setReceived] = useState(0)  // bestätigte Stunden als Empfänger
  const [pending, setPending]   = useState(0)  // eigene ausstehende (noch nicht bestätigt)
  const [awaiting, setAwaiting] = useState(0)  // andere müssen ich bestätigen
  const [communityHours, setCommunityHours] = useState(0)

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()

      // Community-Gesamtstunden (bestätigt)
      const { data: allConfirmed } = await supabase
        .from('timebank_entries')
        .select('hours')
        .eq('status', 'confirmed')
      setCommunityHours(
        Math.round((allConfirmed ?? []).reduce((s, e) => s + (e.hours ?? 0), 0) * 10) / 10
      )

      if (!userId) return

      // Meine gegebenen bestätigten Stunden
      const { data: givenData } = await supabase
        .from('timebank_entries')
        .select('hours')
        .eq('giver_id', userId)
        .eq('status', 'confirmed')
      setGiven(
        Math.round((givenData ?? []).reduce((s, e) => s + (e.hours ?? 0), 0) * 10) / 10
      )

      // Meine erhaltenen bestätigten Stunden
      const { data: receivedData } = await supabase
        .from('timebank_entries')
        .select('hours')
        .eq('receiver_id', userId)
        .eq('status', 'confirmed')
      setReceived(
        Math.round((receivedData ?? []).reduce((s, e) => s + (e.hours ?? 0), 0) * 10) / 10
      )

      // Meine ausstehenden Einträge (ich habe geholfen, warte auf Bestätigung)
      const { count: pendingCount } = await supabase
        .from('timebank_entries')
        .select('*', { count: 'exact', head: true })
        .eq('giver_id', userId)
        .eq('status', 'pending')
      setPending(pendingCount ?? 0)

      // Einträge, die ich bestätigen muss (jemand hat mir geholfen)
      const { count: awaitingCount } = await supabase
        .from('timebank_entries')
        .select('*', { count: 'exact', head: true })
        .eq('receiver_id', userId)
        .eq('status', 'pending')
      setAwaiting(awaitingCount ?? 0)
    }
    load()
  }, [userId, refresh])

  const balance = Math.round((given - received) * 10) / 10

  return (
    <div className="bg-gradient-to-br from-amber-50 to-yellow-50 border border-amber-200 rounded-2xl p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <HandCoins className="w-5 h-5 text-amber-600" />
          <h3 className="font-bold text-amber-900">Dein Zeitkonto</h3>
        </div>
        {userId && (
          <button
            onClick={onLogHelp}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-500 hover:bg-amber-600 text-white text-xs font-semibold rounded-lg transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            Hilfe eintragen
          </button>
        )}
      </div>

      {/* Drei Kennzahlen */}
      <div className="grid grid-cols-3 gap-3 mb-4">
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <div className="flex items-center justify-center gap-1 mb-0.5">
            <TrendingUp className="w-3.5 h-3.5 text-green-500" />
            <p className="text-xl font-bold text-green-600">{given}</p>
          </div>
          <p className="text-xs text-gray-500 leading-tight">Std. gegeben</p>
        </div>
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <p className={`text-xl font-bold ${balance >= 0 ? 'text-amber-600' : 'text-red-500'}`}>
            {balance >= 0 ? `+${balance}` : balance}
          </p>
          <p className="text-xs text-gray-500 leading-tight">Saldo Std.</p>
        </div>
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <div className="flex items-center justify-center gap-1 mb-0.5">
            <TrendingDown className="w-3.5 h-3.5 text-blue-400" />
            <p className="text-xl font-bold text-blue-500">{received}</p>
          </div>
          <p className="text-xs text-gray-500 leading-tight">Std. erhalten</p>
        </div>
      </div>

      {/* Status-Badges */}
      {(pending > 0 || awaiting > 0) && (
        <div className="flex flex-wrap gap-2 mb-4">
          {pending > 0 && (
            <span className="flex items-center gap-1 text-xs bg-amber-100 text-amber-700 px-2.5 py-1 rounded-full font-medium">
              <Clock className="w-3 h-3" />
              {pending} ausstehend
            </span>
          )}
          {awaiting > 0 && (
            <span className="flex items-center gap-1 text-xs bg-orange-100 text-orange-700 px-2.5 py-1 rounded-full font-medium animate-pulse">
              <AlertCircle className="w-3 h-3" />
              {awaiting} zu bestätigen
            </span>
          )}
        </div>
      )}

      {/* Erklärung */}
      <div className="space-y-2">
        <p className="text-xs font-semibold text-amber-800 uppercase tracking-wide">So funktioniert es</p>
        {[
          { n: '1', text: 'Hilf jemandem in deiner Nachbarschaft' },
          { n: '2', text: 'Trage die Zeit ein – die Person bestätigt' },
          { n: '3', text: 'Tausche dein Guthaben gegen Hilfe, die du brauchst' },
        ].map(step => (
          <div key={step.n} className="flex items-start gap-2 text-sm text-amber-900">
            <span className="w-5 h-5 rounded-full bg-amber-200 text-amber-800 flex items-center justify-center text-xs font-bold flex-shrink-0">
              {step.n}
            </span>
            <span>{step.text}</span>
          </div>
        ))}
      </div>

      <div className="mt-4 pt-3 border-t border-amber-200 text-center">
        <p className="text-xs text-amber-700">
          <span className="font-bold text-amber-800">{communityHours}</span> Community-Stunden bestätigt
        </p>
      </div>
    </div>
  )
}

// ── Ausstehende Bestätigungen ──────────────────────────────────
function PendingConfirmations({
  userId,
  onRefresh,
}: {
  userId: string
  onRefresh: () => void
}) {
  const [entries, setEntries]   = useState<TimebankEntry[]>([])
  const [loading, setLoading]   = useState(true)
  const [actionId, setActionId] = useState<string | null>(null)

  const load = useCallback(async () => {
    const supabase = createClient()
    const { data } = await supabase
      .from('timebank_entries')
      .select(`
        *,
        giver:giver_id(id, name, nickname, avatar_url),
        receiver:receiver_id(id, name, nickname, avatar_url)
      `)
      .eq('receiver_id', userId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
    setEntries((data ?? []) as unknown as TimebankEntry[])
    setLoading(false)
  }, [userId])

  useEffect(() => { load() }, [load])

  const handleAction = async (entry: TimebankEntry, action: 'confirmed' | 'cancelled') => {
    setActionId(entry.id)
    const supabase = createClient()
    const { error } = await supabase
      .from('timebank_entries')
      .update({
        status: action,
        ...(action === 'confirmed' ? { confirmed_at: new Date().toISOString() } : {}),
      })
      .eq('id', entry.id)

    if (error) {
      toast.error('Fehler: ' + error.message)
    } else {
      const giverName = entry.giver?.name ?? entry.giver?.nickname ?? 'Person'
      if (action === 'confirmed') {
        toast.success(`✅ Bestätigt! ${entry.hours} Std. für ${giverName} gutgeschrieben.`)
      } else {
        toast('Eintrag abgelehnt.', { icon: '🚫' })
      }
      onRefresh()
      load()
    }
    setActionId(null)
  }

  if (loading || entries.length === 0) return null

  return (
    <div className="bg-white border border-orange-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-1">
        <AlertCircle className="w-5 h-5 text-orange-500" />
        <h3 className="font-bold text-gray-900">Ausstehende Bestätigungen</h3>
        <span className="ml-auto text-xs bg-orange-100 text-orange-700 px-2 py-0.5 rounded-full font-medium">
          {entries.length}
        </span>
      </div>
      <p className="text-xs text-gray-500 mb-4">
        Jemand hat eingetragen, dass er dir geholfen hat. Bitte bestätige, ob das stimmt.
      </p>
      <div className="space-y-3">
        {entries.map(entry => (
          <div key={entry.id} className="border border-gray-100 rounded-xl p-3 bg-gray-50">
            <div className="flex items-start justify-between gap-2 mb-2">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-amber-200 flex items-center justify-center text-amber-800 font-bold text-sm flex-shrink-0">
                  {initials(entry.giver)}
                </div>
                <div>
                  <p className="text-sm font-semibold text-gray-900">
                    {entry.giver?.name ?? entry.giver?.nickname ?? 'Unbekannt'}
                  </p>
                  <p className="text-xs text-gray-400">
                    {new Date(entry.created_at).toLocaleDateString('de-AT', {
                      day: '2-digit', month: '2-digit', year: 'numeric',
                    })}
                  </p>
                </div>
              </div>
              <span className="text-sm font-bold text-amber-600 flex-shrink-0">
                {entry.hours} Std.
              </span>
            </div>
            <p className="text-sm text-gray-700 mb-3 italic">"{entry.description}"</p>
            <div className="flex gap-2">
              <button
                onClick={() => handleAction(entry, 'confirmed')}
                disabled={actionId === entry.id}
                className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 bg-green-500 hover:bg-green-600 text-white text-sm font-semibold rounded-lg disabled:opacity-50 transition-colors"
              >
                {actionId === entry.id
                  ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  : <CheckCircle2 className="w-3.5 h-3.5" />}
                Bestätigen
              </button>
              <button
                onClick={() => handleAction(entry, 'cancelled')}
                disabled={actionId === entry.id}
                className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 bg-gray-100 hover:bg-red-50 hover:text-red-600 text-gray-600 text-sm font-semibold rounded-lg disabled:opacity-50 transition-colors"
              >
                <XCircle className="w-3.5 h-3.5" />
                Ablehnen
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ── Meine Zeiteinträge (Verlauf) ───────────────────────────────
function RecentEntries({ userId, refresh }: { userId: string; refresh: number }) {
  const [entries, setEntries] = useState<TimebankEntry[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()
      const { data } = await supabase
        .from('timebank_entries')
        .select(`
          *,
          giver:giver_id(id, name, nickname, avatar_url),
          receiver:receiver_id(id, name, nickname, avatar_url)
        `)
        .or(`giver_id.eq.${userId},receiver_id.eq.${userId}`)
        .in('status', ['confirmed', 'pending'])
        .order('created_at', { ascending: false })
        .limit(8)
      setEntries((data ?? []) as unknown as TimebankEntry[])
      setLoading(false)
    }
    load()
  }, [userId, refresh])

  if (loading) {
    return (
      <div className="bg-white border border-gray-200 rounded-2xl p-5">
        <div className="flex items-center gap-2 mb-3">
          <History className="w-5 h-5 text-gray-400" />
          <h3 className="font-bold text-gray-900">Meine Zeiteinträge</h3>
        </div>
        <p className="text-sm text-gray-400 text-center py-4">Lädt…</p>
      </div>
    )
  }

  if (entries.length === 0) {
    return (
      <div className="bg-white border border-gray-200 rounded-2xl p-5">
        <div className="flex items-center gap-2 mb-3">
          <History className="w-5 h-5 text-gray-400" />
          <h3 className="font-bold text-gray-900">Meine Zeiteinträge</h3>
        </div>
        <p className="text-sm text-gray-500 text-center py-4">
          Noch keine Einträge – trage deine erste geleistete Hilfe ein!
        </p>
      </div>
    )
  }

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-3">
        <History className="w-5 h-5 text-gray-500" />
        <h3 className="font-bold text-gray-900">Meine Zeiteinträge</h3>
      </div>
      <div className="space-y-2">
        {entries.map(entry => {
          const isGiver   = entry.giver_id === userId
          const other     = isGiver ? entry.receiver : entry.giver
          const confirmed = entry.status === 'confirmed'
          return (
            <div
              key={entry.id}
              className={`flex items-center gap-3 p-3 rounded-xl border ${
                confirmed
                  ? isGiver
                    ? 'bg-green-50 border-green-100'
                    : 'bg-blue-50 border-blue-100'
                  : 'bg-gray-50 border-gray-100'
              }`}
            >
              <div className="w-8 h-8 rounded-full bg-amber-200 flex items-center justify-center text-amber-800 font-bold text-sm flex-shrink-0">
                {initials(other)}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs text-gray-500 mb-0.5">
                  {isGiver
                    ? `Du hast geholfen → ${other?.name ?? other?.nickname ?? 'Unbekannt'}`
                    : `${other?.name ?? other?.nickname ?? 'Unbekannt'} hat dir geholfen`}
                </p>
                <p className="text-sm font-medium text-gray-800 truncate">{entry.description}</p>
              </div>
              <div className="text-right flex-shrink-0">
                <p className={`text-sm font-bold ${
                  confirmed
                    ? isGiver ? 'text-green-600' : 'text-blue-600'
                    : 'text-gray-400'
                }`}>
                  {isGiver ? '+' : '-'}{entry.hours}h
                </p>
                <p className="text-xs text-gray-400">
                  {confirmed ? 'bestätigt' : 'ausstehend'}
                </p>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ── Kategorien-Widget ────────────────────────────────────────
const TIME_CATEGORIES = [
  { icon: <Wrench className="w-5 h-5" />,   label: 'Handwerk & Reparatur', category: 'skills',    color: 'bg-orange-100 text-orange-700 border-orange-200 hover:bg-orange-200' },
  { icon: <Leaf className="w-5 h-5" />,     label: 'Garten & Natur',       category: 'general',   color: 'bg-green-100 text-green-700 border-green-200 hover:bg-green-200'   },
  { icon: <BookOpen className="w-5 h-5" />, label: 'Nachhilfe & Lernen',   category: 'knowledge', color: 'bg-blue-100 text-blue-700 border-blue-200 hover:bg-blue-200'       },
  { icon: <Heart className="w-5 h-5" />,    label: 'Pflege & Fürsorge',    category: 'mental',    color: 'bg-pink-100 text-pink-700 border-pink-200 hover:bg-pink-200'       },
  { icon: <Users className="w-5 h-5" />,    label: 'Gemeinschaft',         category: 'community', color: 'bg-violet-100 text-violet-700 border-violet-200 hover:bg-violet-200' },
  { icon: <Star className="w-5 h-5" />,     label: 'Kreatives & Kunst',    category: 'general',   color: 'bg-yellow-100 text-yellow-700 border-yellow-200 hover:bg-yellow-200' },
]

function SkillCategoriesWidget({
  activeCategory,
  onFilter,
}: {
  activeCategory: string
  onFilter: (cat: string) => void
}) {
  return (
    <div className="bg-white border border-warm-200 rounded-2xl p-5">
      <h3 className="font-bold text-gray-900 mb-1 flex items-center gap-2">
        <Clock className="w-5 h-5 text-primary-600" />
        Was kannst du anbieten?
      </h3>
      <p className="text-xs text-gray-400 mb-3">Klicke auf eine Kategorie, um die Liste zu filtern</p>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
        {TIME_CATEGORIES.map((cat, i) => (
          <button
            key={i}
            onClick={() => onFilter(activeCategory === cat.category ? '' : cat.category)}
            className={`flex items-center gap-2 p-3 rounded-xl border text-sm font-medium transition-all hover:scale-105 ${cat.color} ${
              activeCategory === cat.category ? 'ring-2 ring-offset-1 ring-primary-400' : ''
            }`}
          >
            {cat.icon}
            <span className="text-left leading-tight">{cat.label}</span>
          </button>
        ))}
      </div>
      {activeCategory && (
        <button
          onClick={() => onFilter('')}
          className="mt-2 text-xs text-primary-600 hover:underline w-full text-center"
        >
          Filter zurücksetzen
        </button>
      )}
    </div>
  )
}

// ── Haupt-Export ───────────────────────────────────────────────
export default function TimebankPage() {
  const [activeCategory, setActiveCategory] = useState('')
  const [showLogModal, setShowLogModal]     = useState(false)
  const [userId, setUserId]                 = useState<string | null>(null)
  const [refresh, setRefresh]               = useState(0)
  const [awaitingBanner, setAwaitingBanner] = useState(0)

  useEffect(() => {
    createClient().auth.getUser().then(({ data }) => {
      setUserId(data.user?.id ?? null)
    })
  }, [])

  useEffect(() => {
    if (!userId) return
    createClient()
      .from('timebank_entries')
      .select('*', { count: 'exact', head: true })
      .eq('receiver_id', userId)
      .eq('status', 'pending')
      .then(({ count }) => setAwaitingBanner(count ?? 0))
  }, [userId, refresh])

  const handleRefresh = useCallback(() => setRefresh(r => r + 1), [])

  return (
    <>
      <ModulePage
        title="Zeitbank"
        description="Tausche Zeit statt Geld – biete Stunden an, verdiene Gutschriften, baue Gemeinschaft auf"
        icon={<Clock className="w-6 h-6 text-white" />}
        color="bg-gradient-to-r from-amber-500 to-yellow-600"
        postTypes={['sharing', 'rescue', 'community']}
        moduleFilter={[
          { type: 'sharing',   categories: ['skills', 'knowledge', 'mental'] },
          { type: 'rescue',    categories: ['skills', 'knowledge', 'mental'] },
          { type: 'community', categories: ['skills', 'knowledge', 'mental'] },
        ]}
        createTypes={[
          { value: 'sharing',   label: '⏰ Stunde anbieten' },
          { value: 'rescue',    label: '🔴 Hilfe benötigt'  },
          { value: 'community', label: '⭐ Skill eintragen'  },
        ]}
        categories={[
          { value: 'skills',    label: '🔧 Handwerk'  },
          { value: 'knowledge', label: '📚 Nachhilfe' },
          { value: 'mental',    label: '💙 Fürsorge'  },
        ]}
        emptyText="Noch keine Zeitbank-Einträge – sei der Erste!"
        filterCategory={activeCategory}
      >
        {/* Hauptbereich – oberhalb des Post-Feeds */}
        <div className="space-y-4">

          {/* Pending confirmation banner */}
          {awaitingBanner > 0 && (
            <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 flex items-center gap-3 animate-slide-down">
              <AlertCircle className="w-5 h-5 text-amber-500 flex-shrink-0" />
              <p className="text-sm text-amber-700 flex-1">
                Du hast <strong>{awaitingBanner}</strong> unbestätigte Stunde{awaitingBanner !== 1 ? 'n' : ''} – bitte bestätige oder lehne ab.
              </p>
            </div>
          )}

          {/* Onboarding – nur beim ersten Besuch */}
          <OnboardingHint
            storageKey="zeitbank"
            title="So funktioniert die Zeitbank"
            accentColor="amber"
            steps={[
              { icon: '🤝', title: 'Hilf jemandem', text: 'Leiste Hilfe in der Nachbarschaft' },
              { icon: '⏱️', title: 'Stunden eintragen', text: 'Trage die Zeit ein – Person bestätigt' },
              { icon: '🔄', title: 'Tausche Guthaben', text: 'Nutze dein Zeitguthaben für eigene Hilfe' },
            ]}
          />

          {/* "Hilfe eintragen" – prominenter CTA */}
          {userId && (
            <button
              onClick={() => setShowLogModal(true)}
              className="w-full flex items-center justify-center gap-2 py-3.5 bg-amber-500 hover:bg-amber-600 text-white font-semibold rounded-2xl shadow-sm transition-colors"
            >
              <Plus className="w-5 h-5" />
              Geleistete Hilfe eintragen
            </button>
          )}

          {/* Zeitkonto + Kategorien */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <TimebankWidget
              userId={userId}
              refresh={refresh}
              onLogHelp={() => setShowLogModal(true)}
            />
            <SkillCategoriesWidget activeCategory={activeCategory} onFilter={setActiveCategory} />
          </div>

          {/* Ausstehende Bestätigungen */}
          {userId && (
            <PendingConfirmations userId={userId} onRefresh={handleRefresh} />
          )}

          {/* Mein Verlauf */}
          {userId && (
            <RecentEntries userId={userId} refresh={refresh} />
          )}

        </div>
      </ModulePage>

      {/* Log-Help Modal */}
      {userId && (
        <LogHelpModal
          open={showLogModal}
          onClose={() => setShowLogModal(false)}
          userId={userId}
          onSuccess={handleRefresh}
        />
      )}
    </>
  )
}
