'use client'

// ── HolidayWidget ─────────────────────────────────────────────────────────────
// Compact: Countdown bis zum nächsten Feiertag.
// Voll:    Timeline der nächsten Feiertage des Jahres, Brückentage hervorgehoben.

import { useEffect, useState } from 'react'
import { Calendar, PartyPopper, Palmtree, Clock, AlertCircle } from 'lucide-react'
import {
  fetchNextHolidays, fetchLongWeekends,
  type PublicHoliday, type LongWeekend,
} from '@/lib/api/holidays-nager'
import type { BundeslandCode } from '@/lib/geo/plz-mapping'
import { filterByBundesland } from '@/lib/api/holidays-nager'

export interface HolidayWidgetProps {
  countryCode: string
  bundesland?: BundeslandCode
  compact?: boolean
  className?: string
}

function daysUntil(isoDate: string): number {
  const target = new Date(isoDate + 'T00:00:00')
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  return Math.round((target.getTime() - now.getTime()) / (24 * 60 * 60 * 1000))
}

function formatDate(isoDate: string): string {
  try {
    const d = new Date(isoDate + 'T00:00:00')
    return new Intl.DateTimeFormat('de-DE', { day: '2-digit', month: 'short', weekday: 'short' }).format(d)
  } catch {
    return isoDate
  }
}

export function HolidayWidget({
  countryCode,
  bundesland,
  compact = false,
  className = '',
}: HolidayWidgetProps) {
  const [holidays, setHolidays] = useState<PublicHoliday[]>([])
  const [longWeekends, setLongWeekends] = useState<LongWeekend[]>([])
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    let cancelled = false
    const year = new Date().getFullYear()
    Promise.all([
      fetchNextHolidays(countryCode),
      fetchLongWeekends(year, countryCode),
    ])
      .then(([next, lw]) => {
        if (cancelled) return
        const filtered = countryCode === 'DE' && bundesland
          ? filterByBundesland(next, bundesland)
          : next
        setHolidays(filtered)
        setLongWeekends(lw)
      })
      .catch(() => {
        if (!cancelled) {
          setHolidays([])
          setLongWeekends([])
        }
      })
      .finally(() => { if (!cancelled) setLoaded(true) })
    return () => { cancelled = true }
  }, [countryCode, bundesland])

  if (!loaded) {
    return (
      <div
        role="status"
        aria-label="Feiertage werden geladen"
        className={`animate-pulse rounded-xl border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800 ${className}`}
      >
        <div className="mb-2 h-4 w-32 rounded bg-gray-200 dark:bg-gray-700" />
        <div className="h-8 w-48 rounded bg-gray-200 dark:bg-gray-700" />
      </div>
    )
  }

  if (holidays.length === 0) {
    return (
      <div
        role="status"
        className={`flex items-center gap-2 rounded-xl border border-gray-200 bg-white px-4 py-3 text-sm text-gray-600 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-300 ${className}`}
      >
        <AlertCircle aria-hidden className="h-4 w-4 text-gray-400" />
        <span>Keine Feiertage gefunden.</span>
      </div>
    )
  }

  const next = holidays[0]
  const days = daysUntil(next.date)

  if (compact) {
    return (
      <div
        className={`flex items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-3 dark:border-gray-700 dark:bg-gray-800 ${className}`}
        aria-label={`Nächster Feiertag: ${next.localName} in ${days} Tagen`}
      >
        <PartyPopper aria-hidden className="h-5 w-5 text-amber-500" />
        <div className="flex flex-col leading-tight">
          <span className="text-xs text-gray-500 dark:text-gray-400">Nächster Feiertag</span>
          <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
            {next.localName}
          </span>
          <span className="text-xs text-gray-500 dark:text-gray-400">
            {days === 0 ? 'heute' : days === 1 ? 'morgen' : `in ${days} Tagen`} · {formatDate(next.date)}
          </span>
        </div>
      </div>
    )
  }

  // Voll-Modus: Timeline + Brückentage
  const longWeekendDates = new Set(longWeekends.flatMap(lw => [lw.startDate, lw.endDate]))

  return (
    <section
      className={`rounded-xl border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800 ${className}`}
      aria-label="Feiertage"
    >
      <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-gray-900 dark:text-gray-100">
        <Calendar aria-hidden className="h-4 w-4 text-primary-500" />
        Feiertage
      </h3>
      <ul className="space-y-1.5">
        {holidays.slice(0, 8).map(h => {
          const d = daysUntil(h.date)
          const isBridge = longWeekendDates.has(h.date) || longWeekends.some(lw => lw.needBridgeDay && lw.startDate <= h.date && lw.endDate >= h.date)
          return (
            <li
              key={h.date + h.localName}
              className={`flex items-center gap-3 rounded-lg px-2 py-1.5 ${isBridge ? 'bg-amber-50 dark:bg-amber-950/30' : ''}`}
            >
              <span className="w-20 text-xs text-gray-500 dark:text-gray-400">
                {formatDate(h.date)}
              </span>
              <span className="flex-1 text-sm text-gray-900 dark:text-gray-100">
                {h.localName}
              </span>
              {isBridge && (
                <span className="flex items-center gap-1 text-[11px] font-medium text-amber-700 dark:text-amber-300">
                  <Palmtree aria-hidden className="h-3 w-3" />
                  Brückentag
                </span>
              )}
              <span className="flex items-center gap-1 text-[11px] text-gray-500 dark:text-gray-400">
                <Clock aria-hidden className="h-3 w-3" />
                {d === 0 ? 'heute' : d === 1 ? 'morgen' : `${d} T.`}
              </span>
            </li>
          )
        })}
      </ul>
      <p className="mt-3 text-[11px] text-gray-400 dark:text-gray-500">
        Daten: Nager.Date
      </p>
    </section>
  )
}

export default HolidayWidget
