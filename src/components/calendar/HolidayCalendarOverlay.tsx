'use client'

// ─────────────────────────────────────────────────────────────────────────────
// HolidayCalendarOverlay – Feiertage als farbige Markierungen im Event-Kalender
//
// Verwendung:
//   <HolidayCalendarOverlay
//     activeMonth={activeMonth}
//     state={state}        // optional, wird sonst aus plz/coords abgeleitet
//     plz={profile.plz}
//     lat={profile.latitude}
//     lng={profile.longitude}
//   />
//
// Liefert:
//   - useHolidayMap(): Map<dateKey, Holiday[]> für Integration in eigene Day-Cells
//   - <HolidayCalendarOverlay/>: rendert eigene Pille pro Feiertag im Monat
//   - <HolidayDayMarker date={...}/>: kleines Inline-Marker-Element
//   - <HolidayDetailDialog holiday={...}/>: Modal mit Details + CTA "Plane Aktion!"
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import { X, Calendar, PartyPopper, MapPin, ArrowRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchHolidaysForCurrentAndNextYear,
  getHolidayEmoji,
  getHolidayDescription,
  plzToBundesland,
  coordsToBundesland,
  BUNDESLAND_NAMES,
  type Holiday,
  type BundeslandCode,
} from '@/lib/api/holidays'

// ── Hook: liefert Map<dateKey, Holiday[]> ────────────────────────────────────

/**
 * Fetched alle Feiertage für aktuelles + nächstes Jahr und liefert
 * sie als Map (key = "YYYY-M-D" lokal) für effizienten Day-Lookup.
 */
export function useHolidayMap(state: BundeslandCode = 'NATIONAL') {
  const [holidays, setHolidays] = useState<Holiday[]>([])
  const [loading, setLoading]   = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetchHolidaysForCurrentAndNextYear(state).then(data => {
      if (!cancelled) {
        setHolidays(data)
        setLoading(false)
      }
    })
    return () => { cancelled = true }
  }, [state])

  const map = useMemo(() => {
    const m = new Map<string, Holiday>()
    for (const h of holidays) {
      const d = new Date(h.date + 'T00:00:00')
      const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
      m.set(key, h)
    }
    return m
  }, [holidays])

  return { holidays, holidayMap: map, loading }
}

// ── Standalone Marker (fürs Day-Cell) ────────────────────────────────────────

interface HolidayDayMarkerProps {
  date: Date
  holiday: Holiday
  /** Klein-Variante (Mobile) ohne Text */
  compact?: boolean
  onClick?: (holiday: Holiday) => void
}

/**
 * Kleines Marker-Element für eine Tageszelle im Kalender.
 * Lila/Pink je nach regional vs. bundesweit – passt zum Design der EventCalendarDay.
 */
export function HolidayDayMarker({
  holiday, compact = false, onClick,
}: HolidayDayMarkerProps) {
  const emoji = getHolidayEmoji(holiday.name)
  const isRegional = holiday.isRegional

  const tone = isRegional
    ? 'bg-pink-100 text-pink-800 border-pink-300 hover:bg-pink-200'
    : 'bg-purple-100 text-purple-800 border-purple-300 hover:bg-purple-200'

  if (compact) {
    return (
      <button
        type="button"
        onClick={onClick ? (e) => { e.stopPropagation(); onClick(holiday) } : undefined}
        className={cn(
          'inline-flex items-center justify-center w-4 h-4 rounded-full text-[10px] leading-none border',
          tone,
        )}
        aria-label={`Feiertag: ${holiday.name}`}
        title={holiday.name}
      >
        <span aria-hidden="true">{emoji}</span>
      </button>
    )
  }

  return (
    <button
      type="button"
      onClick={onClick ? (e) => { e.stopPropagation(); onClick(holiday) } : undefined}
      className={cn(
        'flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium leading-none border w-full overflow-hidden',
        tone,
      )}
      aria-label={`Feiertag: ${holiday.name}`}
      title={holiday.name}
    >
      <span className="flex-shrink-0" aria-hidden="true">{emoji}</span>
      <span className="truncate">{holiday.name}</span>
    </button>
  )
}

// ── Standalone Pille pro Feiertag im aktiven Monat ──────────────────────────

interface HolidayCalendarOverlayProps {
  /** Aktiver Monat des Kalenders (zur Filterung) */
  activeMonth: Date
  /** Bundesland-Code (Vorrang vor PLZ/coords) */
  state?: BundeslandCode
  /** PLZ aus Profil */
  plz?: string | null
  /** Geo-Koordinaten als Fallback */
  lat?: number | null
  lng?: number | null
  /** Callback wenn auf einen Feiertag geklickt wird */
  onSelect?: (holiday: Holiday) => void
  className?: string
}

/**
 * Liste aller Feiertage im aktiven Monat als horizontale Pillen-Leiste.
 * Wird unter dem Kalender-Grid platziert und gibt einen Überblick.
 */
export default function HolidayCalendarOverlay({
  activeMonth, state, plz, lat, lng, onSelect, className,
}: HolidayCalendarOverlayProps) {
  const [openDetail, setOpenDetail] = useState<Holiday | null>(null)

  const resolvedState: BundeslandCode = useMemo(() => {
    if (state) return state
    if (plz) return plzToBundesland(plz)
    if (lat != null && lng != null) return coordsToBundesland(lat, lng)
    return 'NATIONAL'
  }, [state, plz, lat, lng])

  const { holidays, loading } = useHolidayMap(resolvedState)

  const monthHolidays = useMemo(() => {
    if (loading) return []
    const y = activeMonth.getFullYear()
    const m = activeMonth.getMonth()
    return holidays.filter(h => {
      const d = new Date(h.date + 'T00:00:00')
      return d.getFullYear() === y && d.getMonth() === m
    })
  }, [holidays, activeMonth, loading])

  if (loading || monthHolidays.length === 0) return null

  const handleSelect = (h: Holiday) => {
    if (onSelect) onSelect(h)
    else setOpenDetail(h)
  }

  return (
    <>
      <section
        className={cn(
          'mt-4 rounded-2xl border border-purple-100 bg-purple-50/40 p-3 sm:p-4',
          'dark:bg-purple-900/10 dark:border-purple-800/50',
          className,
        )}
        aria-label="Feiertage in diesem Monat"
      >
        <header className="flex items-center gap-2 mb-2.5">
          <Calendar className="w-3.5 h-3.5 text-purple-600 dark:text-purple-400" aria-hidden="true" />
          <span className="text-[11px] uppercase tracking-wider font-semibold text-purple-700 dark:text-purple-300">
            Feiertage in diesem Monat
          </span>
          {resolvedState !== 'NATIONAL' && (
            <span className="text-[10px] text-purple-600/70 dark:text-purple-400/70 ml-auto">
              {BUNDESLAND_NAMES[resolvedState]}
            </span>
          )}
        </header>

        <div className="flex flex-wrap gap-1.5">
          {monthHolidays.map(h => (
            <HolidayPill key={h.date + h.name} holiday={h} onClick={handleSelect} />
          ))}
        </div>

        <p className="text-[10px] text-purple-600/60 dark:text-purple-400/60 mt-3 leading-relaxed">
          <span className="inline-block w-2 h-2 rounded-full bg-purple-300 mr-1 align-middle" />
          Bundesweit
          <span className="inline-block w-2 h-2 rounded-full bg-pink-300 mr-1 ml-3 align-middle" />
          Regional
        </p>
      </section>

      {/* Detail Modal */}
      {openDetail && (
        <HolidayDetailDialog
          holiday={openDetail}
          stateLabel={BUNDESLAND_NAMES[resolvedState]}
          onClose={() => setOpenDetail(null)}
        />
      )}
    </>
  )
}

// ── Internal: Pille pro Feiertag im Monat ────────────────────────────────────

function HolidayPill({
  holiday, onClick,
}: {
  holiday: Holiday
  onClick: (h: Holiday) => void
}) {
  const emoji = getHolidayEmoji(holiday.name)
  const day = new Date(holiday.date + 'T00:00:00').getDate()

  const tone = holiday.isRegional
    ? 'bg-pink-100 hover:bg-pink-200 border-pink-200 text-pink-800 dark:bg-pink-900/30 dark:border-pink-800 dark:text-pink-200'
    : 'bg-purple-100 hover:bg-purple-200 border-purple-200 text-purple-800 dark:bg-purple-900/30 dark:border-purple-800 dark:text-purple-200'

  return (
    <button
      type="button"
      onClick={() => onClick(holiday)}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors',
        tone,
      )}
      aria-label={`Feiertag-Details für ${holiday.name}`}
    >
      <span className="text-sm leading-none" aria-hidden="true">{emoji}</span>
      <span className="font-semibold tabular-nums">{day}.</span>
      <span>{holiday.name}</span>
    </button>
  )
}

// ── Detail Modal ────────────────────────────────────────────────────────────

interface HolidayDetailDialogProps {
  holiday: Holiday
  stateLabel?: string
  onClose: () => void
  /** Optionaler Aktions-Pfad (Standard: Event-Erstellung) */
  actionHref?: string
}

/**
 * Modal mit Details + Vorschlag "Plane eine Nachbarschaftsaktion!".
 */
export function HolidayDetailDialog({
  holiday, stateLabel, onClose, actionHref = '/dashboard/events/create',
}: HolidayDetailDialogProps) {
  const emoji = getHolidayEmoji(holiday.name)
  const description = getHolidayDescription(holiday.name)
  const dateLabel = formatLongDate(holiday.date)

  // Schließen mit ESC
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  // Action-URL mit Datum als Query-Parameter
  const planUrl = `${actionHref}?date=${holiday.date}&title=${encodeURIComponent(`${emoji} ${holiday.name}`)}`

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="holiday-dialog-title"
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4"
    >
      {/* Backdrop */}
      <button
        type="button"
        aria-label="Schließen"
        onClick={onClose}
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
      />

      {/* Dialog */}
      <div
        className={cn(
          'relative w-full max-w-md bg-white dark:bg-stone-900 rounded-t-3xl sm:rounded-3xl shadow-2xl overflow-hidden',
          'animate-in slide-in-from-bottom-4 sm:zoom-in-95 duration-300',
        )}
      >
        {/* Header gradient */}
        <div className={cn(
          'relative px-6 py-8 text-center overflow-hidden',
          holiday.isRegional
            ? 'bg-gradient-to-br from-pink-50 via-pink-100 to-purple-100 dark:from-pink-900/40 dark:via-pink-900/30 dark:to-purple-900/40'
            : 'bg-gradient-to-br from-purple-50 via-purple-100 to-violet-100 dark:from-purple-900/40 dark:via-purple-900/30 dark:to-violet-900/40',
        )}>
          <button
            onClick={onClose}
            aria-label="Schließen"
            className="absolute top-3 right-3 p-2 rounded-full hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
          >
            <X className="w-4 h-4 text-stone-700 dark:text-stone-300" />
          </button>

          <div className="text-6xl leading-none mb-3" aria-hidden="true">{emoji}</div>
          <h3 id="holiday-dialog-title" className="font-display text-2xl text-stone-900 dark:text-stone-100 leading-tight">
            {holiday.name}
          </h3>
          <p className="text-sm text-stone-600 dark:text-stone-400 mt-1">{dateLabel}</p>
        </div>

        {/* Body */}
        <div className="p-6 space-y-4">
          <p className="text-sm text-stone-700 dark:text-stone-300 leading-relaxed">
            {description}
          </p>

          {/* Meta info */}
          <div className="flex flex-wrap gap-2">
            <span className={cn(
              'inline-flex items-center gap-1 text-[11px] uppercase tracking-wider font-semibold px-2 py-1 rounded-full',
              holiday.isRegional
                ? 'bg-pink-100 text-pink-800 dark:bg-pink-900/40 dark:text-pink-200'
                : 'bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-200',
            )}>
              {holiday.isRegional ? 'Regional' : 'Bundesweit'}
            </span>
            {stateLabel && (
              <span className="inline-flex items-center gap-1 text-[11px] text-stone-500 dark:text-stone-400 px-2 py-1">
                <MapPin className="w-3 h-3" aria-hidden="true" />
                {stateLabel}
              </span>
            )}
            {holiday.note && (
              <span className="text-[11px] text-stone-500 dark:text-stone-400 px-2 py-1 italic">
                {holiday.note}
              </span>
            )}
          </div>

          {/* Suggestion CTA */}
          <div className="bg-gradient-to-br from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 border border-purple-200 dark:border-purple-800/50 rounded-2xl p-4">
            <div className="flex items-start gap-3 mb-3">
              <div className="flex-shrink-0 w-9 h-9 rounded-full bg-white dark:bg-stone-800 border border-purple-200 dark:border-purple-700 flex items-center justify-center">
                <PartyPopper className="w-4 h-4 text-purple-600 dark:text-purple-400" aria-hidden="true" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-stone-900 dark:text-stone-100 leading-tight mb-1">
                  Plane eine Nachbarschaftsaktion!
                </p>
                <p className="text-xs text-stone-600 dark:text-stone-400 leading-relaxed">
                  Feiertage sind ideal für Begegnungen. Lade deine Nachbar:innen
                  zu einem Picknick, Brunch oder Spaziergang ein.
                </p>
              </div>
            </div>
            <Link
              href={planUrl}
              onClick={onClose}
              className={cn(
                'group flex items-center justify-center gap-2 w-full bg-purple-600 hover:bg-purple-700',
                'text-white text-sm font-medium rounded-full px-4 py-2.5 transition-colors',
              )}
            >
              <Calendar className="w-4 h-4" aria-hidden="true" />
              Veranstaltung erstellen
              <ArrowRight className="w-3.5 h-3.5 transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function formatLongDate(iso: string): string {
  const d = new Date(iso + 'T00:00:00')
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('de-DE', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  })
}

// ── Re-exports for convenience ──────────────────────────────────────────────

export type { Holiday, BundeslandCode } from '@/lib/api/holidays'
