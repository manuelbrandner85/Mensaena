'use client'

// ── useAddressSearch ──────────────────────────────────────────────────────────
// Debounced Adress-Suche mit Location Bias und AbortController-Cleanup.
// Min. 3 Zeichen, Debounce 300 ms.

import { useCallback, useEffect, useRef, useState } from 'react'
import { searchAddress, type GeocodingResult, type GeocoderOptions } from '@/lib/api/geocoder'

export interface UseAddressSearchOptions {
  biasLat?: number
  biasLng?: number
  limit?: number
  /** Debounce in ms (Default 300) */
  debounceMs?: number
  /** Minimale Länge zum Auslösen (Default 3) */
  minChars?: number
}

export interface UseAddressSearchReturn {
  query: string
  setQuery: (q: string) => void
  results: GeocodingResult[]
  isLoading: boolean
  error: string | null
  selectedResult: GeocodingResult | null
  selectResult: (result: GeocodingResult) => void
  clearResults: () => void
}

export function useAddressSearch(
  options: UseAddressSearchOptions = {},
): UseAddressSearchReturn {
  const { biasLat, biasLng, limit = 5, debounceMs = 300, minChars = 3 } = options

  const [query, setQuery] = useState('')
  const [results, setResults] = useState<GeocodingResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [selectedResult, setSelectedResult] = useState<GeocodingResult | null>(null)

  const lastRunRef = useRef(0)

  useEffect(() => {
    const trimmed = query.trim()
    if (trimmed.length < minChars) {
      setResults([])
      setIsLoading(false)
      setError(null)
      return
    }

    const runId = ++lastRunRef.current
    const handle = setTimeout(async () => {
      setIsLoading(true)
      setError(null)
      try {
        const opts: GeocoderOptions = { biasLat, biasLng, limit }
        const data = await searchAddress(trimmed, opts)
        if (lastRunRef.current === runId) {
          setResults(data)
          setIsLoading(false)
        }
      } catch {
        if (lastRunRef.current === runId) {
          setError('Adresssuche fehlgeschlagen.')
          setIsLoading(false)
        }
      }
    }, debounceMs)

    return () => clearTimeout(handle)
  }, [query, biasLat, biasLng, limit, debounceMs, minChars])

  const selectResult = useCallback((result: GeocodingResult) => {
    setSelectedResult(result)
    setQuery(result.displayName)
    setResults([])
  }, [])

  const clearResults = useCallback(() => {
    setResults([])
    setSelectedResult(null)
  }, [])

  return {
    query,
    setQuery,
    results,
    isLoading,
    error,
    selectedResult,
    selectResult,
    clearResults,
  }
}
