import { create } from 'zustand'
import { persist } from 'zustand/middleware'

// ── Types ─────────────────────────────────────────────────────────────────────

export type WidgetId =
  | 'nina'
  | 'weather-alert'
  | 'food-warnings'
  | 'weather'
  | 'pollen'
  | 'water-level'
  | 'holiday'
  | 'traffic'
  | 'jobs'
  | 'education'
  | 'did-you-know'
  | 'historical'

export type WidgetTier = 'critical' | 'important' | 'optional'

export interface WidgetMeta {
  id: WidgetId
  tier: WidgetTier
  title: string
  description: string
  emoji: string
  defaultEnabled: boolean
}

// ── Widget registry ───────────────────────────────────────────────────────────

export const WIDGET_META: readonly WidgetMeta[] = [
  // ── Critical – always shown, locked ──────────────────────────────────────
  {
    id: 'nina',
    tier: 'critical',
    title: 'NINA Warnungen',
    description: 'Amtliche Bevölkerungsschutz- und Katastrophenschutzmeldungen',
    emoji: '🚨',
    defaultEnabled: true,
  },
  {
    id: 'weather-alert',
    tier: 'critical',
    title: 'Unwetterwarnungen',
    description: 'Amtliche Wetterwarnungen des Deutschen Wetterdienstes (DWD)',
    emoji: '⛈️',
    defaultEnabled: true,
  },
  {
    id: 'food-warnings',
    tier: 'critical',
    title: 'Lebensmittelwarnungen',
    description: 'Aktuelle Rückrufe und Warnmeldungen des BVL / foodwatch',
    emoji: '🍎',
    defaultEnabled: true,
  },
  // ── Important – enabled by default ───────────────────────────────────────
  {
    id: 'weather',
    tier: 'important',
    title: 'Wetter',
    description: 'Aktuelles Wetter, Vorhersage und Luftqualität für deinen Standort',
    emoji: '🌤️',
    defaultEnabled: true,
  },
  {
    id: 'pollen',
    tier: 'important',
    title: 'Pollenflug',
    description: 'Tagesaktuelle Pollenbelastung des DWD für deine Region',
    emoji: '🌸',
    defaultEnabled: true,
  },
  {
    id: 'water-level',
    tier: 'important',
    title: 'Wasserpegel',
    description: 'Aktuelle Pegelstände nahegelegener Gewässer',
    emoji: '🌊',
    defaultEnabled: true,
  },
  {
    id: 'holiday',
    tier: 'important',
    title: 'Feiertage',
    description: 'Nächste Feiertage in deinem Bundesland',
    emoji: '🎉',
    defaultEnabled: true,
  },
  // ── Optional – off by default ─────────────────────────────────────────────
  {
    id: 'traffic',
    tier: 'optional',
    title: 'Verkehr & Autobahn',
    description: 'Staus, Baustellen und Sperrungen auf Autobahnen (Pendler-Modus)',
    emoji: '🚗',
    defaultEnabled: false,
  },
  {
    id: 'jobs',
    tier: 'optional',
    title: 'Jobs in der Nähe',
    description: 'Aktuelle Stellenangebote der Bundesagentur für Arbeit',
    emoji: '💼',
    defaultEnabled: false,
  },
  {
    id: 'education',
    tier: 'optional',
    title: 'Bildungsangebote',
    description: 'Ausbildungs- und Weiterbildungsangebote in deiner Nähe',
    emoji: '🎓',
    defaultEnabled: false,
  },
  {
    id: 'did-you-know',
    tier: 'optional',
    title: 'Wusstest du?',
    description: 'Täglicher Wissens-Fakt über deine Stadt (Wikidata)',
    emoji: '💡',
    defaultEnabled: true,
  },
  {
    id: 'historical',
    tier: 'optional',
    title: 'Historische Fotos',
    description: 'Archivbilder und Dokumente aus deiner Region (Deutsche Digitale Bibliothek)',
    emoji: '📸',
    defaultEnabled: true,
  },
] as const

export const CRITICAL_IDS = new Set<WidgetId>(
  WIDGET_META.filter(w => w.tier === 'critical').map(w => w.id),
)

const DEFAULT_ORDER: WidgetId[] = WIDGET_META.map(w => w.id)
const DEFAULT_ENABLED: WidgetId[] = WIDGET_META.filter(w => w.defaultEnabled).map(w => w.id)

// ── State & actions ───────────────────────────────────────────────────────────

interface PersistedState {
  enabledWidgets: WidgetId[]
  widgetOrder: WidgetId[]
  collapsedWidgets: WidgetId[]
}

interface EphemeralState {
  /** Whether the settings modal is open — not persisted */
  settingsOpen: boolean
}

interface Actions {
  toggleWidget: (id: WidgetId) => void
  moveWidget: (id: WidgetId, direction: 'up' | 'down') => void
  collapseWidget: (id: WidgetId) => void
  expandWidget: (id: WidgetId) => void
  openSettings: () => void
  closeSettings: () => void
  resetToDefaults: () => void
}

type State = PersistedState & EphemeralState & Actions

const DEFAULTS: PersistedState = {
  enabledWidgets: DEFAULT_ENABLED,
  widgetOrder: DEFAULT_ORDER,
  collapsedWidgets: [],
}

export const useDashboardWidgetStore = create<State>()(
  persist(
    (set) => ({
      ...DEFAULTS,
      settingsOpen: false,

      toggleWidget: (id) =>
        set(state => {
          if (CRITICAL_IDS.has(id)) return state
          const s = new Set(state.enabledWidgets)
          s.has(id) ? s.delete(id) : s.add(id)
          return { enabledWidgets: [...s] }
        }),

      moveWidget: (id, direction) =>
        set(state => {
          if (CRITICAL_IDS.has(id)) return state
          const order = [...state.widgetOrder]
          const idx = order.indexOf(id)
          if (idx === -1) return state

          const criticalPositions = WIDGET_META
            .filter(w => w.tier === 'critical')
            .map(w => order.indexOf(w.id))
            .filter(i => i !== -1)
          const boundary = criticalPositions.length ? Math.max(...criticalPositions) : -1

          if (direction === 'up' && idx <= boundary + 1) return state
          if (direction === 'down' && idx >= order.length - 1) return state

          const swap = direction === 'up' ? idx - 1 : idx + 1
          ;[order[idx], order[swap]] = [order[swap], order[idx]]
          return { widgetOrder: order }
        }),

      collapseWidget: (id) =>
        set(state => ({
          collapsedWidgets: state.collapsedWidgets.includes(id)
            ? state.collapsedWidgets
            : [...state.collapsedWidgets, id],
        })),

      expandWidget: (id) =>
        set(state => ({
          collapsedWidgets: state.collapsedWidgets.filter(w => w !== id),
        })),

      openSettings: () => set({ settingsOpen: true }),
      closeSettings: () => set({ settingsOpen: false }),

      resetToDefaults: () => set(DEFAULTS),
    }),
    {
      name: 'mensaena-dashboard-widgets',
      version: 1,
      // Only persist the layout config, not the modal state
      partialize: (state): PersistedState => ({
        enabledWidgets: state.enabledWidgets,
        widgetOrder: state.widgetOrder,
        collapsedWidgets: state.collapsedWidgets,
      }),
    },
  ),
)
