'use client'

// ─────────────────────────────────────────────────────────────────────────────
// HolidayBadge – Kompakter Feiertags-Hinweis fürs Dashboard
//
// Zeigt — abhängig vom Datum — den passenden Hinweis:
//   • Heute Feiertag      → "🎉 Heute ist {Name} – Schönen Feiertag!"
//   • Morgen Feiertag     → "📅 Morgen ist {Name}"
//   • Sonst nächster      → "Nächster Feiertag: {Name} am {Datum} (in X Tagen)"
//
// Lat/Lng aus User-Profil → Bundesland → API-Call.
// 24h Cache via lib/api/holidays.ts.
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import { Calendar, PartyPopper, ArrowRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchHolidaysForCurrentAndNextYear,
  isHolidayToday,
  isHolidayTomorrow,
  getNextHoliday,
  daysUntilHoliday,
  getHolidayEmoji,
  getHolidayDescription,
  plzToBundesland,
  coordsToBundesland,
  BUNDESLAND_NAMES,
  type Holiday,
  type BundeslandCode,
} from '@/lib/api/holidays'

// ── Props ───────────────────────────────────────────────────────────────────

export interface HolidayBadgeProps {
  /** Bundesland-Code – wenn gesetzt, wird PLZ/Koordinaten ignoriert */
  state?: BundeslandCode
  /** PLZ aus User-Profil (Vorrang vor lat/lng) */
  plz?: string | null
  /** Geo-Koordinaten als Fallback wenn keine PLZ vorhanden */
  lat?: number | null
  /** Geo-Koordinaten als Fallback wenn keine PLZ vorhanden */
  lng?: number | null
  /** Visuelle Variante */
  variant?: 'default' | 'compact'
  /** Nicht anzeigen wenn der nächste Feiertag weiter als X Tage entfernt ist */
  maxDaysAhead?: number
  /** Optional: eigene CSS-Klassen für den Wrapper */
  className?: string
  /** Optional: Link zur weiteren Aktion (z. B. /dashboard/events) */
  actionHref?: string
  /** Optional: Aktions-Text */
  actionLabel?: string
}

// ── Component ───────────────────────────────────────────────────────────────

export default function HolidayBadge({
  state,
  plz,
  lat,
  lng,
  variant = 'default',
  maxDaysAhead = 60,
  className,
  actionHref = '/dashboard/events',
  actionLabel = 'Veranstaltung planen',
}: HolidayBadgeProps) {
  const [holidays, setHolidays] = useState<Holiday[]>([])
  const [loading, setLoading]   = useState(true)

  const resolvedState: BundeslandCode = useMemo(() => {
    if (state) return state
    if (plz) return plzToBundesland(plz)
    if (lat != null && lng != null) return coordsToBundesland(lat, lng)
    return 'NATIONAL'
  }, [state, plz, lat, lng])

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetchHolidaysForCurrentAndNextYear(resolvedState).then(data => {
      if (!cancelled) {
        setHolidays(data)
        setLoading(false)
      }
    })
    return () => { cancelled = true }
  }, [resolvedState])

  const status = useMemo(() => {
    if (holidays.length === 0) return null

    const today = isHolidayToday(holidays)
    if (today) return { kind: 'today' as const, holiday: today, days: 0 }

    const tomorrow = isHolidayTomorrow(holidays)
    if (tomorrow) return { kind: 'tomorrow' as const, holiday: tomorrow, days: 1 }

    const next = getNextHoliday(holidays)
    if (next) {
      const days = daysUntilHoliday(next)
      if (days > maxDaysAhead) return null
      return { kind: 'upcoming' as const, holiday: next, days }
    }

    return null
  }, [holidays, maxDaysAhead])

  if (loading || !status) return null

  const emoji = getHolidayEmoji(status.holiday.name)
  const description = getHolidayDescription(status.holiday.name)
  const stateLabel = resolvedState !== 'NATIONAL' ? BUNDESLAND_NAMES[resolvedState] : null

  // ── Variant: compact (single line, no CTA) ───────────────────────────────
  if (variant === 'compact') {
    return (
      <CompactBadge status={status} emoji={emoji} className={className} />
    )
  }

  // ── Variant: default (full card) ─────────────────────────────────────────
  return (
    <DefaultBadge
      status={status}
      emoji={emoji}
      description={description}
      stateLabel={stateLabel}
      actionHref={actionHref}
      actionLabel={actionLabel}
      className={className}
    />
  )
}

// ── Internal: Compact ───────────────────────────────────────────────────────

function CompactBadge({
  status, emoji, className,
}: {
  status: { kind: 'today' | 'tomorrow' | 'upcoming'; holiday: Holiday; days: number }
  emoji: string
  className?: string
}) {
  const text = (() => {
    if (status.kind === 'today')    return `Heute ist ${status.holiday.name}`
    if (status.kind === 'tomorrow') return `Morgen ist ${status.holiday.name}`
    return `${status.holiday.name} in ${status.days} Tag${status.days === 1 ? '' : 'en'}`
  })()

  return (
    <div
      className={cn(
        'inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-medium',
        'bg-purple-50 border border-purple-200 text-purple-800',
        'dark:bg-purple-900/30 dark:border-purple-700 dark:text-purple-200',
        className,
      )}
      role="status"
      aria-label={text}
    >
      <span className="text-sm leading-none" aria-hidden="true">{emoji}</span>
      <span>{text}</span>
    </div>
  )
}

// ── Internal: Default (full card) ───────────────────────────────────────────

function DefaultBadge({
  status, emoji, description, stateLabel, actionHref, actionLabel, className,
}: {
  status: { kind: 'today' | 'tomorrow' | 'upcoming'; holiday: Holiday; days: number }
  emoji: string
  description: string
  stateLabel: string | null
  actionHref: string
  actionLabel: string
  className?: string
}) {
  const headline = useMemo(() => {
    if (status.kind === 'today')    return `Heute ist ${status.holiday.name}`
    if (status.kind === 'tomorrow') return `Morgen ist ${status.holiday.name}`
    return `Nächster Feiertag: ${status.holiday.name}`
  }, [status])

  const subtitle = useMemo(() => {
    if (status.kind === 'today')    return 'Schönen Feiertag! 🎉'
    if (status.kind === 'tomorrow') return 'Morgen frei – plane jetzt etwas mit deinen Nachbar:innen.'
    const date = formatDate(status.holiday.date)
    const days = `in ${status.days} Tag${status.days === 1 ? '' : 'en'}`
    return `${date} · ${days}`
  }, [status])

  const Icon = status.kind === 'today' ? PartyPopper : Calendar

  // Farbschema je nach Zeitlichkeit
  const tone = status.kind === 'today'
    ? {
        bg: 'bg-gradient-to-br from-pink-50 via-purple-50 to-pink-50',
        border: 'border-pink-200',
        iconBg: 'bg-pink-500 text-white',
        text: 'text-pink-900',
        sub: 'text-pink-700',
        dark: 'dark:from-pink-900/30 dark:via-purple-900/30 dark:to-pink-900/30 dark:border-pink-800 dark:text-pink-100 dark:[&_*]:!text-pink-100',
      }
    : status.kind === 'tomorrow'
    ? {
        bg: 'bg-gradient-to-br from-purple-50 via-violet-50 to-purple-50',
        border: 'border-purple-200',
        iconBg: 'bg-purple-500 text-white',
        text: 'text-purple-900',
        sub: 'text-purple-700',
        dark: 'dark:from-purple-900/30 dark:via-violet-900/30 dark:to-purple-900/30 dark:border-purple-800 dark:text-purple-100',
      }
    : {
        bg: 'bg-stone-50',
        border: 'border-stone-200',
        iconBg: 'bg-stone-200 text-stone-700',
        text: 'text-stone-900',
        sub: 'text-stone-500',
        dark: 'dark:bg-stone-800/40 dark:border-stone-700 dark:text-stone-100',
      }

  return (
    <article
      className={cn(
        'relative overflow-hidden rounded-2xl border p-4 sm:p-5',
        tone.bg, tone.border, tone.dark,
        className,
      )}
      role="status"
      aria-label={headline}
    >
      {/* Decorative emoji backdrop */}
      {status.kind === 'today' && (
        <div
          className="absolute -top-4 -right-2 text-7xl opacity-10 select-none pointer-events-none"
          aria-hidden="true"
        >
          {emoji}
        </div>
      )}

      <div className="relative flex items-start gap-3">
        <div className={cn(
          'flex-shrink-0 w-10 h-10 rounded-xl flex items-center justify-center shadow-sm',
          tone.iconBg,
        )}>
          <Icon className="w-5 h-5" aria-hidden="true" />
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-0.5">
            <span className="text-xl leading-none" aria-hidden="true">{emoji}</span>
            <h3 className={cn('text-sm sm:text-base font-semibold leading-tight', tone.text)}>
              {headline}
            </h3>
          </div>
          <p className={cn('text-xs sm:text-[13px] leading-relaxed', tone.sub)}>
            {subtitle}
          </p>
          {description && status.kind !== 'upcoming' && (
            <p className={cn('text-[11px] sm:text-xs mt-1.5 leading-relaxed opacity-80', tone.sub)}>
              {description}
            </p>
          )}
          {stateLabel && status.holiday.isRegional && (
            <p className={cn('text-[10px] uppercase tracking-wider mt-2 opacity-70', tone.sub)}>
              Regional · {stateLabel}
            </p>
          )}
        </div>
      </div>

      {/* CTA */}
      {(status.kind === 'tomorrow' || status.kind === 'today') && actionHref && (
        <Link
          href={actionHref}
          className={cn(
            'mt-3 sm:mt-4 group inline-flex items-center gap-1.5 text-xs sm:text-sm font-medium',
            'rounded-full px-3 py-1.5 bg-white/70 hover:bg-white border transition-colors',
            tone.border, tone.text,
            'dark:bg-stone-900/40 dark:hover:bg-stone-900/60',
          )}
        >
          <PartyPopper className="w-3.5 h-3.5" aria-hidden="true" />
          {actionLabel}
          <ArrowRight className="w-3 h-3 transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
        </Link>
      )}
    </article>
  )
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function formatDate(iso: string): string {
  const d = new Date(iso + 'T00:00:00')
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('de-DE', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  })
}
