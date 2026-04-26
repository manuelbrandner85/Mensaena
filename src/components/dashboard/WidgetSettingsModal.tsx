'use client'

import { X, RotateCcw, ChevronUp, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  useDashboardWidgetStore,
  WIDGET_META,
  CRITICAL_IDS,
  type WidgetId,
  type WidgetTier,
} from '@/stores/dashboardWidgetStore'

// ── Tier labels ───────────────────────────────────────────────────────────────

const TIER_LABEL: Record<WidgetTier, string> = {
  critical:  '🚨 Kritische Warnungen',
  important: '⭐ Wichtige Informationen',
  optional:  '✨ Optionale Widgets',
}

const TIER_DESC: Record<WidgetTier, string> = {
  critical:  'Immer sichtbar – können nicht deaktiviert werden',
  important: 'Standardmäßig aktiv – für alle Nutzer empfohlen',
  optional:  'Individuell aktivierbar – je nach Bedarf',
}

// ── Widget row ────────────────────────────────────────────────────────────────

interface WidgetRowProps {
  id: WidgetId
  moveableIdx: number
  moveableTotal: number
}

function WidgetRow({ id, moveableIdx, moveableTotal }: WidgetRowProps) {
  const { enabledWidgets, toggleWidget, moveWidget } = useDashboardWidgetStore()
  const meta = WIDGET_META.find(w => w.id === id)!
  const isCritical = CRITICAL_IDS.has(id)
  const isEnabled = enabledWidgets.includes(id)
  const isFirst = moveableIdx === 0
  const isLast = moveableIdx === moveableTotal - 1

  return (
    <div
      className={cn(
        'flex items-center gap-3 px-3 py-2.5 transition-colors',
        isEnabled && !isCritical ? 'bg-primary-50/40' : 'bg-white',
      )}
    >
      {/* Emoji */}
      <span className="text-xl w-7 flex-shrink-0 text-center">{meta.emoji}</span>

      {/* Title + desc */}
      <div className="flex-1 min-w-0">
        <p className={cn('text-sm font-medium', isCritical ? 'text-red-800' : 'text-gray-900')}>
          {meta.title}
          {isCritical && (
            <span className="ml-1.5 text-[10px] font-semibold text-red-500 bg-red-100 px-1.5 py-0.5 rounded-full">
              Pflicht
            </span>
          )}
        </p>
        <p className="text-[11px] text-gray-500 mt-0.5 line-clamp-1 leading-tight">
          {meta.description}
        </p>
      </div>

      {/* Move buttons – non-critical only */}
      {!isCritical && (
        <div className="flex flex-col gap-px flex-shrink-0">
          <button
            disabled={isFirst}
            onClick={() => moveWidget(id, 'up')}
            className="p-0.5 rounded hover:bg-stone-200 disabled:opacity-25 disabled:cursor-not-allowed text-gray-500 transition-colors"
            aria-label="Nach oben"
          >
            <ChevronUp className="w-3.5 h-3.5" />
          </button>
          <button
            disabled={isLast}
            onClick={() => moveWidget(id, 'down')}
            className="p-0.5 rounded hover:bg-stone-200 disabled:opacity-25 disabled:cursor-not-allowed text-gray-500 transition-colors"
            aria-label="Nach unten"
          >
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {/* Toggle switch */}
      {isCritical ? (
        // Locked – always on
        <div
          className="flex-shrink-0 w-9 h-5 bg-red-400 rounded-full flex items-center justify-end pr-0.5 cursor-not-allowed opacity-80"
          title="Kann nicht deaktiviert werden"
        >
          <span className="w-4 h-4 bg-white rounded-full shadow-sm" />
        </div>
      ) : (
        <button
          role="switch"
          aria-checked={isEnabled}
          onClick={() => toggleWidget(id)}
          className={cn(
            'relative flex-shrink-0 w-9 h-5 rounded-full transition-colors duration-200',
            isEnabled ? 'bg-primary-500' : 'bg-stone-300',
          )}
        >
          <span
            className={cn(
              'absolute top-0.5 w-4 h-4 bg-white rounded-full shadow-sm transition-transform duration-200',
              isEnabled ? 'translate-x-4' : 'translate-x-0.5',
            )}
          />
        </button>
      )}
    </div>
  )
}

// ── Layout preview ────────────────────────────────────────────────────────────

function LayoutPreview() {
  const { enabledWidgets, widgetOrder } = useDashboardWidgetStore()
  const enabledSet = new Set(enabledWidgets)

  const criticalEnabled = WIDGET_META
    .filter(w => w.tier === 'critical' && enabledSet.has(w.id))
  const othersEnabled = widgetOrder
    .filter(id => !CRITICAL_IDS.has(id) && enabledSet.has(id))
    .map(id => WIDGET_META.find(w => w.id === id)!)
    .filter(Boolean)

  return (
    <div className="bg-stone-50 border border-stone-200 rounded-2xl p-3 space-y-1.5">
      <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wide mb-2">
        Vorschau – Aktuelle Anordnung
      </p>

      {/* Critical row */}
      {criticalEnabled.map(w => (
        <div key={w.id}
          className="flex items-center gap-1.5 bg-red-50 border border-red-200 rounded-lg px-2 py-1">
          <span className="text-xs">{w.emoji}</span>
          <span className="text-[11px] font-medium text-red-700 truncate">{w.title}</span>
          <span className="ml-auto text-[9px] text-red-400 bg-red-100 px-1 rounded-full">Immer</span>
        </div>
      ))}

      {/* Grid preview */}
      {othersEnabled.length > 0 && (
        <div className="grid grid-cols-3 gap-1 mt-1">
          {othersEnabled.slice(0, 9).map(w => (
            <div key={w.id}
              className="flex flex-col items-center gap-0.5 bg-white border border-stone-200 rounded-lg p-1.5 text-center">
              <span className="text-sm">{w.emoji}</span>
              <span className="text-[9px] text-gray-600 leading-tight line-clamp-2">{w.title}</span>
            </div>
          ))}
          {othersEnabled.length > 9 && (
            <div className="flex items-center justify-center bg-stone-100 rounded-lg p-1.5">
              <span className="text-[10px] text-gray-500">+{othersEnabled.length - 9}</span>
            </div>
          )}
        </div>
      )}

      {othersEnabled.length === 0 && criticalEnabled.length === 0 && (
        <p className="text-[11px] text-gray-400 text-center py-2">Keine Widgets aktiv</p>
      )}
    </div>
  )
}

// ── Modal ─────────────────────────────────────────────────────────────────────

interface WidgetSettingsModalProps {
  /** Explicit close callback; defaults to store.closeSettings */
  onClose?: () => void
}

export default function WidgetSettingsModal({ onClose }: WidgetSettingsModalProps) {
  const { widgetOrder, resetToDefaults, closeSettings } = useDashboardWidgetStore()
  const handleClose = onClose ?? closeSettings

  // Compute global moveable list for isFirst/isLast
  const moveableOrder = widgetOrder.filter(id => !CRITICAL_IDS.has(id))

  // Build tier groups in widgetOrder sequence
  const groups: Record<WidgetTier, WidgetId[]> = {
    critical: WIDGET_META.filter(w => w.tier === 'critical').map(w => w.id),
    important: widgetOrder.filter(id => WIDGET_META.find(w => w.id === id)?.tier === 'important'),
    optional: widgetOrder.filter(id => WIDGET_META.find(w => w.id === id)?.tier === 'optional'),
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      role="dialog"
      aria-modal="true"
      aria-label="Widgets anpassen"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/40 backdrop-blur-sm"
        onClick={handleClose}
      />

      {/* Panel */}
      <div className="relative bg-white sm:rounded-3xl rounded-t-3xl w-full sm:max-w-lg max-h-[92dvh] flex flex-col shadow-2xl overflow-hidden">
        {/* Drag handle (mobile) */}
        <div className="sm:hidden flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 bg-stone-300 rounded-full" />
        </div>

        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-stone-100">
          <div>
            <h2 className="font-bold text-gray-900">⚙️ Widgets anpassen</h2>
            <p className="text-xs text-gray-500 mt-0.5">
              Aktiviere, deaktiviere und ordne deine Dashboard-Widgets
            </p>
          </div>
          <button
            onClick={handleClose}
            className="p-2 rounded-xl hover:bg-stone-100 text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-5">
          {/* Layout preview */}
          <LayoutPreview />

          {/* Widget groups */}
          {(['critical', 'important', 'optional'] as WidgetTier[]).map(tier => {
            const ids = groups[tier]
            if (!ids.length) return null

            return (
              <div key={tier}>
                <div className="mb-2 px-1">
                  <p className="text-xs font-bold text-gray-900">{TIER_LABEL[tier]}</p>
                  <p className="text-[11px] text-gray-500 mt-0.5">{TIER_DESC[tier]}</p>
                </div>

                <div className="border border-stone-200 rounded-2xl overflow-hidden divide-y divide-stone-100">
                  {ids.map(id => (
                    <WidgetRow
                      key={id}
                      id={id}
                      moveableIdx={moveableOrder.indexOf(id)}
                      moveableTotal={moveableOrder.length}
                    />
                  ))}
                </div>
              </div>
            )
          })}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-3.5 border-t border-stone-100 bg-stone-50/60">
          <button
            onClick={() => {
              resetToDefaults()
            }}
            className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-red-500 transition-colors"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            Auf Standard zurücksetzen
          </button>
          <button
            onClick={handleClose}
            className="px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white text-sm font-medium rounded-xl transition-colors"
          >
            Fertig
          </button>
        </div>
      </div>
    </div>
  )
}
