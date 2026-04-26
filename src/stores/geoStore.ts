'use client'

// ── Globaler GeoContext-Store ─────────────────────────────────────────────────
// Hält das aktuell ermittelte GeoContext-Profil im Speicher und persistiert
// das letzte erfolgreiche Ergebnis in localStorage. Das vermeidet Flicker beim
// Reload und einen Geolocation-Permission-Prompt bei jedem Seitenaufruf.

import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import { getGeoContext, type GeoContext } from '@/lib/geo/country-detect'
import { getCurrentPosition } from '@/lib/geo/browser-location'

// ── Store-Interface ──────────────────────────────────────────────────────────

export interface GeoStore {
  /** Aktuell aktiver Kontext oder null wenn noch nicht ermittelt */
  context: GeoContext | null
  /** Wird gerade eine Standortermittlung ausgeführt? */
  loading: boolean
  /** Letzter Fehler (in Deutsch) oder null */
  error: string | null

  /** Setzt den Kontext explizit (z. B. nach Profil-Änderung) */
  setContext: (ctx: GeoContext) => void
  /** Setzt den Fehler explizit (z. B. wenn der Browser keine Geo-Permission gibt) */
  setError: (msg: string | null) => void
  /** Erzwingt eine erneute Ermittlung via Geolocation API */
  refresh: () => Promise<void>
  /** Initialisiert aus expliziten Koordinaten (Profil/Onboarding) */
  setFromCoords: (lat: number, lng: number) => Promise<void>
  /** Setzt den Store komplett zurück */
  reset: () => void
}

// ── Store-Implementierung ────────────────────────────────────────────────────

export const useGeoStore = create<GeoStore>()(
  persist(
    (set) => ({
      context: null,
      loading: false,
      error: null,

      setContext: (ctx) => set({ context: ctx, error: null }),

      setError: (msg) => set({ error: msg }),

      refresh: async () => {
        set({ loading: true, error: null })
        try {
          const pos = await getCurrentPosition()
          const ctx = await getGeoContext(pos.lat, pos.lng)
          set({ context: ctx, loading: false, error: null })
        } catch (err) {
          const message =
            err && typeof err === 'object' && 'message' in err
              ? String((err as { message: unknown }).message)
              : 'Standort konnte nicht ermittelt werden.'
          set({ loading: false, error: message })
        }
      },

      setFromCoords: async (lat, lng) => {
        set({ loading: true, error: null })
        try {
          const ctx = await getGeoContext(lat, lng)
          set({ context: ctx, loading: false, error: null })
        } catch {
          set({ loading: false, error: 'Geo-Kontext konnte nicht erstellt werden.' })
        }
      },

      reset: () => set({ context: null, loading: false, error: null }),
    }),
    {
      name: 'mensaena-geo-context',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({ context: state.context }),
    },
  ),
)
