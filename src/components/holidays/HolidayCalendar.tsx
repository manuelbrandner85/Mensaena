'use client'

// ── HolidayCalendar ───────────────────────────────────────────────────────────
// Jahreskalender mit farbig markierten Feiertagen, Monatsnavigation,
// Klick öffnet Details. Nutzt Nager.Date für internationale Unterstützung.

import { useEffect, useMemo, useState } from 'react'
import {
  ChevronLeft, ChevronRight, Calendar, X, MapPin, Info,
} from 'lucide-react'
import {
  fetchPublicHolidays,
  filterByBundesland,
  type PublicHoliday,
} from '@/lib/api/holidays-nager'
import type { BundeslandCode } from '@/lib/geo/plz-mapping'

export interface HolidayCalendarProps {
  countryCode: string
  bundesland?: BundeslandCode
  className?: string
}

const WEEKDAYS = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
const MONTHS = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
]

function daysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate()
}

/** Mo=0, So=6 für `getDay()` */
function firstWeekday(year: number, month: number): number {
  const d = new Date(year, month, 1).getDay()
  // JS: 0 = Sonntag … wir wollen Montag-basiert
  return (d + 6) % 7
}

function pad(n: number): string {
  return String(n).padStart(2, '0')
}

export function HolidayCalendar({
  countryCode,
  bundesland,
  className = '',
}: HolidayCalendarProps) {
  const today = new Date()
  const [year, setYear] = useState(today.getFullYear())
  const [month, setMonth] = useState(today.getMonth())
  const [holidays, setHolidays] = useState<PublicHoliday[]>([])
  const [selected, setSelected] = useState<PublicHoliday | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetchPublicHolidays(year, countryCode)
      .then(list => {
        if (cancelled) return
        const filtered = countryCode === 'DE' && bundesland
          ? filterByBundesland(list, bundesland)
          : list
        setHolidays(filtered)
      })
      .catch(() => { if (!cancelled) setHolidays([]) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [year, countryCode, bundesland])

  const holidayMap = useMemo(() => {
    const map = new Map<string, PublicHoliday>()
    for (const h of holidays) map.set(h.date, h)
    return map
  }, [holidays])

  const totalDays = daysInMonth(year, month)
  const firstWd = firstWeekday(year, month)
  const cells = Array.from({ length: firstWd + totalDays }, (_, i) => {
    if (i < firstWd) return null
    return i - firstWd + 1
  })

  function prev() {
    if (month === 0) { setMonth(11); setYear(y => y - 1) }
    else setMonth(m => m - 1)
  }

  function next() {
    if (month === 11) { setMonth(0); setYear(y => y + 1) }
    else setMonth(m => m + 1)
  }

  const todayIso = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`

  return (
    <section
      className={`rounded-xl border border-white/5 bg-mn-elevated p-4 dark:border-ink-700 dark:bg-ink-800 ${className}`}
      aria-label="Feiertagskalender"
    >
      {/* Header */}
      <div className="mb-3 flex items-center justify-between">
        <button
          type="button"
          onClick={prev}
          aria-label="Vorheriger Monat"
          className="rounded-lg p-1.5 text-mn-ink-soft hover:bg-mn-elevated/5 dark:text-mn-ghost dark:hover:bg-ink-700"
        >
          <ChevronLeft aria-hidden className="h-4 w-4" />
        </button>
        <h3 className="flex items-center gap-2 text-sm font-semibold text-mn-ink dark:text-stone-100">
          <Calendar aria-hidden className="h-4 w-4 text-mn-bronze" />
          {MONTHS[month]} {year}
        </h3>
        <button
          type="button"
          onClick={next}
          aria-label="Nächster Monat"
          className="rounded-lg p-1.5 text-mn-ink-soft hover:bg-mn-elevated/5 dark:text-mn-ghost dark:hover:bg-ink-700"
        >
          <ChevronRight aria-hidden className="h-4 w-4" />
        </button>
      </div>

      {/* Wochentage */}
      <div role="grid" aria-label={`${MONTHS[month]} ${year}`} className="grid grid-cols-7 gap-1">
        {WEEKDAYS.map(w => (
          <div
            key={w}
            role="columnheader"
            className="py-1 text-center text-[11px] font-medium uppercase text-mn-mute"
          >
            {w}
          </div>
        ))}

        {/* Zellen */}
        {cells.map((day, idx) => {
          if (day === null) {
            return <div key={`empty-${idx}`} role="gridcell" aria-hidden />
          }
          const iso = `${year}-${pad(month + 1)}-${pad(day)}`
          const holiday = holidayMap.get(iso)
          const isToday = iso === todayIso
          const dt = new Date(year, month, day).getDay()
          const isWeekend = dt === 0 || dt === 6
          const baseCls = 'aspect-square rounded-lg text-center text-xs flex flex-col items-center justify-center transition-colors'
          const classes = holiday
            ? 'bg-mn-bronze/5 dark:bg-primary-900/30 text-primary-900 dark:text-primary-100 hover:bg-mn-bronze/10 dark:hover:bg-primary-900/50 cursor-pointer'
            : isToday
              ? 'bg-mn-surface dark:bg-blue-900/30 text-mn-teal-soft dark:text-mn-teal-soft ring-1 ring-mn-teal/30 dark:ring-mn-teal/30'
              : isWeekend
                ? 'text-mn-mute dark:text-mn-mute'
                : 'text-mn-ink-soft dark:text-mn-ghost hover:bg-mn-elevated/5 dark:hover:bg-ink-700'

          return (
            <button
              key={iso}
              type="button"
              role="gridcell"
              aria-label={
                holiday
                  ? `${day}. ${MONTHS[month]}: ${holiday.localName}`
                  : `${day}. ${MONTHS[month]}`
              }
              onClick={() => holiday && setSelected(holiday)}
              disabled={!holiday}
              className={`${baseCls} ${classes} ${!holiday ? 'cursor-default' : ''}`}
            >
              <span className="font-medium">{day}</span>
              {holiday && (
                <span className="mt-0.5 h-1.5 w-1.5 rounded-full bg-mn-bronze" aria-hidden />
              )}
            </button>
          )
        })}
      </div>

      {loading && (
        <p className="mt-3 text-center text-xs text-mn-mute">Lade Feiertage…</p>
      )}

      {/* Detail-Modal */}
      {selected && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={selected.localName}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          onClick={() => setSelected(null)}
        >
          <div
            className="w-full max-w-md rounded-xl bg-mn-elevated p-5 shadow-xl dark:bg-ink-800"
            onClick={e => e.stopPropagation()}
          >
            <div className="mb-3 flex items-start justify-between">
              <h4 className="text-base font-semibold text-mn-ink dark:text-stone-100">
                {selected.localName}
              </h4>
              <button
                type="button"
                aria-label="Schließen"
                onClick={() => setSelected(null)}
                className="rounded-md p-1 text-mn-mute hover:bg-mn-elevated/5 dark:hover:bg-ink-700"
              >
                <X aria-hidden className="h-4 w-4" />
              </button>
            </div>
            <dl className="space-y-2 text-sm text-mn-ink-soft dark:text-mn-ghost">
              <div className="flex items-center gap-2">
                <Calendar aria-hidden className="h-4 w-4 text-mn-mute" />
                <span>{new Intl.DateTimeFormat('de-DE', { dateStyle: 'full' }).format(new Date(selected.date + 'T00:00:00'))}</span>
              </div>
              <div className="flex items-center gap-2">
                <MapPin aria-hidden className="h-4 w-4 text-mn-mute" />
                <span>
                  {selected.isNational ? 'Bundesweit' : `Regional: ${selected.counties?.join(', ') ?? '–'}`}
                </span>
              </div>
              {selected.name !== selected.localName && (
                <div className="flex items-center gap-2">
                  <Info aria-hidden className="h-4 w-4 text-mn-mute" />
                  <span>{selected.name}</span>
                </div>
              )}
              <div className="flex flex-wrap gap-1 pt-1">
                {selected.types.map(t => (
                  <span
                    key={t}
                    className="rounded-full bg-mn-elevated px-2 py-0.5 text-[11px] text-mn-ink-soft dark:bg-ink-700 dark:text-mn-ghost"
                  >
                    {t}
                  </span>
                ))}
              </div>
            </dl>
          </div>
        </div>
      )}
    </section>
  )
}

export default HolidayCalendar
