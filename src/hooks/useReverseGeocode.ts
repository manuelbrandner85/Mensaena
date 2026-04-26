'use client'

// ── useReverseGeocode ─────────────────────────────────────────────────────────
// Wandelt lat/lng in eine lesbare Adresse um. Nutzt den bestehenden
// Nominatim-Wrapper (@/lib/api/nominatim) und fügt Debounce + Cleanup hinzu.

import { useEffect, useRef, useState } from 'react'
import { reverseGeocode as nominatimReverse, type GeoAddress } from '@/lib/api/nominatim'

export interface UseReverseGeocodeReturn {
  address: GeoAddress | null
  isLoading: boolean
  error: string | null
}

export function useReverseGeocode(
  lat: number | null | undefined,
  lng: number | null | undefined,
  debounceMs: number = 500,
): UseReverseGeocodeReturn {
  const [address, setAddress] = useState<GeoAddress | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const lastRunRef = useRef(0)

  useEffect(() => {
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      setAddress(null)
      setIsLoading(false)
      setError(null)
      return
    }

    const runId = ++lastRunRef.current
    const handle = setTimeout(async () => {
      setIsLoading(true)
      setError(null)
      try {
        const data = await nominatimReverse(lat, lng)
        if (lastRunRef.current === runId) {
          setAddress(data)
          setIsLoading(false)
        }
      } catch {
        if (lastRunRef.current === runId) {
          setError('Adresse konnte nicht ermittelt werden.')
          setIsLoading(false)
        }
      }
    }, debounceMs)

    return () => clearTimeout(handle)
  }, [lat, lng, debounceMs])

  return { address, isLoading, error }
}
