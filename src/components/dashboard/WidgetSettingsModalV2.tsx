'use client'

// ── WidgetSettingsModalV2 ─────────────────────────────────────────────────────
// Spec-konformes Settings-Modal für die neue Widget-Architektur (widgetStore.ts).
// Parallel zur bestehenden WidgetSettingsModal.tsx, die noch das ältere
// dashboardWidgetStore.ts verwendet. Migration in Folge-PR.
//
// Drag-Drop via native HTML5 dragstart/dragover/drop (kein NPM-Paket).

import { useState } from 'react'
import {
  Settings, X, GripVertical, RotateCcw, Maximize2, Minimize2,
  Square, Columns2, AlertCircle,
} from 'lucide-react'
import {
  useWidgetStore,
  type WidgetConfig,
  type WidgetId,
  type WidgetSize,
  type WidgetColumn,
} from '@/stores/widgetStore'
import { useGeoStore } from '@/stores/geoStore'
import { getApiAvailability } from '@/lib/api/api-router'

interface WidgetMeta {
  title: string
  description: string
  /** Mapping zu API-Availability für Verfügbarkeitsprüfung */
  availabilityKey?: keyof ReturnType<typeof getApiAvailability> | null
}

const WIDGET_META: Record<WidgetId, WidgetMeta> = {
  weather:        { title: 'Wetter',                    description: 'Aktuelles Wetter und 7-Tage-Vorhersage' },
  air_quality:    { title: 'Luftqualität',              description: 'AQI, PM2.5/PM10, UV-Index', availabilityKey: 'airQuality' },
  pollen:         { title: 'Pollenflug',                description: 'Pollenbelastung in Europa', availabilityKey: 'pollen' },
  warnings:       { title: 'Warnungen',                 description: 'Unwetter- und Bevölkerungsschutz' },
  news:           { title: 'Regionale Nachrichten',     description: 'Tagesschau Regional', availabilityKey: 'news' },
  holidays:       { title: 'Feiertage',                 description: 'Nächste Feiertage' },
  water_levels:   { title: 'Wasserpegel',               description: 'Pegelonline (DE)', availabilityKey: 'waterLevels' },
  radiation:      { title: 'Radioaktivität',            description: 'BfS ODL (DE)', availabilityKey: 'radiation' },
  autobahn:       { title: 'Verkehr & Autobahn',        description: 'Baustellen, Sperrungen (DE)', availabilityKey: 'autobahn' },
  waste:          { title: 'Müllabfuhr',                description: 'Abfallnavi (DE)', availabilityKey: 'wasteCalendar' },
  city_info:      { title: 'Stadtinfo',                 description: 'Wikidata SPARQL' },
  food_warnings:  { title: 'Lebensmittelwarnungen',     description: 'BVL + RASFF EU', availabilityKey: 'foodWarnings' },
  quick_actions:  { title: 'Schnellaktionen',           description: 'Direkte Posts' },
  nearby_posts:   { title: 'Beiträge in der Nähe',      description: 'Nachbarschaft' },
  messages:       { title: 'Ungelesene Nachrichten',    description: 'Chat-Übersicht' },
  trust_score:    { title: 'Vertrauensindex',           description: 'Profil-Stand' },
  challenges:     { title: 'Wochen-Challenge',          description: 'Aktuelle Aktion' },
  activity:       { title: 'Aktivität',                 description: 'Letzte Ereignisse' },
}

const SIZE_OPTIONS: Array<{ value: WidgetSize; label: string; icon: typeof Square }> = [
  { value: 'compact', label: 'Klein', icon: Minimize2 },
  { value: 'normal',  label: 'Normal', icon: Square },
  { value: 'large',   label: 'Groß', icon: Maximize2 },
]

const COLUMN_OPTIONS: Array<{ value: WidgetColumn; label: string }> = [
  { value: 'main',    label: 'Hauptbereich' },
  { value: 'sidebar', label: 'Seitenleiste' },
]

export interface WidgetSettingsModalV2Props {
  open?: boolean
  onClose?: () => void
  onSave?: () => void
}

export function WidgetSettingsModalV2({
  open: openProp,
  onClose,
  onSave,
}: WidgetSettingsModalV2Props = {}) {
  const isOpenStore = useWidgetStore(s => s.isSettingsOpen)
  const closeStore = useWidgetStore(s => s.closeSettings)
  const widgets = useWidgetStore(s => s.widgets)
  const toggleWidget = useWidgetStore(s => s.toggleWidget)
  const reorderWidget = useWidgetStore(s => s.reorderWidget)
  const resizeWidget = useWidgetStore(s => s.resizeWidget)
  const moveToColumn = useWidgetStore(s => s.moveToColumn)
  const resetToDefaults = useWidgetStore(s => s.resetToDefaults)
  const saveToSupabase = useWidgetStore(s => s.saveToSupabase)

  const context = useGeoStore(s => s.context)
  const availability = context ? getApiAvailability(context) : null

  const [draggingId, setDraggingId] = useState<WidgetId | null>(null)

  const isOpen = openProp ?? isOpenStore
  const handleClose = onClose ?? closeStore

  if (!isOpen) return null

  const sortedWidgets = [...widgets].sort((a, b) => a.order - b.order)

  function isWidgetAvailable(w: WidgetConfig): boolean {
    if (!availability) return true
    const key = WIDGET_META[w.id].availabilityKey
    if (!key) return true
    const value = availability[key]
    if (typeof value === 'boolean') return value
    return true
  }

  async function handleSave() {
    try {
      const { createClient } = await import('@/lib/supabase/client')
      const supabase = createClient()
      const { data } = await supabase.auth.getUser()
      if (data.user?.id) {
        await saveToSupabase(data.user.id)
      }
    } catch { /* nur lokaler Persist */ }
    onSave?.()
    handleClose()
  }

  function handleReset() {
    if (context) resetToDefaults(context)
  }

  function handleDragStart(id: WidgetId) {
    setDraggingId(id)
  }

  function handleDragOver(e: React.DragEvent) {
    e.preventDefault()
  }

  function handleDrop(targetId: WidgetId) {
    if (!draggingId || draggingId === targetId) {
      setDraggingId(null)
      return
    }
    const targetOrder = sortedWidgets.findIndex(w => w.id === targetId)
    if (targetOrder >= 0) reorderWidget(draggingId, targetOrder)
    setDraggingId(null)
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Widget-Einstellungen"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={handleClose}
    >
      <div
        className="flex w-full max-w-2xl flex-col overflow-hidden rounded-xl bg-white shadow-2xl dark:bg-ink-800"
        onClick={e => e.stopPropagation()}
        style={{ maxHeight: 'calc(100vh - 4rem)' }}
      >
        <header className="flex items-center justify-between border-b border-stone-200 px-4 py-3 dark:border-ink-700">
          <h2 className="flex items-center gap-2 text-base font-semibold text-ink-900 dark:text-stone-100">
            <Settings aria-hidden className="h-5 w-5 text-primary-500" />
            Widgets anpassen
          </h2>
          <button
            type="button"
            aria-label="Schließen"
            onClick={handleClose}
            className="rounded-md p-1.5 text-ink-500 hover:bg-stone-100 dark:text-stone-400 dark:hover:bg-ink-700"
          >
            <X aria-hidden className="h-4 w-4" />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-4 py-3">
          <p className="mb-3 text-xs text-ink-500 dark:text-ink-400">
            Widgets per Drag-and-Drop sortieren, Größe wählen und Ein-/Ausblenden.
            {context && ` Verfügbarkeit hängt von deinem Standort ab (${context.countryName}).`}
          </p>
          <ul className="space-y-2">
            {sortedWidgets.map(w => {
              const meta = WIDGET_META[w.id]
              const available = isWidgetAvailable(w)
              const dragged = draggingId === w.id
              return (
                <li
                  key={w.id}
                  draggable={available}
                  onDragStart={() => available && handleDragStart(w.id)}
                  onDragOver={handleDragOver}
                  onDrop={() => handleDrop(w.id)}
                  onDragEnd={() => setDraggingId(null)}
                  className={`flex flex-col gap-2 rounded-lg border bg-white p-3 transition-opacity dark:bg-ink-900/40 ${
                    dragged ? 'opacity-50' : ''
                  } ${
                    available
                      ? 'border-stone-200 dark:border-ink-700'
                      : 'border-stone-100 opacity-60 dark:border-ink-800'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <GripVertical
                      aria-hidden
                      className={`h-4 w-4 flex-shrink-0 ${available ? 'cursor-grab text-ink-400' : 'text-stone-400 dark:text-ink-600'}`}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-ink-900 dark:text-stone-100">
                          {meta.title}
                        </span>
                        {!available && (
                          <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-800 dark:bg-amber-900/40 dark:text-amber-200">
                            <AlertCircle aria-hidden className="h-3 w-3" />
                            in dieser Region nicht verfügbar
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-ink-500 dark:text-ink-400">
                        {meta.description}
                      </p>
                    </div>
                    <label className="inline-flex cursor-pointer items-center gap-2">
                      <input
                        type="checkbox"
                        checked={w.enabled && available}
                        disabled={!available}
                        onChange={() => toggleWidget(w.id)}
                        className="h-4 w-4 rounded border-stone-300 text-primary-500 focus:ring-primary-500"
                        aria-label={`${meta.title} aktivieren`}
                      />
                    </label>
                  </div>

                  {available && w.enabled && (
                    <div className="flex flex-wrap items-center justify-between gap-2 border-t border-stone-100 pt-2 dark:border-ink-700">
                      <div className="inline-flex rounded-lg border border-stone-200 bg-stone-50 p-0.5 dark:border-stone-500 dark:bg-ink-800">
                        {SIZE_OPTIONS.map(opt => {
                          const Icon = opt.icon
                          const active = w.size === opt.value
                          return (
                            <button
                              key={opt.value}
                              type="button"
                              onClick={() => resizeWidget(w.id, opt.value)}
                              aria-pressed={active}
                              aria-label={`Größe ${opt.label}`}
                              className={`flex items-center gap-1 rounded-md px-2 py-1 text-xs ${
                                active
                                  ? 'bg-white text-primary-700 shadow-sm dark:bg-ink-900 dark:text-primary-300'
                                  : 'text-ink-600 dark:text-stone-400'
                              }`}
                            >
                              <Icon aria-hidden className="h-3 w-3" />
                              {opt.label}
                            </button>
                          )
                        })}
                      </div>

                      <div className="inline-flex rounded-lg border border-stone-200 bg-stone-50 p-0.5 dark:border-stone-500 dark:bg-ink-800">
                        {COLUMN_OPTIONS.map(opt => {
                          const active = w.column === opt.value
                          return (
                            <button
                              key={opt.value}
                              type="button"
                              onClick={() => moveToColumn(w.id, opt.value)}
                              aria-pressed={active}
                              className={`flex items-center gap-1 rounded-md px-2 py-1 text-xs ${
                                active
                                  ? 'bg-white text-primary-700 shadow-sm dark:bg-ink-900 dark:text-primary-300'
                                  : 'text-ink-600 dark:text-stone-400'
                              }`}
                            >
                              <Columns2 aria-hidden className="h-3 w-3" />
                              {opt.label}
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        </div>

        <footer className="flex items-center justify-between gap-2 border-t border-stone-200 bg-stone-50 px-4 py-3 dark:border-ink-700 dark:bg-ink-900/40">
          <button
            type="button"
            onClick={handleReset}
            className="inline-flex items-center gap-1 rounded-lg border border-stone-200 bg-white px-3 py-1.5 text-xs font-medium text-ink-700 hover:bg-stone-100 dark:border-stone-500 dark:bg-ink-800 dark:text-stone-300 dark:hover:bg-ink-700"
          >
            <RotateCcw aria-hidden className="h-3.5 w-3.5" />
            Zurücksetzen
          </button>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={handleClose}
              className="rounded-lg border border-stone-200 bg-white px-3 py-1.5 text-xs font-medium text-ink-700 hover:bg-stone-100 dark:border-stone-500 dark:bg-ink-800 dark:text-stone-300 dark:hover:bg-ink-700"
            >
              Abbrechen
            </button>
            <button
              type="button"
              onClick={handleSave}
              className="rounded-lg bg-primary-500 px-3 py-1.5 text-xs font-medium text-white hover:bg-primary-600"
            >
              Speichern
            </button>
          </div>
        </footer>
      </div>
    </div>
  )
}

export default WidgetSettingsModalV2
