'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import {
  Heart, Coffee, Users, Shield, ArrowLeft,
  CreditCard, Building2, Star, Sparkles, Copy, Check, Mail, Loader2,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

const AMOUNTS = [1, 3, 5, 10]

const TIERS = [
  {
    icon: Coffee,
    amount: 1,
    label: 'Kaffee',
    description: 'Danke! Ein symbolischer Start.',
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-200',
    highlight: false,
  },
  {
    icon: Heart,
    amount: 3,
    label: 'Nachbar:in',
    description: 'Push-Benachrichtigungen für 60 Nutzer',
    color: 'text-primary-600',
    bg: 'bg-primary-50',
    border: 'border-primary-200',
    highlight: true,
  },
  {
    icon: Star,
    amount: 5,
    label: 'Held:in',
    description: 'Ein Monat Chat-Server',
    color: 'text-violet-600',
    bg: 'bg-violet-50',
    border: 'border-violet-200',
    highlight: false,
  },
  {
    icon: Sparkles,
    amount: 10,
    label: 'Botschafter:in',
    description: 'Einen Monat Kartenservice',
    color: 'text-rose-600',
    bg: 'bg-rose-50',
    border: 'border-rose-200',
    highlight: false,
  },
]

const COSTS = [
  { label: 'Server & Infrastruktur', value: '~30 €/Monat', icon: Shield },
  { label: 'Domain & SSL', value: '~15 €/Jahr', icon: CreditCard },
  { label: 'SMS-Verifikation', value: '~0,05 €/Nutzer', icon: Users },
  { label: 'Entwicklung', value: 'ehrenamtlich', icon: Heart },
]

const IBAN = 'DE79 1001 0178 6303 9229 28'
const BIC  = 'REVODEB2'

// ── Spendenbescheinigung auf Anfrage ─────────────────────────
function ReceiptRequestPanel() {
  const [name, setName]     = useState('')
  const [email, setEmail]   = useState('')
  const [amount, setAmount] = useState('')
  const [date, setDate]     = useState(() => new Date().toISOString().slice(0, 10))
  const [address, setAddress] = useState('')
  const [sending, setSending] = useState(false)
  const [sent, setSent]     = useState(false)
  const [err, setErr]       = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim() || !email.trim() || !amount) return
    setSending(true)
    setErr(null)
    try {
      const supabase = createClient()
      const { data: { session } } = await supabase.auth.getSession()
      const res = await fetch('/api/emails/donation-receipt', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {}),
        },
        body: JSON.stringify({
          donorName: name.trim(),
          donorEmail: email.trim(),
          amount: parseFloat(amount),
          donationDate: date,
          donorAddress: address.trim() || undefined,
        }),
      })
      if (!res.ok) {
        const j = await res.json().catch(() => ({}))
        throw new Error(j.error || `HTTP ${res.status}`)
      }
      setSent(true)
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Unbekannter Fehler')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="bg-white rounded-3xl border border-gray-100 shadow-soft p-6 space-y-4">
      <h2 className="font-semibold text-gray-900 flex items-center gap-2">
        <Mail className="w-4 h-4 text-gray-400" />
        Spendenbescheinigung anfordern
      </h2>
      <p className="text-xs text-gray-500 leading-relaxed">
        Du hast gespendet und möchtest eine Bescheinigung? Fülle das Formular aus – wir senden dir per E-Mail eine Bestätigung.
      </p>

      {sent ? (
        <div className="flex flex-col items-center gap-3 py-4 text-center">
          <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center">
            <Check className="w-6 h-6 text-green-600" />
          </div>
          <p className="text-sm font-semibold text-gray-900">Bescheinigung wurde versendet!</p>
          <p className="text-xs text-gray-500">Bitte prüfe dein Postfach (auch Spam).</p>
          <button onClick={() => { setSent(false); setName(''); setEmail(''); setAmount(''); setAddress('') }}
            className="text-xs text-primary-600 hover:underline mt-1">
            Weitere Anfrage stellen
          </button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Name *</label>
              <input value={name} onChange={e => setName(e.target.value)} className="input" placeholder="Max Mustermann" required />
            </div>
            <div>
              <label className="label">E-Mail *</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} className="input" placeholder="max@beispiel.de" required />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Betrag (€) *</label>
              <input type="number" min="0.01" step="0.01" value={amount} onChange={e => setAmount(e.target.value)} className="input" placeholder="5.00" required />
            </div>
            <div>
              <label className="label">Spendedatum *</label>
              <input type="date" value={date} onChange={e => setDate(e.target.value)} className="input" required />
            </div>
          </div>
          <div>
            <label className="label">Adresse <span className="font-normal text-gray-400">(optional)</span></label>
            <textarea value={address} onChange={e => setAddress(e.target.value)} rows={2} className="input resize-none" placeholder="Straße, PLZ, Ort" />
          </div>
          {err && <p className="text-xs text-red-600 bg-red-50 rounded-lg px-3 py-2">{err}</p>}
          <button type="submit" disabled={sending || !name.trim() || !email.trim() || !amount}
            className="btn-primary w-full disabled:opacity-50 disabled:pointer-events-none flex items-center justify-center gap-2">
            {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Mail className="w-4 h-4" />}
            Bescheinigung anfordern
          </button>
          <p className="text-[11px] text-gray-400 text-center">
            Die Bescheinigung dient als Zahlungsnachweis. Steuerliche Absetzbarkeit derzeit nicht möglich (keine eingetragene Gemeinnützigkeit).
          </p>
        </form>
      )}
    </div>
  )
}

export default function SpendenPage() {
  const [userCount, setUserCount] = useState<number | null>(null)
  const [selectedAmount, setSelectedAmount] = useState<number>(3)
  const [customAmount, setCustomAmount] = useState('')
  const [isCustom, setIsCustom] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .then(({ count }) => {
        if (count !== null) setUserCount(count)
      })
  }, [])

  const costPerPerson =
    userCount && userCount > 0 ? (30 / userCount).toFixed(2) : null

  const finalAmount = isCustom
    ? parseFloat(customAmount) || 0
    : selectedAmount

  const handleCopyIBAN = async () => {
    try {
      await navigator.clipboard.writeText(IBAN.replace(/\s/g, ''))
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  return (
    <div className="min-h-screen bg-[#EEF9F9]">
      <div className="max-w-xl mx-auto px-4 py-8 space-y-6">

        {/* Back link */}
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück
        </Link>

        {/* Hero Header */}
        <div className="relative overflow-hidden bg-gradient-to-br from-primary-600 via-primary-500 to-teal-500 rounded-3xl px-6 pt-8 pb-10 text-center text-white shadow-glow-teal">
          <div className="absolute inset-0 bg-noise opacity-10 pointer-events-none" />
          <div className="absolute -top-6 -right-6 w-32 h-32 rounded-full bg-white/10 blur-2xl pointer-events-none" />
          <div className="absolute -bottom-8 -left-8 w-40 h-40 rounded-full bg-teal-300/20 blur-3xl pointer-events-none" />

          <div className="relative">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-white/20 backdrop-blur-sm border border-white/30 mb-4">
              <Heart className="w-8 h-8 text-white fill-white/30" />
            </div>
            <h1 className="text-2xl font-bold mb-2">Mensaena unterstützen</h1>
            <p className="text-white/80 text-sm leading-relaxed max-w-xs mx-auto">
              100&nbsp;% gemeinnützig · 0&nbsp;% Werbung<br />
              Deine Spende hält uns am Laufen.
            </p>

            {costPerPerson && userCount && (
              <div className="mt-4 inline-block bg-white/20 backdrop-blur-sm border border-white/30 rounded-xl px-4 py-2 text-xs text-white/90">
                Bei <strong>{userCount.toLocaleString('de-DE')}</strong> Nachbar:innen = nur{' '}
                <strong>{costPerPerson}&nbsp;€</strong> pro Person/Monat
              </div>
            )}
          </div>
        </div>

        {/* Amount Picker */}
        <div className="bg-white rounded-3xl border border-gray-100 shadow-soft p-6 space-y-5">
          <h2 className="font-semibold text-gray-900">Betrag wählen</h2>

          {/* Quick amounts */}
          <div className="grid grid-cols-4 gap-2">
            {AMOUNTS.map(amt => (
              <button
                key={amt}
                onClick={() => { setSelectedAmount(amt); setIsCustom(false) }}
                className={cn(
                  'py-3 rounded-2xl text-sm font-bold transition-all border',
                  !isCustom && selectedAmount === amt
                    ? 'bg-primary-500 text-white border-primary-500 shadow-glow-teal scale-105'
                    : 'bg-gray-50 text-gray-700 border-gray-200 hover:border-primary-300 hover:bg-primary-50',
                )}
              >
                {amt}&nbsp;€
              </button>
            ))}
          </div>

          {/* Custom amount */}
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1.5 block">
              Eigener Betrag
            </label>
            <div className="relative">
              <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 font-semibold text-sm">€</span>
              <input
                type="number"
                min="0.50"
                step="0.50"
                value={customAmount}
                placeholder="z.B. 7,50"
                onChange={e => {
                  setCustomAmount(e.target.value)
                  setIsCustom(true)
                }}
                onFocus={() => setIsCustom(true)}
                className={cn(
                  'input pl-8 transition-all',
                  isCustom && 'border-primary-400 ring-2 ring-primary-100',
                )}
              />
            </div>
          </div>

          {/* PayPal – vorübergehend deaktiviert */}
        </div>

        {/* Spenden-Stufen */}
        <div className="space-y-3">
          <h2 className="font-semibold text-gray-900 px-1">Was deine Spende bewirkt</h2>
          <div className="grid grid-cols-2 gap-3">
            {TIERS.map(({ icon: Icon, amount, label, description, color, bg, border, highlight }) => (
              <button
                key={label}
                onClick={() => { setSelectedAmount(amount); setIsCustom(false) }}
                className={cn(
                  'rounded-2xl border p-4 text-left space-y-2 transition-all',
                  bg, border,
                  highlight && 'ring-2 ring-primary-300',
                  !isCustom && selectedAmount === amount && 'ring-2 ring-primary-400 scale-[1.02] shadow-md',
                )}
              >
                <div className="flex items-center gap-2">
                  <Icon className={cn('w-4 h-4', color)} />
                  <span className={cn('font-bold text-base', color)}>{amount}&nbsp;€</span>
                  {highlight && <span className="ml-auto text-[10px] bg-primary-500 text-white px-1.5 py-0.5 rounded-full font-semibold">Beliebt</span>}
                </div>
                <p className="font-semibold text-gray-900 text-sm">{label}</p>
                <p className="text-xs text-gray-500 leading-relaxed">{description}</p>
              </button>
            ))}
          </div>
        </div>

        {/* Banküberweisung */}
        <div className="bg-white rounded-3xl border border-gray-100 shadow-soft p-6 space-y-4">
          <h2 className="font-semibold text-gray-900 flex items-center gap-2">
            <Building2 className="w-4 h-4 text-gray-400" />
            Banküberweisung
          </h2>
          <dl className="space-y-2.5 text-sm">
            <div className="flex justify-between items-center py-2 border-b border-gray-50">
              <dt className="text-gray-400">IBAN</dt>
              <div className="flex items-center gap-2">
                <dd className="font-mono text-gray-700 text-xs">{IBAN}</dd>
                <button
                  onClick={handleCopyIBAN}
                  className="p-1 rounded-lg hover:bg-gray-100 transition-colors"
                  aria-label="IBAN kopieren"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-primary-500" /> : <Copy className="w-3.5 h-3.5 text-gray-400" />}
                </button>
              </div>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-gray-50">
              <dt className="text-gray-400">BIC</dt>
              <dd className="font-mono text-gray-700 text-xs">{BIC}</dd>
            </div>
            <div className="flex justify-between items-center py-2">
              <dt className="text-gray-400">Verwendungszweck</dt>
              <dd className="text-gray-700 text-xs">Spende Mensaena</dd>
            </div>
          </dl>
          <p className="text-xs text-gray-400">
            Spendenbescheinigung auf Anfrage:{' '}
            <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">
              info@mensaena.de
            </a>
          </p>
        </div>

        {/* Transparenz */}
        <div className="bg-white rounded-3xl border border-gray-100 shadow-soft p-6 space-y-4">
          <h2 className="font-semibold text-gray-900">Wo dein Geld hingeht</h2>
          <ul className="space-y-3">
            {COSTS.map(({ label, value, icon: Icon }) => (
              <li key={label} className="flex items-center justify-between text-sm">
                <span className="flex items-center gap-2 text-gray-600">
                  <Icon className="w-4 h-4 text-primary-500 flex-shrink-0" />
                  {label}
                </span>
                <span className="font-medium text-gray-800 bg-gray-50 px-2.5 py-0.5 rounded-full text-xs">{value}</span>
              </li>
            ))}
          </ul>
        </div>

        {/* Supporter badge */}
        <div className="bg-gradient-to-br from-amber-50 to-orange-50 border border-amber-200 rounded-3xl p-5 flex items-center gap-4">
          <div className="flex-shrink-0 w-11 h-11 rounded-2xl bg-amber-100 border border-amber-200 flex items-center justify-center">
            <Heart className="w-5 h-5 text-amber-500 fill-amber-400" />
          </div>
          <div>
            <p className="font-semibold text-gray-900 text-sm">Supporter-Badge</p>
            <p className="text-xs text-gray-600 mt-0.5 leading-relaxed">
              Spender:innen erhalten ein goldenes Herz-Badge im Profil – sichtbares Dankeschön von der Community.
            </p>
          </div>
        </div>

        {/* Spendenbescheinigung auf Anfrage */}
        <ReceiptRequestPanel />

      </div>
    </div>
  )
}
