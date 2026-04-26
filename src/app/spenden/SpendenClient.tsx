'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import QRCode from 'qrcode'
import {
  Heart, Coffee, Star, Sparkles, ArrowLeft, ArrowRight,
  Building2, Smartphone, Copy, Check, Mail, Loader2, Shield,
  CreditCard, Users, FileText, ChevronDown,
  Lock, Eye, Code2, Ban,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

// ─────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────

const AMOUNTS = [1, 3, 5, 10, 25]

const TIERS = [
  { icon: Coffee,    amount: 1,  label: 'Kaffee',        impact: 'Danke! Ein symbolischer Start.' },
  { icon: Heart,     amount: 3,  label: 'Nachbar:in',    impact: 'Push-Benachrichtigungen für 60 Nutzer:innen einen Monat lang.', popular: true },
  { icon: Star,      amount: 5,  label: 'Held:in',       impact: 'Ein Monat Chat-Server für die gesamte Plattform.' },
  { icon: Sparkles,  amount: 10, label: 'Botschafter:in', impact: 'Ein Monat Kartenservice für alle Nachbarschaften.' },
]

const COSTS = [
  { label: 'Server & Infrastruktur', value: '~30 €/Monat', icon: Shield },
  { label: 'Domain & SSL',           value: '~15 €/Jahr',  icon: CreditCard },
  { label: 'SMS-Verifikation',       value: '~0,05 €/Nutzer:in', icon: Users },
  { label: 'Entwicklung',            value: 'ehrenamtlich', icon: Heart },
]

const IBAN      = 'DE79 1001 0178 6303 9229 28'
const BIC       = 'REVODEB2'
const RECIPIENT = 'Mensaena'

// EPC069-12 SEPA Credit Transfer payload
function buildEpcPayload(amount: number): string {
  const ibanCompact = IBAN.replace(/\s/g, '')
  const amt = amount > 0 ? `EUR${amount.toFixed(2)}` : ''
  return [
    'BCD', '002', '1', 'SCT',
    BIC, RECIPIENT, ibanCompact, amt,
    '', '', 'Spende Mensaena',
  ].join('\n')
}

// ─────────────────────────────────────────────────────────────
// Client Page – wird vom Server-Wrapper (page.tsx) eingebunden,
// damit dort SEO-Metadata gerendert werden können.
// ─────────────────────────────────────────────────────────────

export default function SpendenClient() {
  const [userCount, setUserCount]         = useState<number | null>(null)
  const [selectedAmount, setSelectedAmount] = useState<number>(3)
  const [customAmount, setCustomAmount]   = useState('')
  const [isCustom, setIsCustom]           = useState(false)
  const [copied, setCopied]               = useState(false)
  const [qrDataUrl, setQrDataUrl]         = useState<string>('')

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .then(({ count }) => {
        if (count !== null) setUserCount(count)
      })
  }, [])

  const finalAmount = isCustom ? parseFloat(customAmount) || 0 : selectedAmount
  const costPerPerson = userCount && userCount > 0 ? (30 / userCount).toFixed(2) : null

  useEffect(() => {
    const payload = buildEpcPayload(finalAmount)
    QRCode.toDataURL(payload, {
      errorCorrectionLevel: 'M',
      margin: 1,
      width: 320,
      color: { dark: '#0E1A19', light: '#FFFFFF' },
    })
      .then(setQrDataUrl)
      .catch(() => setQrDataUrl(''))
  }, [finalAmount])

  const handleCopyIBAN = async () => {
    try {
      await navigator.clipboard.writeText(IBAN.replace(/\s/g, ''))
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch { /* ignore */ }
  }

  return (
    <div className="min-h-dvh bg-paper">
      {/* ─── Sticky Top Bar ───────────────────────────────────────── */}
      <header className="sticky top-0 z-40 bg-paper/85 backdrop-blur-md border-b border-stone-200">
        <div className="max-w-6xl mx-auto px-6 md:px-10 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <Image src="/mensaena-logo.png" alt="Mensaena" width={36} height={36} className="h-8 w-auto object-contain" />
            <span className="font-display text-lg text-ink-800">Mensaena<span className="text-primary-500">.</span></span>
          </Link>
          <Link
            href="/"
            className="meta-label meta-label--subtle hover:text-primary-700 transition-colors inline-flex items-center gap-1.5"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            Zurück
          </Link>
        </div>
      </header>

      {/* ─── Hero ─────────────────────────────────────────────────── */}
      <section className="relative px-6 md:px-10 pt-20 md:pt-28 pb-16 md:pb-24 overflow-hidden">
        <div
          className="absolute inset-0 pointer-events-none opacity-50"
          style={{ background: 'radial-gradient(ellipse 70% 60% at 50% 0%, rgba(30,170,166,0.18), transparent 70%)' }}
          aria-hidden="true"
        />
        <div className="relative max-w-4xl mx-auto text-center">
          <div className="meta-label mb-7 text-primary-700">— Unterstütze Mensaena</div>
          <h1 className="display-xl mb-8 text-balance">
            Damit Nachbarschaft{' '}
            <span className="text-primary-600">möglich bleibt.</span>
          </h1>
          <p className="text-lg md:text-xl text-ink-500 leading-relaxed max-w-2xl mx-auto">
            Mensaena ist <strong className="text-ink-800">100&nbsp;%&nbsp;werbefrei</strong> und für alle kostenlos.
            Damit das so bleibt, finanzieren wir uns ausschließlich durch Spenden.
          </p>

          {costPerPerson && userCount && (
            <div className="mt-10 inline-flex flex-wrap justify-center items-center gap-x-3 gap-y-1.5 bg-white border border-primary-200 rounded-2xl px-5 py-3 shadow-soft max-w-md">
              <span className="meta-label text-primary-700">Pro Person</span>
              <span className="text-sm text-ink-700">
                Bei <strong>{userCount.toLocaleString('de-DE')}</strong> Nachbar:innen reichen{' '}
                <strong className="text-primary-700">{costPerPerson}&nbsp;€</strong>/Monat.
              </span>
            </div>
          )}

          <ul
            className="mt-12 flex flex-wrap items-center justify-center gap-x-6 gap-y-3 text-[12px] text-ink-500"
            aria-label="Vertrauenswürdigkeit der Spendenseite"
          >
            <TrustItem Icon={Lock} label="SEPA-Standard" />
            <TrustItem Icon={Ban} label="Keine Werbung" />
            <TrustItem Icon={Eye} label="100% transparent" />
            <TrustItem Icon={Code2} label="Open Source" />
          </ul>
        </div>
      </section>

      {/* ─── Amount Picker (centerpiece) ──────────────────────────── */}
      <section className="px-6 md:px-10 pb-20">
        <div className="max-w-3xl mx-auto bg-white rounded-3xl border border-stone-200 shadow-card p-8 md:p-12">
          <div className="meta-label mb-3 text-ink-500">— 01 / Betrag wählen</div>
          <h2 className="font-display text-3xl md:text-4xl text-ink-800 leading-tight tracking-tight mb-8">
            Wie viel möchtest du geben?
          </h2>

          {/* Quick amounts */}
          <div className="grid grid-cols-5 gap-2 md:gap-3 mb-5">
            {AMOUNTS.map(amt => (
              <button
                key={amt}
                onClick={() => { setSelectedAmount(amt); setIsCustom(false) }}
                className={cn(
                  'relative py-4 md:py-5 rounded-2xl text-sm md:text-base font-bold transition-all border-2',
                  !isCustom && selectedAmount === amt
                    ? 'bg-ink-900 text-paper border-ink-900 shadow-md'
                    : 'bg-stone-50 text-ink-700 border-stone-200 hover:border-primary-400 hover:bg-primary-50/50',
                )}
              >
                {amt}&nbsp;€
                {amt === 3 && (
                  <span className="absolute -top-2 left-1/2 -translate-x-1/2 text-[9px] uppercase tracking-wider font-semibold bg-primary-500 text-white px-2 py-0.5 rounded-full">
                    Beliebt
                  </span>
                )}
              </button>
            ))}
          </div>

          {/* Custom amount */}
          <div className="relative mb-8">
            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-ink-400 font-semibold text-sm pointer-events-none">€</span>
            <input
              type="number"
              min="0.50"
              step="0.50"
              value={customAmount}
              placeholder="Eigener Betrag"
              onChange={e => { setCustomAmount(e.target.value); setIsCustom(true) }}
              onFocus={() => setIsCustom(true)}
              className={cn(
                'w-full pl-9 pr-4 py-4 rounded-2xl border-2 text-base font-medium transition-all bg-stone-50',
                isCustom && customAmount
                  ? 'border-primary-500 ring-2 ring-primary-100 bg-white'
                  : 'border-stone-200 hover:border-stone-300',
              )}
            />
          </div>

          {/* Tier preview */}
          <TierPreview amount={finalAmount} />
        </div>
      </section>

      {/* ─── Payment Options ──────────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-20 bg-stone-100">
        <div className="max-w-6xl mx-auto pt-20">
          <div className="text-center mb-12">
            <div className="meta-label mb-3 text-ink-500">— 02 / Zahlungsweg wählen</div>
            <h2 className="display-lg">
              Auf welchem Weg möchtest du spenden?
            </h2>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {/* QR-Code */}
            <div className="bg-white rounded-3xl border border-stone-200 shadow-card p-8 md:p-10">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 rounded-2xl bg-primary-500 text-white flex items-center justify-center">
                  <Smartphone className="w-5 h-5" />
                </div>
                <span className="meta-label text-primary-700">Empfohlen</span>
              </div>
              <h3 className="font-display text-2xl text-ink-800 leading-tight mt-4 mb-2">
                Mit Banking-App scannen
              </h3>
              <p className="text-sm text-ink-500 leading-relaxed mb-6">
                Öffne deine Banking-App (Sparkasse, Volksbank, ING, DKB, N26, comdirect …),
                wähle &bdquo;QR-Code&ldquo; oder &bdquo;Foto&ldquo; und scanne &mdash; alles ist vorausgefüllt.
              </p>

              <div className="flex flex-col items-center">
                <div className="bg-white rounded-3xl border-2 border-stone-100 p-4 shadow-soft">
                  {qrDataUrl ? (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img
                      src={qrDataUrl}
                      alt={`QR-Code für ${finalAmount > 0 ? finalAmount.toFixed(2).replace('.', ',') + ' €' : 'Spende'} an Mensaena`}
                      className="w-56 h-56 md:w-64 md:h-64"
                    />
                  ) : (
                    <div className="w-56 h-56 md:w-64 md:h-64 flex items-center justify-center text-stone-300">
                      <Loader2 className="w-6 h-6 animate-spin" />
                    </div>
                  )}
                </div>
                {finalAmount > 0 && (
                  <p className="mt-4 text-sm text-ink-500">
                    Betrag: <strong className="text-ink-800">{finalAmount.toFixed(2).replace('.', ',')}&nbsp;€</strong>
                  </p>
                )}
              </div>
              <p className="text-[11px] text-ink-400 text-center mt-4">
                SEPA-QR-Standard (EPC069-12) · funktioniert in&nbsp;DE&nbsp;/&nbsp;AT&nbsp;/&nbsp;CH
              </p>
            </div>

            {/* IBAN */}
            <div className="bg-white rounded-3xl border border-stone-200 shadow-card p-8 md:p-10">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 rounded-2xl bg-ink-800 text-paper flex items-center justify-center">
                  <Building2 className="w-5 h-5" />
                </div>
                <span className="meta-label text-ink-500">Klassisch</span>
              </div>
              <h3 className="font-display text-2xl text-ink-800 leading-tight mt-4 mb-2">
                Banküberweisung
              </h3>
              <p className="text-sm text-ink-500 leading-relaxed mb-6">
                Online-Banking, Sparkassen-App oder Beleg &mdash; einmal kopieren, fertig.
              </p>

              <dl className="space-y-3 text-sm">
                <Row label="Empfänger">
                  <span className="text-ink-800">{RECIPIENT}</span>
                </Row>
                <Row label="IBAN">
                  <div className="flex items-center gap-2">
                    <code className="font-mono text-ink-800 text-[13px]">{IBAN}</code>
                    <button
                      onClick={handleCopyIBAN}
                      className="p-1.5 rounded-lg hover:bg-stone-100 transition-colors"
                      aria-label="IBAN kopieren"
                    >
                      {copied
                        ? <Check className="w-3.5 h-3.5 text-primary-600" />
                        : <Copy className="w-3.5 h-3.5 text-ink-400" />}
                    </button>
                  </div>
                </Row>
                <Row label="BIC">
                  <code className="font-mono text-ink-800 text-[13px]">{BIC}</code>
                </Row>
                <Row label="Zweck">
                  <span className="text-ink-800">Spende Mensaena</span>
                </Row>
                {finalAmount > 0 && (
                  <Row label="Betrag">
                    <span className="text-ink-800 font-semibold">{finalAmount.toFixed(2).replace('.', ',')}&nbsp;€</span>
                  </Row>
                )}
              </dl>

              <p className="text-[11px] text-ink-400 mt-6">
                Bank: Revolut Bank UAB · keine Bearbeitungsgebühr für Mensaena
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Transparenz ──────────────────────────────────────────── */}
      <section id="transparenz" className="px-6 md:px-10 py-24 md:py-32 scroll-mt-20">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-14">
            <div className="meta-label mb-3 text-ink-500">— 03 / Transparenz</div>
            <h2 className="display-lg mb-5">
              Wo dein Geld wirklich landet.
            </h2>
            <p className="text-ink-500 max-w-2xl mx-auto">
              Mensaena hat keine Werbung, keine Investoren, keine bezahlten Mitarbeiter:innen.
              Jeder Cent fließt direkt in den Betrieb.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-10">
            {COSTS.map(({ label, value, icon: Icon }, i) => (
              <article key={label} className="border-t border-stone-300 pt-8">
                <div className="flex items-baseline justify-between mb-5">
                  <span className="meta-label meta-label--subtle">{String(i + 1).padStart(2, '0')}</span>
                  <Icon className="w-5 h-5 text-primary-600" aria-hidden="true" />
                </div>
                <h3 className="font-display text-2xl text-ink-800 leading-tight mb-2">
                  {label}
                </h3>
                <p className="text-ink-500 text-sm">
                  {value}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Supporter Badge ──────────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-24">
        <div className="max-w-4xl mx-auto bg-gradient-to-br from-amber-50 via-orange-50 to-amber-50 border border-amber-200 rounded-3xl p-8 md:p-12 relative overflow-hidden">
          <div className="absolute -top-12 -right-12 w-48 h-48 rounded-full bg-amber-200/40 blur-3xl pointer-events-none" aria-hidden="true" />
          <div className="relative flex flex-col md:flex-row items-center gap-8">
            <div className="flex-shrink-0 w-24 h-24 rounded-3xl bg-white border-2 border-amber-300 flex items-center justify-center shadow-amber-200 shadow-lg">
              <Heart className="w-10 h-10 text-amber-500 fill-amber-400" />
            </div>
            <div className="flex-1 text-center md:text-left">
              <div className="meta-label text-amber-700 mb-2">— Dankeschön</div>
              <h3 className="font-display text-2xl md:text-3xl text-ink-800 leading-tight mb-3">
                Das goldene Herz für Unterstützer:innen
              </h3>
              <p className="text-ink-600 leading-relaxed text-sm md:text-base">
                Spender:innen erhalten ein <strong>goldenes Herz-Badge</strong> im Profil &mdash;
                ein dezent leuchtendes Dankeschön von der gesamten Community.
                Sichtbar nach Anforderung der Spendenbescheinigung.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Spendenbescheinigung ─────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-24">
        <div className="max-w-3xl mx-auto">
          <ReceiptRequestSection />
        </div>
      </section>

      {/* ─── Footer Note ──────────────────────────────────────────── */}
      <footer className="px-6 md:px-10 pb-20">
        <div className="max-w-3xl mx-auto text-center">
          <p className="text-[13px] text-ink-400 leading-relaxed">
            Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt.
            Spenden sind daher <strong>nicht</strong> steuerlich absetzbar &mdash; wir arbeiten daran.
          </p>
          <div className="mt-8 flex items-center justify-center gap-4 text-xs text-ink-400">
            <Link href="/impressum" className="hover:text-primary-700 transition-colors">Impressum</Link>
            <span aria-hidden="true">·</span>
            <Link href="/datenschutz" className="hover:text-primary-700 transition-colors">Datenschutz</Link>
            <span aria-hidden="true">·</span>
            <a href="mailto:info@mensaena.de" className="hover:text-primary-700 transition-colors">info@mensaena.de</a>
          </div>
        </div>
      </footer>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────

function TierPreview({ amount }: { amount: number }) {
  const tier = useMemo(() => {
    if (amount <= 0) return null
    if (amount >= 10) return TIERS[3]
    if (amount >= 5)  return TIERS[2]
    if (amount >= 3)  return TIERS[1]
    return TIERS[0]
  }, [amount])

  if (!tier) return null
  const Icon = tier.icon

  return (
    <div className="bg-stone-50 border border-stone-200 rounded-2xl p-5 flex items-start gap-4">
      <div className="flex-shrink-0 w-11 h-11 rounded-xl bg-white border border-stone-200 flex items-center justify-center">
        <Icon className="w-5 h-5 text-primary-600" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <span className="font-semibold text-ink-800 text-sm">{tier.label}</span>
          {tier.popular && (
            <span className="text-[10px] uppercase tracking-wider font-semibold bg-primary-500 text-white px-2 py-0.5 rounded-full">
              Beliebt
            </span>
          )}
        </div>
        <p className="text-sm text-ink-500 leading-relaxed">{tier.impact}</p>
      </div>
    </div>
  )
}

function TrustItem({
  Icon,
  label,
}: {
  Icon: React.ComponentType<{ className?: string }>
  label: string
}) {
  return (
    <li className="inline-flex items-center gap-1.5">
      <Icon className="h-3.5 w-3.5 text-primary-600" aria-hidden="true" />
      <span className="font-medium tracking-wide">{label}</span>
    </li>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between items-center py-2.5 border-b border-stone-100 last:border-0">
      <dt className="meta-label meta-label--subtle">{label}</dt>
      <dd>{children}</dd>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// Receipt request – collapsible
// ─────────────────────────────────────────────────────────────

function ReceiptRequestSection() {
  const [open, setOpen] = useState(false)

  return (
    <div className="bg-white rounded-3xl border border-stone-200 shadow-soft overflow-hidden">
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between gap-4 p-6 md:p-8 text-left hover:bg-stone-50 transition-colors"
        aria-expanded={open}
      >
        <div className="flex items-center gap-4">
          <div className="w-11 h-11 rounded-2xl bg-stone-100 flex items-center justify-center">
            <FileText className="w-5 h-5 text-ink-700" />
          </div>
          <div>
            <h3 className="font-display text-xl text-ink-800 leading-tight">
              Spendenbescheinigung anfordern
            </h3>
            <p className="text-xs text-ink-500 mt-0.5">
              Per E-Mail &mdash; als Zahlungsnachweis (nicht steuerlich absetzbar)
            </p>
          </div>
        </div>
        <ChevronDown className={cn('w-5 h-5 text-ink-400 transition-transform flex-shrink-0', open && 'rotate-180')} />
      </button>

      {open && (
        <div className="border-t border-stone-200 p-6 md:p-8">
          <ReceiptRequestForm />
        </div>
      )}
    </div>
  )
}

function ReceiptRequestForm() {
  const [name, setName]       = useState('')
  const [email, setEmail]     = useState('')
  const [amount, setAmount]   = useState('')
  const [date, setDate]       = useState(() => new Date().toISOString().slice(0, 10))
  const [address, setAddress] = useState('')
  const [sending, setSending] = useState(false)
  const [sent, setSent]       = useState(false)
  const [err, setErr]         = useState<string | null>(null)

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
          userId: session?.user?.id,
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

  if (sent) {
    return (
      <div className="flex flex-col items-center gap-4 py-6 text-center">
        <div className="w-14 h-14 rounded-full bg-primary-50 border border-primary-200 flex items-center justify-center">
          <Check className="w-7 h-7 text-primary-600" />
        </div>
        <div>
          <p className="font-semibold text-ink-800">Bescheinigung wurde versendet!</p>
          <p className="text-sm text-ink-500 mt-1">Bitte prüfe dein Postfach (auch Spam).</p>
        </div>
        <button
          onClick={() => { setSent(false); setName(''); setEmail(''); setAmount(''); setAddress('') }}
          className="text-sm text-primary-700 hover:underline mt-2"
        >
          Weitere Anfrage stellen
        </button>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Field label="Name" required>
          <input
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="Max Mustermann"
            required
            className="input"
          />
        </Field>
        <Field label="E-Mail" required>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            placeholder="max@beispiel.de"
            required
            className="input"
          />
        </Field>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Field label="Betrag (€)" required>
          <input
            type="number"
            min="0.01"
            step="0.01"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder="5.00"
            required
            className="input"
          />
        </Field>
        <Field label="Datum der Spende" required>
          <input
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
            required
            className="input"
          />
        </Field>
      </div>
      <Field label="Adresse" optional>
        <textarea
          value={address}
          onChange={e => setAddress(e.target.value)}
          rows={2}
          placeholder="Straße, PLZ, Ort"
          className="input resize-none"
        />
      </Field>

      {err && (
        <p className="text-sm text-red-700 bg-red-50 border border-red-200 rounded-lg px-3 py-2">{err}</p>
      )}

      <button
        type="submit"
        disabled={sending || !name.trim() || !email.trim() || !amount}
        className="group w-full inline-flex items-center justify-center gap-2 bg-ink-900 hover:bg-ink-800 disabled:opacity-50 disabled:pointer-events-none text-paper px-6 py-3.5 rounded-full text-sm font-medium tracking-wide transition-colors"
      >
        {sending
          ? <Loader2 className="w-4 h-4 animate-spin" />
          : <Mail className="w-4 h-4" />}
        Bescheinigung anfordern
        <ArrowRight className="w-3.5 h-3.5 transition-transform group-hover:translate-x-0.5" />
      </button>
    </form>
  )
}

function Field({
  label, required, optional, children,
}: { label: string; required?: boolean; optional?: boolean; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="meta-label meta-label--subtle mb-1.5 block">
        {label}
        {required && <span className="text-primary-600 ml-1">*</span>}
        {optional && <span className="text-ink-400 ml-1 normal-case tracking-normal">(optional)</span>}
      </span>
      {children}
    </label>
  )
}
