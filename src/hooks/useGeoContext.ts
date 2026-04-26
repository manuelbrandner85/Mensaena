'use client'

// ── Hook: GeoContext laden + im Store halten ──────────────────────────────────
// Ermittelt beim Mount den GeoContext (Reihenfolge: Profil-Koordinaten →
// Browser-Geolocation → null). Kein Auto-Permission-Prompt — die Browser-API
// fragt nur nach, wenn der Nutzer einen entsprechenden Button klickt oder die
// Seite den Standort aktiv anfordert (z. B. Karte).

import { useEffect } from 'react'
import { useGeoStore } from '@/stores/geoStore'
import { getGeoContext, getGeoContextFromPlz } from '@/lib/geo/country-detect'
import { createClient } from '@/lib/supabase/client'
import type { GeoContext } from '@/lib/geo/country-detect'

interface UseGeoContextReturn {
  context: GeoContext | null
  loading: boolean
  error: string | null
  refresh: () => Promise<void>
}

/**
 * Lädt den GeoContext beim Mount.
 *
 * Strategie:
 *  1) Wenn der Store bereits einen Kontext hat → nichts tun.
 *  2) Versuche das Profil aus Supabase zu lesen (lat, lng oder plz).
 *  3) Wenn Profil-Koordinaten vorhanden → daraus Kontext bauen.
 *  4) Wenn nur PLZ vorhanden → DE-Kontext per PLZ ableiten.
 *  5) Sonst: keine Aktion (Browser-Geolocation wird erst on-demand angefragt).
 */
export function useGeoContext(): UseGeoContextReturn {
  const context = useGeoStore((s) => s.context)
  const loading = useGeoStore((s) => s.loading)
  const error = useGeoStore((s) => s.error)
  const refresh = useGeoStore((s) => s.refresh)
  const setContext = useGeoStore((s) => s.setContext)
  const setFromCoords = useGeoStore((s) => s.setFromCoords)

  useEffect(() => {
    if (context) return
    let cancelled = false

    async function loadFromProfile() {
      try {
        const supabase = createClient()
        const {
          data: { user },
        } = await supabase.auth.getUser()
        if (!user || cancelled) return

        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude, plz')
          .eq('id', user.id)
          .maybeSingle()

        if (cancelled || !profile) return

        if (
          typeof profile.latitude === 'number' &&
          typeof profile.longitude === 'number'
        ) {
          await setFromCoords(profile.latitude, profile.longitude)
          return
        }

        if (typeof profile.plz === 'string' && profile.plz.length >= 4) {
          const partial = getGeoContextFromPlz(profile.plz)
          if (partial.countryCode === 'DE') {
            // Best-effort Kontext ohne reale Koordinaten — wird beim ersten
            // Geolocation-Aufruf später überschrieben.
            const fakeCtx: GeoContext = {
              ...partial,
              lat: 0,
              lng: 0,
            } as GeoContext
            setContext(fakeCtx)
          }
        }
      } catch {
        /* Profil nicht ladbar oder nicht eingeloggt – ignorieren */
      }
    }

    void loadFromProfile()
    return () => {
      cancelled = true
    }
    // Nur einmal beim Mount – setContext/setFromCoords sind stabil aus Zustand.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return { context, loading, error, refresh }
}

/**
 * Variante: erzwingt Browser-Geolocation. Sollte nur aus User-Aktionen
 * (z. B. "Mein Standort"-Button) heraus aufgerufen werden, weil der Browser
 * eine Permission-Abfrage zeigt.
 */
export async function requestGeoFromBrowser(): Promise<void> {
  await useGeoStore.getState().refresh()
}

export async function buildGeoContextFromCoords(
  lat: number,
  lng: number,
): Promise<GeoContext> {
  return getGeoContext(lat, lng)
}
