'use client'

// ── Widget Store (Next-Gen Orchestrator) ──────────────────────────────────────
// Spec-konformer Store für die neue Widget-Architektur. Wird parallel zu
// dashboardWidgetStore.ts gepflegt; das Dashboard wird in einer Folge-PR
// migriert.
//
// Persistenz:
//  - lokal: zustand/persist (localStorage) als sofortige UX
//  - remote: Supabase Tabelle widget_configs (loadFromSupabase /
//    saveToSupabase) für Cross-Device-Sync
//
// DB-Migration (Supabase):
//   CREATE TABLE IF NOT EXISTS widget_configs (
//     user_id UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
//     config JSONB NOT NULL DEFAULT '[]'::jsonb,
//     updated_at TIMESTAMPTZ DEFAULT NOW()
//   );
//   ALTER TABLE widget_configs ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "Users can manage own widget config"
//     ON widget_configs FOR ALL
//     USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import { createClient } from '@/lib/supabase/client'
import type { GeoContext } from '@/lib/geo/country-detect'

// ── Widget-IDs ───────────────────────────────────────────────────────────────

export type WidgetId =
  | 'weather'
  | 'air_quality'
  | 'pollen'
  | 'warnings'
  | 'news'
  | 'holidays'
  | 'water_levels'
  | 'radiation'
  | 'autobahn'
  | 'waste'
  | 'city_info'
  | 'food_warnings'
  | 'quick_actions'
  | 'nearby_posts'
  | 'messages'
  | 'trust_score'
  | 'challenges'
  | 'activity'

export type WidgetSize = 'compact' | 'normal' | 'large'
export type WidgetColumn = 'main' | 'sidebar'

export interface WidgetConfig {
  id: WidgetId
  enabled: boolean
  order: number
  size: WidgetSize
  column: WidgetColumn
}

// ── Defaults pro Region ──────────────────────────────────────────────────────

const ALL_WIDGETS: ReadonlyArray<WidgetId> = [
  'weather', 'air_quality', 'pollen', 'warnings', 'news', 'holidays',
  'water_levels', 'radiation', 'autobahn', 'waste', 'city_info',
  'food_warnings', 'quick_actions', 'nearby_posts', 'messages',
  'trust_score', 'challenges', 'activity',
]

const SIDEBAR_DEFAULTS: ReadonlySet<WidgetId> = new Set([
  'messages', 'trust_score', 'city_info', 'activity', 'challenges',
])

function buildConfig(
  ids: ReadonlyArray<WidgetId>,
  enabled: ReadonlySet<WidgetId>,
): WidgetConfig[] {
  return ids.map((id, idx) => ({
    id,
    enabled: enabled.has(id),
    order: idx,
    size: 'normal',
    column: SIDEBAR_DEFAULTS.has(id) ? 'sidebar' : 'main',
  }))
}

const ENABLED_BY_LEVEL: Record<GeoContext['supportLevel'], ReadonlySet<WidgetId>> = {
  DE: new Set(ALL_WIDGETS),
  AT: new Set([
    'weather', 'air_quality', 'pollen', 'warnings', 'holidays',
    'quick_actions', 'nearby_posts', 'messages', 'trust_score',
    'challenges', 'activity', 'city_info',
  ]),
  CH: new Set([
    'weather', 'air_quality', 'pollen', 'warnings', 'holidays',
    'quick_actions', 'nearby_posts', 'messages', 'trust_score',
    'challenges', 'activity', 'city_info',
  ]),
  EU: new Set([
    'weather', 'air_quality', 'warnings', 'holidays', 'food_warnings',
    'quick_actions', 'nearby_posts', 'messages',
  ]),
  WORLD: new Set([
    'weather', 'holidays', 'quick_actions', 'nearby_posts', 'messages',
  ]),
}

// ── Store-Interface ──────────────────────────────────────────────────────────

export interface WidgetStore {
  widgets: WidgetConfig[]
  isLoading: boolean
  isSettingsOpen: boolean

  setWidgets: (w: WidgetConfig[]) => void
  toggleWidget: (id: WidgetId) => void
  reorderWidget: (id: WidgetId, order: number) => void
  resizeWidget: (id: WidgetId, size: WidgetSize) => void
  moveToColumn: (id: WidgetId, column: WidgetColumn) => void
  openSettings: () => void
  closeSettings: () => void

  loadFromSupabase: (userId: string) => Promise<void>
  saveToSupabase: (userId: string) => Promise<void>

  /** Initial-Konfiguration je nach GeoContext */
  getDefaultWidgets: (geo: GeoContext) => WidgetConfig[]
  /** Setzt den Store auf die Defaults für einen GeoContext zurück */
  resetToDefaults: (geo: GeoContext) => void
}

// ── Implementierung ──────────────────────────────────────────────────────────

function defaultsFromLevel(level: GeoContext['supportLevel']): WidgetConfig[] {
  return buildConfig(ALL_WIDGETS, ENABLED_BY_LEVEL[level])
}

export const useWidgetStore = create<WidgetStore>()(
  persist(
    (set, get) => ({
      widgets: defaultsFromLevel('WORLD'),
      isLoading: false,
      isSettingsOpen: false,

      setWidgets: (w) => set({ widgets: w }),

      toggleWidget: (id) =>
        set(state => ({
          widgets: state.widgets.map(w =>
            w.id === id ? { ...w, enabled: !w.enabled } : w,
          ),
        })),

      reorderWidget: (id, order) =>
        set(state => {
          const list = [...state.widgets].sort((a, b) => a.order - b.order)
          const idx = list.findIndex(w => w.id === id)
          if (idx === -1) return state
          const target = Math.max(0, Math.min(list.length - 1, order))
          const [item] = list.splice(idx, 1)
          list.splice(target, 0, item)
          return {
            widgets: list.map((w, i) => ({ ...w, order: i })),
          }
        }),

      resizeWidget: (id, size) =>
        set(state => ({
          widgets: state.widgets.map(w => (w.id === id ? { ...w, size } : w)),
        })),

      moveToColumn: (id, column) =>
        set(state => ({
          widgets: state.widgets.map(w => (w.id === id ? { ...w, column } : w)),
        })),

      openSettings: () => set({ isSettingsOpen: true }),
      closeSettings: () => set({ isSettingsOpen: false }),

      loadFromSupabase: async (userId) => {
        if (!userId) return
        set({ isLoading: true })
        try {
          const supabase = createClient()
          const { data, error } = await supabase
            .from('widget_configs')
            .select('config')
            .eq('user_id', userId)
            .maybeSingle()

          if (error) {
            // 42P01 = relation does not exist (Migration noch nicht angewendet)
            if (!('code' in error) || error.code !== 'PGRST116') {
              // Andere Fehler ignorieren wir leise — Migration evtl. fehlend.
            }
            return
          }
          if (data?.config && Array.isArray(data.config)) {
            set({ widgets: data.config as WidgetConfig[] })
          }
        } catch {
          /* offline / Konfigurationsfehler – Defaults bleiben */
        } finally {
          set({ isLoading: false })
        }
      },

      saveToSupabase: async (userId) => {
        if (!userId) return
        try {
          const supabase = createClient()
          await supabase
            .from('widget_configs')
            .upsert({
              user_id: userId,
              config: get().widgets,
              updated_at: new Date().toISOString(),
            })
        } catch {
          /* silent fail – persist() hat lokal bereits gesichert */
        }
      },

      getDefaultWidgets: (geo) => defaultsFromLevel(geo.supportLevel),

      resetToDefaults: (geo) => set({ widgets: defaultsFromLevel(geo.supportLevel) }),
    }),
    {
      name: 'mensaena-widget-config-v1',
      // FIX-114: SSR-safe storage
      storage: createJSONStorage(() => (
        typeof window !== 'undefined'
          ? localStorage
          : { getItem: () => null, setItem: () => {}, removeItem: () => {} } as Storage
      )),
      partialize: (state) => ({ widgets: state.widgets }),
    },
  ),
)
