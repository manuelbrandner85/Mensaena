'use client'

import { useState, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import {
  Trash2, Settings2, RefreshCw, AlertCircle, PartyPopper,
  Users, Loader2, Bell,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchTermine, getNextTermine, formatAbfallDate, groupByDate,
  FRAKTIONEN_INFO,
  type AbfallTermin, type NextTermine,
} from '@/lib/api/abfallnavi'
import {
  loadWasteSettings, type WasteSettings,
} from './WasteSetupWizard'
import WasteReminderToggle from './WasteReminderToggle'
import dynamic from 'next/dynamic'

const WasteSetupWizard = dynamic(() => import('./WasteSetupWizard'), { ssr: false })

// ─── Fraktion chip ────────────────────────────────────────────────────────────

function FraktionChip({ fraktion, small }: { fraktion: string; small?: boolean }) {
  const info = FRAKTIONEN_INFO[fraktion] ?? {
    label: fraktion,
    emoji: '♻️',
    bgColor: 'bg-gray-100',
    textColor: 'text-gray-700',
    borderColor: 'border-gray-200',
  }
  return (
    <span
      aria-label={`${info.label} Abfuhrtermin`}
      className={cn(
        'inline-flex items-center gap-1 rounded-full border font-medium',
        info.bgColor, info.textColor, info.borderColor,
        small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs',
      )}
    >
      <span>{info.emoji}</span>
      <span>{info.label}</span>
    </span>
  )
}

// ─── Today / Tomorrow banner ──────────────────────────────────────────────────

function UrgentBanner({ termine, label, pulse }: { termine: AbfallTermin[]; label: string; pulse?: boolean }) {
  if (termine.length === 0) return null
  return (
    <div className="space-y-1.5">
      <p className="text-xs font-bold text-gray-500 uppercase tracking-wide">{label}</p>
      <div className="flex flex-wrap gap-2">
        {termine.map((t, i) => {
          const info = FRAKTIONEN_INFO[t.fraktion]
          if (!info) return null
          return (
            <div
              key={i}
              className={cn(
                'flex items-center gap-2 px-3 py-2 rounded-xl border font-semibold text-sm flex-shrink-0',
                info.bgColor, info.textColor, info.borderColor,
              )}
            >
              {pulse && (
                <span className="relative flex h-2.5 w-2.5 flex-shrink-0">
                  <span className={cn('absolute inline-flex h-full w-full rounded-full opacity-75 animate-ping', info.dotColor ?? 'bg-current')} />
                  <span className={cn('relative inline-flex h-2.5 w-2.5 rounded-full', info.dotColor ?? 'bg-current')} />
                </span>
              )}
              <span>{info.emoji}</span>
              <span>{info.label}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ─── Week row ────────────────────────────────────────────────────────────────

function WeekRow({ date, termine }: { date: string; termine: AbfallTermin[] }) {
  return (
    <div className="flex items-start gap-3 py-2">
      <span className="text-xs text-gray-500 whitespace-nowrap w-20 flex-shrink-0 pt-1">
        {formatAbfallDate(date)}
      </span>
      <div className="flex flex-wrap gap-1">
        {termine.map((t, i) => <FraktionChip key={i} fraktion={t.fraktion} small />)}
      </div>
    </div>
  )
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function Skeleton() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-3 w-16 bg-gray-100 rounded" />
      <div className="flex gap-2">
        <div className="h-9 w-28 bg-gray-100 rounded-xl" />
        <div className="h-9 w-24 bg-gray-100 rounded-xl" />
      </div>
      <div className="space-y-2">
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex gap-3">
            <div className="h-4 w-20 bg-gray-100 rounded" />
            <div className="h-4 w-16 bg-gray-100 rounded-full" />
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── Not-configured empty state ───────────────────────────────────────────────

function NotConfigured({ onSetup }: { onSetup: () => void }) {
  return (
    <div className="flex flex-col items-center py-6 text-center gap-4">
      <div className="w-14 h-14 rounded-2xl bg-gray-50 border border-gray-200 flex items-center justify-center">
        <Trash2 className="w-6 h-6 text-gray-400" />
      </div>
      <div>
        <p className="text-sm font-semibold text-gray-700">Mülltermine noch nicht eingerichtet</p>
        <p className="text-xs text-gray-400 mt-1">Verbinde deine Adresse mit dem Abfallkalender</p>
      </div>
      <button
        onClick={onSetup}
        className="flex items-center gap-2 px-4 py-2.5 bg-primary-600 text-white rounded-xl text-sm font-semibold hover:bg-primary-700 transition-colors shadow-sm"
      >
        <Settings2 className="w-4 h-4" />
        Jetzt einrichten
      </button>
    </div>
  )
}

// ─── Main Widget ─────────────────────────────────────────────────────────────

export default function WasteScheduleWidget() {
  const router = useRouter()

  const [mounted, setMounted] = useState(false)
  const [settings, setSettings] = useState<WasteSettings | null>(null)
  const [termine, setTermine] = useState<AbfallTermin[]>([])
  const [next, setNext] = useState<NextTermine | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showWizard, setShowWizard] = useState(false)
  const [showReminder, setShowReminder] = useState(false)
  const [neighborPosting, setNeighborPosting] = useState(false)

  // ── Load settings from localStorage ──
  useEffect(() => {
    setMounted(true)
    const s = loadWasteSettings()
    setSettings(s)
  }, [])

  // ── Fetch termine when settings available ──
  const loadTermine = useCallback(async (s: WasteSettings) => {
    setLoading(true)
    setError('')
    try {
      const data = await fetchTermine(s.region, s.hausnummerId)
      setTermine(data)
      setNext(getNextTermine(data))
    } catch {
      setError('Termine konnten nicht geladen werden. Bitte später versuchen.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (settings) loadTermine(settings)
  }, [settings, loadTermine])

  // ── Wizard complete ──
  const handleWizardComplete = useCallback((newSettings: WasteSettings) => {
    setSettings(newSettings)
    setShowWizard(false)
  }, [])

  // ── Neighbor post ──
  const handleNeighborPost = useCallback(() => {
    if (!next) return
    const tomorrowTermine = next.tomorrow
    if (tomorrowTermine.length === 0) return
    const fraktionLabels = tomorrowTermine
      .map((t) => FRAKTIONEN_INFO[t.fraktion]?.label ?? t.fraktion)
      .join(', ')
    const date = tomorrowTermine[0]?.date ?? ''
    // Navigate to create page with pre-filled offer
    const params = new URLSearchParams({
      type: 'offer',
      category: 'everyday',
      title: `Kann morgen eure ${fraktionLabels}-Tonne rausstellen`,
      description: `Ich stelle am ${formatAbfallDate(date)} die Tonne(n) für euch raus – meldet euch einfach!`,
      urgency: 'low',
    })
    setNeighborPosting(true)
    router.push(`/dashboard/create?${params}`)
  }, [next, router])

  // ── Guard: SSR ──
  if (!mounted) return null

  // ── Widget card ──
  const hasToday = (next?.today?.length ?? 0) > 0
  const hasTomorrow = (next?.tomorrow?.length ?? 0) > 0
  const hasThisWeek = (next?.thisWeek?.length ?? 0) > 0

  const weekByDate = next ? groupByDate([...next.thisWeek]) : new Map<string, AbfallTermin[]>()

  return (
    <>
      <div className="card p-4 space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-green-50 border border-green-100 flex items-center justify-center">
              <Trash2 className="w-4 h-4 text-green-700" />
            </div>
            <div>
              <p className="text-sm font-semibold text-gray-900">Müllabfuhr</p>
              {settings && (
                <p className="text-[10px] text-gray-400 truncate max-w-[160px]">
                  {settings.strasseName} {settings.hausnummerName}, {settings.ortName}
                </p>
              )}
            </div>
          </div>

          <div className="flex items-center gap-1">
            {settings && (
              <>
                <button
                  onClick={() => setShowReminder((r) => !r)}
                  aria-label="Erinnerungen"
                  className={cn(
                    'p-1.5 rounded-lg transition-colors',
                    showReminder ? 'bg-amber-100 text-amber-600' : 'text-gray-400 hover:bg-gray-100',
                  )}
                >
                  <Bell className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={() => loadTermine(settings)}
                  disabled={loading}
                  aria-label="Aktualisieren"
                  className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 transition-colors"
                >
                  <RefreshCw className={cn('w-3.5 h-3.5', loading && 'animate-spin')} />
                </button>
              </>
            )}
            <button
              onClick={() => setShowWizard(true)}
              aria-label="Einstellungen"
              className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 transition-colors"
            >
              <Settings2 className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Reminder toggle (expandable) */}
        {showReminder && settings && (
          <div className="animate-slide-down">
            <WasteReminderToggle />
          </div>
        )}

        {/* Content */}
        {!settings ? (
          <NotConfigured onSetup={() => setShowWizard(true)} />
        ) : loading ? (
          <Skeleton />
        ) : error ? (
          <div className="flex items-start gap-2 text-sm text-red-600 bg-red-50 rounded-xl p-3">
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Today */}
            {hasToday && (
              <UrgentBanner
                termine={next!.today}
                label="⚠️ HEUTE ABHOLEN"
                pulse
              />
            )}

            {/* Tomorrow */}
            {hasTomorrow && (
              <UrgentBanner
                termine={next!.tomorrow}
                label="Morgen rausstellen"
              />
            )}

            {/* This week */}
            {hasThisWeek && (
              <div>
                <p className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                  Diese Woche
                </p>
                <div className="divide-y divide-gray-50">
                  {Array.from(weekByDate.entries()).map(([date, t]) => (
                    <WeekRow key={date} date={date} termine={t} />
                  ))}
                </div>
              </div>
            )}

            {/* No pickups */}
            {!hasToday && !hasTomorrow && !hasThisWeek && (
              <div className="flex items-center gap-2 py-4 text-center justify-center">
                <PartyPopper className="w-5 h-5 text-gray-400" />
                <p className="text-sm text-gray-500">Diese Woche keine Abfuhr 🎉</p>
              </div>
            )}

            {/* Loading indicator for more termine */}
            {termine.length > 0 && (
              <p className="text-[10px] text-gray-300 text-right">
                {termine.length} Termine geladen
              </p>
            )}
          </div>
        )}

        {/* Nachbarschafts-Button (only when tomorrow has termine) */}
        {settings && hasTomorrow && !loading && !error && (
          <div className="pt-1 border-t border-gray-50">
            <button
              onClick={handleNeighborPost}
              disabled={neighborPosting}
              className="w-full flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-medium text-gray-500 hover:bg-green-50 hover:text-green-700 border border-dashed border-gray-200 hover:border-green-300 transition-all"
              aria-label="Nachbarn anbieten, ihre Tonne rauszustellen"
            >
              {neighborPosting ? (
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Users className="w-3.5 h-3.5" />
              )}
              Tonne rausstellen für Nachbarn anbieten
            </button>
          </div>
        )}
      </div>

      {/* Setup Wizard */}
      {showWizard && (
        <WasteSetupWizard
          onClose={() => setShowWizard(false)}
          onComplete={handleWizardComplete}
          initial={settings}
        />
      )}
    </>
  )
}
