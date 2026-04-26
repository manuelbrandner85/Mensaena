'use client'

// ── DonationBadge ────────────────────────────────────────────────────────────
// Wiederverwendbares Spenden-Element im Mensaena-Stil. Drei Varianten:
//
//  • `pill`     — kompakter Pill-Button (Navbar / Inline-CTA)
//  • `hero`     — eleganter Hero-Pill mit pulsierendem Punkt (über der Headline)
//  • `floating` — sticky Floating-Badge unten rechts auf der Landingpage,
//                 erscheint erst nach Scroll, schließbar (localStorage)
//
// Design folgt dem editorialen Mensaena-Stil: dezent, weißer Hintergrund,
// Teal-Akzent, weiche Schatten, runde Pill-Form.

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Heart, X, ArrowRight } from 'lucide-react'

const FLOATING_DISMISS_KEY = 'mensaena_donation_badge_dismissed'
const FLOATING_DISMISS_TTL_MS = 1000 * 60 * 60 * 24 * 7 // 7 Tage

export type DonationBadgeVariant = 'pill' | 'hero' | 'floating'

export interface DonationBadgeProps {
  variant?: DonationBadgeVariant
  href?: string
  className?: string
  /** Nur für `floating`: Pixel ab denen der Badge sichtbar wird (default: 600) */
  showAfterScroll?: number
  /** Nur für `floating`: optionaler Aria-Label-Text */
  label?: string
}

// ── Public component ─────────────────────────────────────────────────────────

export default function DonationBadge({
  variant = 'pill',
  href = '/spenden',
  className = '',
  showAfterScroll = 600,
  label,
}: DonationBadgeProps) {
  if (variant === 'pill') return <PillBadge href={href} className={className} />
  if (variant === 'hero') return <HeroBadge href={href} className={className} />
  return <FloatingBadge href={href} className={className} showAfterScroll={showAfterScroll} label={label} />
}

// ── Pill (Navbar / Inline) ───────────────────────────────────────────────────

function PillBadge({ href, className }: { href: string; className: string }) {
  return (
    <Link
      href={href}
      className={`group inline-flex items-center gap-2 rounded-full border border-primary-200 bg-primary-50/70 px-3.5 py-1.5 text-[12px] font-medium tracking-wide text-primary-700 transition-all duration-300 hover:border-primary-300 hover:bg-primary-50 hover:shadow-glow-teal ${className}`}
      aria-label="Mensaena unterstützen"
    >
      <Heart className="h-3.5 w-3.5 fill-primary-500/30 text-primary-600 transition-transform duration-300 group-hover:scale-110" aria-hidden="true" />
      <span>Spenden</span>
    </Link>
  )
}

// ── Hero (über der Headline) ─────────────────────────────────────────────────

function HeroBadge({ href, className }: { href: string; className: string }) {
  return (
    <Link
      href={href}
      className={`group inline-flex max-w-full items-center gap-2.5 rounded-full border border-stone-200 bg-white/80 px-4 py-1.5 text-[12px] font-medium tracking-wide text-ink-700 shadow-soft backdrop-blur-sm transition-all duration-300 hover:border-primary-300 hover:bg-white hover:shadow-card ${className}`}
      aria-label="Mehr über die Spendenfinanzierung von Mensaena"
    >
      <span className="relative flex h-2 w-2 flex-shrink-0">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary-400 opacity-75" aria-hidden="true" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-primary-500" />
      </span>
      <span className="truncate">
        <span className="text-ink-800">Spendenfinanziert</span>
        <span className="mx-1.5 text-stone-300" aria-hidden="true">·</span>
        <span className="text-ink-500">100&nbsp;%&nbsp;werbefrei</span>
      </span>
      <ArrowRight className="hidden h-3 w-3 flex-shrink-0 text-primary-600 transition-transform duration-300 group-hover:translate-x-0.5 sm:inline" aria-hidden="true" />
    </Link>
  )
}

// ── Floating (sticky, dismissable) ───────────────────────────────────────────

function FloatingBadge({
  href,
  className,
  showAfterScroll,
  label,
}: {
  href: string
  className: string
  showAfterScroll: number
  label?: string
}) {
  const [visible, setVisible] = useState(false)
  const [dismissed, setDismissed] = useState(true) // start dismissed bis localStorage geprüft

  useEffect(() => {
    if (typeof window === 'undefined') return
    try {
      const raw = window.localStorage.getItem(FLOATING_DISMISS_KEY)
      if (raw) {
        const ts = parseInt(raw, 10)
        if (!Number.isNaN(ts) && Date.now() - ts < FLOATING_DISMISS_TTL_MS) {
          return // dismissed, bleibt unsichtbar
        }
      }
    } catch { /* localStorage gesperrt – ignorieren, einfach anzeigen */ }
    setDismissed(false)
  }, [])

  useEffect(() => {
    if (dismissed) return
    const onScroll = () => {
      if (window.scrollY > showAfterScroll) setVisible(true)
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => window.removeEventListener('scroll', onScroll)
  }, [dismissed, showAfterScroll])

  function handleDismiss() {
    try { window.localStorage.setItem(FLOATING_DISMISS_KEY, String(Date.now())) } catch { /* ignore */ }
    setVisible(false)
    setDismissed(true)
  }

  if (dismissed || !visible) return null

  return (
    <div
      className={`pointer-events-none fixed bottom-6 right-6 z-40 hidden max-w-[calc(100vw-2.5rem)] md:block ${className}`}
      role="complementary"
      aria-label={label ?? 'Mensaena unterstützen'}
    >
      <div className="pointer-events-auto group relative flex items-center gap-2 rounded-full border border-stone-200 bg-white/95 py-1.5 pr-1.5 pl-4 shadow-card backdrop-blur-md transition-all duration-300 hover:border-primary-300 hover:shadow-glow-teal">
        <span className="relative flex h-2 w-2 flex-shrink-0" aria-hidden="true">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-primary-400 opacity-75" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-primary-500" />
        </span>
        <Link
          href={href}
          className="flex items-center gap-2 text-[12px] font-medium text-ink-700 transition-colors duration-300 hover:text-ink-900"
        >
          <span className="hidden sm:inline">Werbefrei dank Spenden</span>
          <span className="sm:hidden">Spenden</span>
          <span className="inline-flex items-center gap-1 rounded-full bg-ink-900 px-3 py-1 text-[11px] font-medium text-paper transition-colors duration-300 group-hover:bg-ink-800">
            <Heart className="h-3 w-3 fill-paper/30" aria-hidden="true" />
            Unterstützen
          </span>
        </Link>
        <button
          type="button"
          onClick={handleDismiss}
          aria-label="Hinweis schließen"
          className="ml-0.5 flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full text-ink-400 transition-colors duration-300 hover:bg-stone-100 hover:text-ink-700"
        >
          <X className="h-3.5 w-3.5" aria-hidden="true" />
        </button>
      </div>
    </div>
  )
}
