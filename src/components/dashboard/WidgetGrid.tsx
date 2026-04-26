'use client'

import { useState, useRef, useEffect } from 'react'
import dynamic from 'next/dynamic'
import {
  ChevronDown, ChevronUp, MoreVertical,
  ArrowUp, ArrowDown, EyeOff, Settings2,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  useDashboardWidgetStore,
  WIDGET_META,
  CRITICAL_IDS,
  type WidgetId,
} from '@/stores/dashboardWidgetStore'

// ── Profile subset ────────────────────────────────────────────────────────────

export interface WidgetGridProfile {
  latitude?: number | null
  longitude?: number | null
}

// ── Lazy-loaded widgets ───────────────────────────────────────────────────────

const sk = <div className="h-28 rounded-2xl bg-stone-100 animate-pulse m-3" />

const WeatherAlertBanner = dynamic(
  () => import('@/components/warnings/WeatherAlertBanner'),
  { ssr: false, loading: () => null },
)
const WeatherWidget = dynamic(
  () => import('@/app/dashboard/components/WeatherWidget'),
  { ssr: false, loading: () => sk },
)
const PollenWidget = dynamic(
  () => import('@/components/environment/PollenWidget'),
  { ssr: false, loading: () => sk },
)
const WaterLevelWidget = dynamic(
  () => import('@/components/water/WaterLevelWidget'),
  { ssr: false, loading: () => sk },
)
const HolidayBadge = dynamic(
  () => import('@/components/calendar/HolidayBadge'),
  { ssr: false, loading: () => sk },
)
const TrafficWidget = dynamic(
  () => import('@/components/traffic/TrafficWidget'),
  { ssr: false, loading: () => sk },
)
const JobsNearbyWidget = dynamic(
  () => import('@/components/jobs/JobsNearbyWidget'),
  { ssr: false, loading: () => sk },
)
const EducationWidget = dynamic(
  () => import('@/components/education/EducationWidget'),
  { ssr: false, loading: () => sk },
)
const DidYouKnowWidget = dynamic(
  () => import('@/components/knowledge/DidYouKnowWidget'),
  { ssr: false, loading: () => sk },
)
const HistoricalGallery = dynamic(
  () => import('@/components/knowledge/HistoricalGallery'),
  { ssr: false, loading: () => sk },
)

// ── Widget content renderer ───────────────────────────────────────────────────

function WidgetContent({ id, profile }: { id: WidgetId; profile: WidgetGridProfile | null }) {
  const lat = profile?.latitude ?? undefined
  const lng = profile?.longitude ?? undefined

  switch (id) {
    case 'weather-alert':
      return <WeatherAlertBanner lat={lat} lng={lng} />
    case 'weather':
      if (!lat || !lng)
        return <p className="px-4 py-6 text-xs text-gray-400 text-center">Kein Standort gesetzt – bitte im Profil hinterlegen.</p>
      return <WeatherWidget lat={lat} lng={lng} />
    case 'pollen':
      return <PollenWidget compact />
    case 'water-level':
      return <WaterLevelWidget />
    case 'holiday':
      return <HolidayBadge lat={lat} lng={lng} variant="default" />
    case 'traffic':
      return <TrafficWidget />
    case 'jobs':
      return <JobsNearbyWidget />
    case 'education':
      return <EducationWidget compact />
    case 'did-you-know':
      return <DidYouKnowWidget />
    case 'historical':
      return (
        <HistoricalGallery
          historicalMode
          compact
          limit={6}
          title="Historisches Foto des Tages"
        />
      )
    default:
      return null
  }
}

// ── Widget wrapper ────────────────────────────────────────────────────────────

interface WrapperProps {
  id: WidgetId
  profile: WidgetGridProfile | null
  /** Index within the non-critical ordered list, used for move button states */
  moveableIdx: number
  moveableCount: number
  onOpenSettings: () => void
}

function WidgetWrapper({ id, profile, moveableIdx, moveableCount, onOpenSettings }: WrapperProps) {
  const { collapsedWidgets, collapseWidget, expandWidget, moveWidget, toggleWidget } =
    useDashboardWidgetStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  const meta = WIDGET_META.find(w => w.id === id)!
  const isCritical = CRITICAL_IDS.has(id)
  const isCollapsed = collapsedWidgets.includes(id)
  const isFirst = moveableIdx === 0
  const isLast = moveableIdx === moveableCount - 1

  useEffect(() => {
    if (!menuOpen) return
    const h = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false)
    }
    document.addEventListener('mousedown', h)
    return () => document.removeEventListener('mousedown', h)
  }, [menuOpen])

  return (
    <div
      className={cn(
        'bg-white rounded-2xl border shadow-soft overflow-hidden',
        isCritical ? 'border-red-200' : 'border-stone-200',
      )}
    >
      {/* Header */}
      <div
        className={cn(
          'flex items-center justify-between px-3.5 py-2.5 border-b',
          isCritical ? 'border-red-100 bg-red-50/60' : 'border-stone-100 bg-stone-50/60',
        )}
      >
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-base flex-shrink-0">{meta.emoji}</span>
          <span
            className={cn(
              'text-xs font-semibold truncate',
              isCritical ? 'text-red-800' : 'text-gray-800',
            )}
          >
            {meta.title}
          </span>
        </div>

        <div className="flex items-center gap-0.5">
          {/* Collapse toggle */}
          <button
            onClick={() => (isCollapsed ? expandWidget(id) : collapseWidget(id))}
            className="p-1.5 rounded-lg hover:bg-stone-200/70 text-gray-400 hover:text-gray-600 transition-colors"
            aria-label={isCollapsed ? 'Aufklappen' : 'Einklappen'}
          >
            {isCollapsed
              ? <ChevronDown className="w-3.5 h-3.5" />
              : <ChevronUp className="w-3.5 h-3.5" />}
          </button>

          {/* Three-dot menu — non-critical only */}
          {!isCritical && (
            <div ref={menuRef} className="relative">
              <button
                onClick={() => setMenuOpen(v => !v)}
                className="p-1.5 rounded-lg hover:bg-stone-200/70 text-gray-400 hover:text-gray-600 transition-colors"
                aria-label="Widget-Optionen"
              >
                <MoreVertical className="w-3.5 h-3.5" />
              </button>

              {menuOpen && (
                <div className="absolute right-0 top-full mt-1 w-44 bg-white rounded-xl border border-stone-200 shadow-card z-30 overflow-hidden py-1">
                  <button
                    disabled={isFirst}
                    onClick={() => { moveWidget(id, 'up'); setMenuOpen(false) }}
                    className="flex items-center gap-2.5 w-full px-3 py-2 text-xs text-gray-700 hover:bg-stone-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    <ArrowUp className="w-3.5 h-3.5" />
                    Nach oben
                  </button>
                  <button
                    disabled={isLast}
                    onClick={() => { moveWidget(id, 'down'); setMenuOpen(false) }}
                    className="flex items-center gap-2.5 w-full px-3 py-2 text-xs text-gray-700 hover:bg-stone-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    <ArrowDown className="w-3.5 h-3.5" />
                    Nach unten
                  </button>
                  <div className="mx-2 my-1 border-t border-stone-100" />
                  <button
                    onClick={() => { toggleWidget(id); setMenuOpen(false) }}
                    className="flex items-center gap-2.5 w-full px-3 py-2 text-xs text-red-600 hover:bg-red-50 transition-colors"
                  >
                    <EyeOff className="w-3.5 h-3.5" />
                    Ausblenden
                  </button>
                  <button
                    onClick={() => { onOpenSettings(); setMenuOpen(false) }}
                    className="flex items-center gap-2.5 w-full px-3 py-2 text-xs text-gray-600 hover:bg-stone-50 transition-colors"
                  >
                    <Settings2 className="w-3.5 h-3.5" />
                    Alle Widgets
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Body */}
      {!isCollapsed && (
        <WidgetContent id={id} profile={profile} />
      )}
    </div>
  )
}

// ── WidgetGrid (public) ───────────────────────────────────────────────────────

interface WidgetGridProps {
  profile: WidgetGridProfile | null
  /** Override for explicit open-settings callback; defaults to store.openSettings */
  onOpenSettings?: () => void
  className?: string
}

export default function WidgetGrid({ profile, onOpenSettings, className }: WidgetGridProps) {
  const openSettings = useDashboardWidgetStore(s => s.openSettings)
  const handleOpenSettings = onOpenSettings ?? openSettings
  const { enabledWidgets, widgetOrder } = useDashboardWidgetStore()

  const enabledSet = new Set(enabledWidgets)
  const ordered = widgetOrder.filter(id => enabledSet.has(id))

  const criticalOrdered = WIDGET_META
    .filter(w => w.tier === 'critical' && enabledSet.has(w.id))
    .map(w => w.id)

  const otherOrdered = ordered.filter(id => !CRITICAL_IDS.has(id))

  if (ordered.length === 0) {
    return (
      <div
        className={cn(
          'bg-white rounded-2xl border border-stone-200 shadow-soft p-8 text-center',
          className,
        )}
      >
        <p className="text-sm font-medium text-gray-700">Keine Widgets aktiviert</p>
        <button
          onClick={handleOpenSettings}
          className="mt-1.5 text-xs text-primary-600 hover:underline"
        >
          Widgets anpassen →
        </button>
      </div>
    )
  }

  return (
    <div className={cn('space-y-3', className)}>
      {/* Critical (full-width, always at top) */}
      {criticalOrdered.map(id => (
        <WidgetWrapper
          key={id}
          id={id}
          profile={profile}
          moveableIdx={0}
          moveableCount={0}
          onOpenSettings={handleOpenSettings}
        />
      ))}

      {/* Non-critical: responsive grid */}
      {otherOrdered.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-3">
          {otherOrdered.map((id, idx) => (
            <WidgetWrapper
              key={id}
              id={id}
              profile={profile}
              moveableIdx={idx}
              moveableCount={otherOrdered.length}
              onOpenSettings={handleOpenSettings}
            />
          ))}
        </div>
      )}
    </div>
  )
}
