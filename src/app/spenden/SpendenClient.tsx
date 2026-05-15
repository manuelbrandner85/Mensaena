'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import QRCode from 'qrcode'
import {
  Heart, Coffee, Star, Sparkles, ArrowLeft, ArrowRight,
  Building2, Smartphone, Copy, Check, Mail, Loader2, Shield,
  CreditCard, Users, FileText, ChevronDown,
  Lock, Eye, Code2, Ban, MessageCircle, BarChart2, Radio, Megaphone,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { DONOR_TIERS, calculateDonorTier } from '@/lib/donorTier'

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
  const [myTier, setMyTier]               = useState(0)
  const [myCount, setMyCount]             = useState(0)
  const [myTotal, setMyTotal]             = useState(0)

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .then(({ count }) => {
        if (count !== null) setUserCount(count)
      })
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) return
      supabase
        .from('profiles')
        .select('donor_tier, donation_count, donation_total')
        .eq('id', data.user.id)
        .single()
        .then(({ data: p }) => {
          if (!p) return
          setMyTier((p as any).donor_tier ?? 0)
          setMyCount((p as any).donation_count ?? 0)
          setMyTotal(parseFloat((p as any).donation_total ?? 0))
        })
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
    <div className="min-h-dvh" style={{ background: '#0a1420', color: '#ece5d6' }}>
      {/* ─── Sticky Top Bar — Cinema glass ───────────────────────── */}
      <header
        className="sticky top-0 z-40"
        style={{
          background: 'rgba(10,20,32,0.85)',
          backdropFilter: 'blur(20px) saturate(1.4)',
          WebkitBackdropFilter: 'blur(20px) saturate(1.4)',
          borderBottom: '1px solid rgba(199,147,99,0.10)',
        }}
      >
        <div className="max-w-6xl mx-auto px-6 md:px-10 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <Image src="/mensaena-logo.png" alt="Mensaena" width={36} height={36} className="h-8 w-auto object-contain" />
            <span
              className="text-lg font-medium tracking-tight"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F1F5F9' }}
            >
              Mensaena<span style={{ color: '#c79363' }}>.</span>
            </span>
          </Link>
          <Link
            href="/"
            className="meta-label meta-label--subtle transition-colors inline-flex items-center gap-1.5 hover:text-mn-paper"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            Zurück
          </Link>
        </div>
      </header>

      {/* ─── Hero — Cinematic atmospheric depth ───────────────────── */}
      <section className="relative px-6 md:px-10 pt-24 md:pt-32 pb-20 md:pb-28 overflow-hidden">
        {/* Layered ambient orbs */}
        <div
          className="hero-orb-1 absolute pointer-events-none"
          style={{ top: '-20%', left: '-15%', width: '60vw', height: '60vw' }}
          aria-hidden="true"
        />
        <div
          className="hero-orb-2 absolute pointer-events-none"
          style={{ top: '-10%', right: '-15%', width: '50vw', height: '50vw' }}
          aria-hidden="true"
        />
        <div
          className="hero-orb-3 absolute pointer-events-none"
          style={{ bottom: '-15%', left: '30%', width: '45vw', height: '45vw' }}
          aria-hidden="true"
        />
        {/* Depth grid */}
        <div
          className="absolute inset-0 depth-grid-overlay pointer-events-none opacity-50"
          aria-hidden="true"
        />
        <div className="relative max-w-4xl mx-auto text-center">
          <div className="meta-label mb-7" style={{ color: '#c79363' }}>— Unterstütze Mensaena</div>
          <h1
            className="mb-8 text-balance"
            style={{
              fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
              fontWeight: 400,
              fontSize: 'clamp(2.25rem, 6vw, 4.5rem)',
              lineHeight: 1.05,
              letterSpacing: '-0.025em',
              color: '#F8FAFC',
            }}
          >
            Damit Nachbarschaft{' '}
            <em style={{ fontStyle: 'italic', color: '#c79363' }}>möglich bleibt.</em>
          </h1>
          <p className="text-lg md:text-xl leading-relaxed max-w-2xl mx-auto" style={{ color: '#94A3B8' }}>
            Mensaena ist <strong style={{ color: '#ece5d6' }}>100&nbsp;%&nbsp;werbefrei</strong> und für alle kostenlos.
            Damit das so bleibt, finanzieren wir uns ausschließlich durch Spenden.
          </p>

          {costPerPerson && userCount && (
            <div
              className="mt-10 inline-flex flex-wrap justify-center items-center gap-x-3 gap-y-1.5 rounded-2xl px-5 py-3 max-w-md"
              style={{ background: 'rgba(22,32,53,0.80)', border: '1px solid rgba(199,147,99,0.15)' }}
            >
              <span className="meta-label" style={{ color: '#c79363' }}>Pro Person</span>
              <span className="text-sm" style={{ color: '#94A3B8' }}>
                Bei <strong style={{ color: '#ece5d6' }}>{userCount.toLocaleString('de-DE')}</strong> Nachbar:innen reichen{' '}
                <strong style={{ color: '#c79363' }}>{costPerPerson}&nbsp;€</strong>/Monat.
              </span>
            </div>
          )}

          <ul
            className="mt-12 flex flex-wrap items-center justify-center gap-x-6 gap-y-3 text-[12px]"
            style={{ color: '#64748B' }}
            aria-label="Vertrauenswürdigkeit der Spendenseite"
          >
            <TrustItem Icon={Lock} label="SEPA-Standard" />
            <TrustItem Icon={Ban} label="Keine Werbung" />
            <TrustItem Icon={Eye} label="100% transparent" />
            <TrustItem Icon={Code2} label="Open Source" />
          </ul>
        </div>
      </section>

      {/* ─── Amount Picker ────────────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-20">
        <div
          className="max-w-3xl mx-auto rounded-3xl p-8 md:p-12"
          style={{
            background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
            border: '1px solid rgba(255,255,255,0.06)',
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 32px rgba(0,0,0,0.40)',
          }}
        >
          <div className="meta-label mb-3 meta-label--subtle">— 01 / Betrag wählen</div>
          <h2
            className="text-3xl md:text-4xl leading-tight tracking-tight mb-8"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
          >
            Wie viel möchtest du geben?
          </h2>

          {/* Quick amounts */}
          <div className="grid grid-cols-5 gap-2 md:gap-3 mb-5">
            {AMOUNTS.map(amt => (
              <button
                key={amt}
                onClick={() => { setSelectedAmount(amt); setIsCustom(false) }}
                className="relative py-4 md:py-5 rounded-2xl text-sm md:text-base font-bold transition-all"
                style={
                  !isCustom && selectedAmount === amt
                    ? {
                        background: 'linear-gradient(135deg, #c79363 0%, #d4a472 100%)',
                        color: '#0a1420',
                        border: '1px solid rgba(212,164,114,0.40)',
                        boxShadow: '0 4px 16px rgba(199,147,99,0.30)',
                      }
                    : {
                        background: 'rgba(15,22,40,0.60)',
                        color: '#94A3B8',
                        border: '1px solid rgba(255,255,255,0.07)',
                      }
                }
              >
                {amt}&nbsp;€
                {amt === 3 && (
                  <span
                    className="absolute -top-2 left-1/2 -translate-x-1/2 text-[9px] uppercase tracking-wider font-bold px-2 py-0.5 rounded-full"
                    style={{ background: '#c79363', color: '#0a1420' }}
                  >
                    Beliebt
                  </span>
                )}
              </button>
            ))}
          </div>

          {/* Custom amount */}
          <div className="relative mb-8">
            <span
              className="absolute left-4 top-1/2 -translate-y-1/2 font-semibold text-sm pointer-events-none"
              style={{ color: '#64748B' }}
            >
              €
            </span>
            <input
              type="number"
              min="0.50"
              step="0.50"
              value={customAmount}
              placeholder="Eigener Betrag"
              onChange={e => { setCustomAmount(e.target.value); setIsCustom(true) }}
              onFocus={() => setIsCustom(true)}
              className="w-full pl-9 pr-4 py-4 rounded-2xl text-base font-medium transition-all"
              style={{
                background: 'rgba(15,22,40,0.65)',
                border: isCustom && customAmount ? '1px solid rgba(199,147,99,0.45)' : '1px solid rgba(255,255,255,0.07)',
                color: '#F8FAFC',
                boxShadow: isCustom && customAmount ? '0 0 0 3px rgba(199,147,99,0.10)' : 'none',
                outline: 'none',
              }}
            />
          </div>

          {/* Tier preview */}
          <TierPreview amount={finalAmount} />
        </div>
      </section>

      {/* ─── Payment Options ──────────────────────────────────────── */}
      <section
        className="px-6 md:px-10 pb-20"
        style={{ background: 'rgba(10,15,28,0.60)' }}
      >
        <div className="max-w-6xl mx-auto pt-20">
          <div className="text-center mb-12">
            <div className="meta-label mb-3 meta-label--subtle">— 02 / Zahlungsweg wählen</div>
            <h2
              className="text-3xl md:text-4xl font-medium leading-tight tracking-tight"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
            >
              Auf welchem Weg möchtest du spenden?
            </h2>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {/* QR-Code */}
            <div
              className="rounded-3xl p-8 md:p-10"
              style={{
                background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
                border: '1px solid rgba(255,255,255,0.07)',
                boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 32px rgba(0,0,0,0.40)',
              }}
            >
              <div className="flex items-center gap-3 mb-2">
                <div
                  className="w-10 h-10 rounded-2xl flex items-center justify-center"
                  style={{ background: 'rgba(199,147,99,0.15)', border: '1px solid rgba(199,147,99,0.25)' }}
                >
                  <Smartphone className="w-5 h-5" style={{ color: '#c79363' }} />
                </div>
                <span className="meta-label" style={{ color: '#c79363' }}>Empfohlen</span>
              </div>
              <h3
                className="text-2xl leading-tight mt-4 mb-2"
                style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
              >
                Mit Banking-App scannen
              </h3>
              <p className="text-sm leading-relaxed mb-6" style={{ color: '#64748B' }}>
                Öffne deine Banking-App (Sparkasse, Volksbank, ING, DKB, N26, comdirect …),
                wähle „QR-Code" oder „Foto" und scanne — alles ist vorausgefüllt.
              </p>

              <div className="flex flex-col items-center">
                <div
                  className="rounded-2xl p-4"
                  style={{ background: 'rgba(15,22,40,0.80)', border: '1px solid rgba(199,147,99,0.15)' }}
                >
                  {qrDataUrl ? (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img
                      src={qrDataUrl}
                      alt={`QR-Code für ${finalAmount > 0 ? finalAmount.toFixed(2).replace('.', ',') + ' €' : 'Spende'} an Mensaena`}
                      className="w-56 h-56 md:w-64 md:h-64"
                    />
                  ) : (
                    <div className="w-56 h-56 md:w-64 md:h-64 flex items-center justify-center" style={{ color: '#64748B' }}>
                      <Loader2 className="w-6 h-6 animate-spin" />
                    </div>
                  )}
                </div>
                {finalAmount > 0 && (
                  <p className="mt-4 text-sm" style={{ color: '#64748B' }}>
                    Betrag: <strong style={{ color: '#ece5d6' }}>{finalAmount.toFixed(2).replace('.', ',')}&nbsp;€</strong>
                  </p>
                )}
              </div>
              <p className="text-[11px] text-center mt-4" style={{ color: '#64748B' }}>
                SEPA-QR-Standard (EPC069-12) · funktioniert in&nbsp;DE&nbsp;/&nbsp;AT&nbsp;/&nbsp;CH
              </p>
            </div>

            {/* IBAN */}
            <div
              className="rounded-3xl p-8 md:p-10"
              style={{
                background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
                border: '1px solid rgba(255,255,255,0.07)',
                boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 32px rgba(0,0,0,0.40)',
              }}
            >
              <div className="flex items-center gap-3 mb-2">
                <div
                  className="w-10 h-10 rounded-2xl flex items-center justify-center"
                  style={{ background: 'rgba(22,32,53,0.85)', border: '1px solid rgba(255,255,255,0.08)' }}
                >
                  <Building2 className="w-5 h-5" style={{ color: '#94A3B8' }} />
                </div>
                <span className="meta-label meta-label--subtle">Klassisch</span>
              </div>
              <h3
                className="text-2xl leading-tight mt-4 mb-2"
                style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
              >
                Banküberweisung
              </h3>
              <p className="text-sm leading-relaxed mb-6" style={{ color: '#64748B' }}>
                Online-Banking, Sparkassen-App oder Beleg — einmal kopieren, fertig.
              </p>

              <dl className="space-y-3 text-sm">
                <Row label="Empfänger">
                  <span style={{ color: '#ece5d6' }}>{RECIPIENT}</span>
                </Row>
                <Row label="IBAN">
                  <div className="flex items-center gap-2">
                    <code className="font-mono text-[13px]" style={{ color: '#ece5d6' }}>{IBAN}</code>
                    <button
                      onClick={handleCopyIBAN}
                      className="p-1.5 rounded-lg transition-colors"
                      style={{ background: 'rgba(22,32,53,0.60)' }}
                      aria-label="IBAN kopieren"
                    >
                      {copied
                        ? <Check className="w-3.5 h-3.5" style={{ color: '#c79363' }} />
                        : <Copy className="w-3.5 h-3.5" style={{ color: '#64748B' }} />}
                    </button>
                  </div>
                </Row>
                <Row label="BIC">
                  <code className="font-mono text-[13px]" style={{ color: '#ece5d6' }}>{BIC}</code>
                </Row>
                <Row label="Zweck">
                  <span style={{ color: '#ece5d6' }}>Spende Mensaena</span>
                </Row>
                {finalAmount > 0 && (
                  <Row label="Betrag">
                    <span className="font-semibold" style={{ color: '#c79363' }}>{finalAmount.toFixed(2).replace('.', ',')}&nbsp;€</span>
                  </Row>
                )}
              </dl>

              <p className="text-[11px] mt-6" style={{ color: '#64748B' }}>
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
            <div className="meta-label mb-3 meta-label--subtle">— 03 / Transparenz</div>
            <h2
              className="mb-5 text-3xl md:text-4xl font-medium leading-tight tracking-tight"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
            >
              Wo dein Geld wirklich landet.
            </h2>
            <p className="max-w-2xl mx-auto" style={{ color: '#64748B' }}>
              Mensaena hat keine Werbung, keine Investoren, keine bezahlten Mitarbeiter:innen.
              Jeder Cent fließt direkt in den Betrieb.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-10">
            {COSTS.map(({ label, value, icon: Icon }, i) => (
              <article key={label} className="pt-8" style={{ borderTop: '1px solid rgba(199,147,99,0.15)' }}>
                <div className="flex items-baseline justify-between mb-5">
                  <span className="meta-label meta-label--subtle">{String(i + 1).padStart(2, '0')}</span>
                  <Icon className="w-5 h-5" style={{ color: '#c79363' }} aria-hidden="true" />
                </div>
                <h3
                  className="text-2xl leading-tight mb-2"
                  style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
                >
                  {label}
                </h3>
                <p className="text-sm" style={{ color: '#64748B' }}>
                  {value}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Supporter Badge ──────────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-24">
        <div
          className="max-w-4xl mx-auto rounded-3xl p-8 md:p-12 relative overflow-hidden"
          style={{
            background: 'linear-gradient(135deg, rgba(199,147,99,0.08) 0%, rgba(22,32,53,0.85) 60%)',
            border: '1px solid rgba(199,147,99,0.20)',
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 32px rgba(0,0,0,0.40)',
          }}
        >
          <div
            className="absolute -top-12 -right-12 w-48 h-48 rounded-full pointer-events-none"
            style={{ background: 'radial-gradient(circle, rgba(199,147,99,0.15) 0%, transparent 70%)', filter: 'blur(30px)' }}
            aria-hidden="true"
          />
          <div className="relative flex flex-col md:flex-row items-center gap-8">
            <div
              className="flex-shrink-0 w-24 h-24 rounded-3xl flex items-center justify-center"
              style={{ background: 'rgba(199,147,99,0.10)', border: '2px solid rgba(199,147,99,0.30)' }}
            >
              <Heart className="w-10 h-10" style={{ color: '#c79363', fill: 'rgba(199,147,99,0.30)' }} />
            </div>
            <div className="flex-1 text-center md:text-left">
              <div className="meta-label mb-2" style={{ color: '#c79363' }}>— Dankeschön</div>
              <h3
                className="text-2xl md:text-3xl leading-tight mb-3"
                style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
              >
                Das goldene Herz für Unterstützer:innen
              </h3>
              <p className="leading-relaxed text-sm md:text-base" style={{ color: '#94A3B8' }}>
                Spender:innen erhalten ein <strong style={{ color: '#ece5d6' }}>goldenes Herz-Badge</strong> im Profil —
                ein dezent leuchtendes Dankeschön von der gesamten Community.
                Sichtbar nach Anforderung der Spendenbescheinigung.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Donor Tier Benefits ──────────────────────────────────── */}
      <section className="px-6 md:px-10 pb-24">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-10">
            <div className="meta-label mb-3" style={{ color: '#c79363' }}>— Dankeschön-Stufen</div>
            <h2
              className="mb-4 text-3xl md:text-4xl font-medium leading-tight tracking-tight"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
            >
              Was du mit deiner Spende freischaltest.
            </h2>
            <p className="text-sm max-w-xl mx-auto" style={{ color: '#64748B' }}>
              Jede Spende hilft Mensaena – und schaltet stufenweise Community-Funktionen im Chat frei.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
            {([
              { tier: 1, emoji: '🤍', name: 'Unterstützer', threshold: '1 Spende oder ab 5 €', features: [
                { icon: MessageCircle, label: 'Spender-Badge im Chat' },
              ]},
              { tier: 2, emoji: '💛', name: 'Förderer', threshold: '3 Spenden oder ab 25 €', features: [
                { icon: BarChart2, label: 'Umfragen erstellen' },
                { icon: MessageCircle, label: 'Eigenen Kanal anlegen' },
              ]},
              { tier: 3, emoji: '🧡', name: 'Partner', threshold: '5 Spenden oder ab 50 €', features: [
                { icon: Radio, label: 'Livestream-Events planen' },
                { icon: Megaphone, label: 'Ankündigungen posten' },
              ]},
              { tier: 4, emoji: '❤️', name: 'Botschafter', threshold: '10 Spenden oder ab 100 €', features: [
                { icon: Star, label: 'Post-Boost' },
                { icon: Users, label: 'Profil-Banner' },
              ]},
            ] as const).map(({ tier, emoji, name, threshold, features }) => {
              const isCurrent = myTier === tier
              const isDone    = myTier > tier
              return (
                <div
                  key={tier}
                  className="rounded-2xl p-5 transition-all relative"
                  style={{
                    background: isCurrent
                      ? 'linear-gradient(150deg, rgba(199,147,99,0.12) 0%, rgba(22,32,53,0.85) 100%)'
                      : isDone
                        ? 'rgba(22,32,53,0.60)'
                        : 'rgba(22,32,53,0.80)',
                    border: isCurrent
                      ? '2px solid rgba(199,147,99,0.35)'
                      : isDone
                        ? '1px solid rgba(255,255,255,0.06)'
                        : '1px solid rgba(255,255,255,0.06)',
                  }}
                >
                  {isCurrent && (
                    <span
                      className="absolute -top-3 left-1/2 -translate-x-1/2 text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full"
                      style={{ background: '#c79363', color: '#0a1420' }}
                    >
                      Deine Stufe
                    </span>
                  )}
                  {isDone && (
                    <span
                      className="absolute -top-3 left-1/2 -translate-x-1/2 text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full"
                      style={{ background: 'rgba(100,116,139,0.40)', color: '#94A3B8', border: '1px solid rgba(255,255,255,0.08)' }}
                    >
                      Erreicht ✓
                    </span>
                  )}
                  <div className="text-3xl mb-2">{emoji}</div>
                  <p className="font-bold text-sm mb-1" style={{ color: '#F8FAFC' }}>{name}</p>
                  <p className="text-[11px] mb-3" style={{ color: '#64748B' }}>{threshold}</p>
                  <ul className="space-y-1.5">
                    {features.map(({ icon: Icon, label }) => (
                      <li key={label} className="flex items-center gap-2 text-xs" style={{ color: '#94A3B8' }}>
                        <Icon className="w-3.5 h-3.5 flex-shrink-0" style={{ color: '#c79363' }} />
                        {label}
                      </li>
                    ))}
                  </ul>
                </div>
              )
            })}
          </div>

          {/* Progress toward next tier */}
          {myTier < 4 && myCount > 0 && (() => {
            const next = DONOR_TIERS[myTier + 1]
            const neededCount = myTier + 1 === 1 ? 1 : myTier + 1 === 2 ? 3 : myTier + 1 === 3 ? 5 : 10
            const neededTotal = myTier + 1 === 1 ? 5 : myTier + 1 === 2 ? 25 : myTier + 1 === 3 ? 50 : 100
            const progress = Math.min(myCount / neededCount, 1)
            return (
              <div
                className="rounded-2xl p-5 max-w-lg mx-auto text-center"
                style={{
                  background: 'rgba(22,32,53,0.80)',
                  border: '1px solid rgba(255,255,255,0.06)',
                }}
              >
                <p className="text-sm mb-3" style={{ color: '#94A3B8' }}>
                  Noch <strong style={{ color: '#ece5d6' }}>{Math.max(neededCount - myCount, 0)} Spenden</strong> oder{' '}
                  <strong style={{ color: '#ece5d6' }}>{Math.max(neededTotal - myTotal, 0).toFixed(0)} €</strong> bis{' '}
                  {next.emoji} <strong style={{ color: '#c79363' }}>{next.name}</strong>
                </p>
                <div className="h-1.5 rounded-full overflow-hidden mb-1" style={{ background: 'rgba(255,255,255,0.06)' }}>
                  <div
                    className="h-full rounded-full transition-all"
                    style={{ width: `${progress * 100}%`, background: 'linear-gradient(90deg, #c79363, #d4a472)' }}
                  />
                </div>
                <p className="text-[11px]" style={{ color: '#64748B' }}>{myCount}/{neededCount} Spenden</p>
              </div>
            )
          })()}
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
          <p className="text-[13px] leading-relaxed" style={{ color: '#64748B' }}>
            Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt.
            Spenden sind daher <strong style={{ color: '#94A3B8' }}>nicht</strong> steuerlich absetzbar — wir arbeiten daran.
          </p>
          <div className="mt-8 flex items-center justify-center gap-4 text-xs" style={{ color: '#64748B' }}>
            <Link href="/impressum" className="transition-colors hover:text-mn-paper">Impressum</Link>
            <span aria-hidden="true">·</span>
            <Link href="/datenschutz" className="transition-colors hover:text-mn-paper">Datenschutz</Link>
            <span aria-hidden="true">·</span>
            <a href="mailto:info@mensaena.de" className="transition-colors hover:text-mn-paper">info@mensaena.de</a>
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
    <div
      className="rounded-2xl p-5 flex items-start gap-4"
      style={{
        background: 'rgba(22,32,53,0.70)',
        border: '1px solid rgba(199,147,99,0.15)',
      }}
    >
      <div
        className="flex-shrink-0 w-11 h-11 rounded-xl flex items-center justify-center"
        style={{ background: 'rgba(199,147,99,0.10)', border: '1px solid rgba(199,147,99,0.20)' }}
      >
        <Icon className="w-5 h-5" style={{ color: '#c79363' }} />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <span className="font-semibold text-sm" style={{ color: '#F8FAFC' }}>{tier.label}</span>
          {tier.popular && (
            <span
              className="text-xs uppercase tracking-wider font-bold px-2 py-0.5 rounded-full"
              style={{ background: '#c79363', color: '#0a1420' }}
            >
              Beliebt
            </span>
          )}
        </div>
        <p className="text-sm leading-relaxed" style={{ color: '#64748B' }}>{tier.impact}</p>
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
      <Icon className="h-3.5 w-3.5" style={{ color: '#c79363' }} aria-hidden="true" />
      <span className="font-medium tracking-wide">{label}</span>
    </li>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between items-center py-2.5 last:border-0" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
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
    <div
      className="rounded-3xl overflow-hidden"
      style={{
        background: 'linear-gradient(150deg, rgba(22,32,53,0.82) 0%, rgba(15,22,40,0.92) 100%)',
        border: '1px solid rgba(255,255,255,0.06)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.35)',
      }}
    >
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between gap-4 p-6 md:p-8 text-left transition-colors"
        style={{ background: 'transparent' }}
        aria-expanded={open}
      >
        <div className="flex items-center gap-4">
          <div
            className="w-11 h-11 rounded-2xl flex items-center justify-center"
            style={{ background: 'rgba(100,116,139,0.15)', border: '1px solid rgba(255,255,255,0.06)' }}
          >
            <FileText className="w-5 h-5" style={{ color: '#94A3B8' }} />
          </div>
          <div>
            <h3
              className="text-xl leading-tight"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F8FAFC' }}
            >
              Spendenbescheinigung anfordern
            </h3>
            <p className="text-xs mt-0.5" style={{ color: '#64748B' }}>
              Per E-Mail — als Zahlungsnachweis (nicht steuerlich absetzbar)
            </p>
          </div>
        </div>
        <ChevronDown className={cn('w-5 h-5 transition-transform flex-shrink-0', open && 'rotate-180')} style={{ color: '#64748B' }} />
      </button>

      {open && (
        <div className="p-6 md:p-8" style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}>
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
        <div
          className="w-14 h-14 rounded-full flex items-center justify-center"
          style={{ background: 'rgba(199,147,99,0.10)', border: '1px solid rgba(199,147,99,0.25)' }}
        >
          <Check className="w-7 h-7" style={{ color: '#c79363' }} />
        </div>
        <div>
          <p className="font-semibold" style={{ color: '#F8FAFC' }}>Bescheinigung wurde versendet!</p>
          <p className="text-sm mt-1" style={{ color: '#64748B' }}>Bitte prüfe dein Postfach (auch Spam).</p>
        </div>
        <button
          onClick={() => { setSent(false); setName(''); setEmail(''); setAmount(''); setAddress('') }}
          className="text-sm hover:underline mt-2 transition-colors"
          style={{ color: '#c79363' }}
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
        <p className="text-sm text-mn-herzrot bg-mn-surface border border-mn-herzrot/20 rounded-lg px-3 py-2">{err}</p>
      )}

      <button
        type="submit"
        disabled={sending || !name.trim() || !email.trim() || !amount}
        className="group w-full inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-full text-sm font-medium tracking-wide transition-all hover:scale-[1.01] active:scale-95 disabled:opacity-50 disabled:pointer-events-none"
        style={{
          background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)',
          color: '#0a1420',
          border: '1px solid rgba(212,164,114,0.40)',
          boxShadow: '0 4px 16px rgba(199,147,99,0.28)',
        }}
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
        {required && <span className="ml-1" style={{ color: '#c79363' }}>*</span>}
        {optional && <span className="ml-1 normal-case tracking-normal" style={{ color: '#64748B' }}>(optional)</span>}
      </span>
      {children}
    </label>
  )
}
