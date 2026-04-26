'use client'

// ── AddressAutocomplete ───────────────────────────────────────────────────────
// Eingabefeld + Dropdown-Liste mit Photon-Geocoder-Treffern.
// Vollständige Tastatur-Navigation (ArrowUp/Down/Enter/Escape) und ARIA-konforme
// Combobox-Semantik.

import { useEffect, useId, useRef, useState } from 'react'
import { MapPin, Building2, Map as MapIcon, Search, Loader2, X } from 'lucide-react'
import { useAddressSearch } from '@/hooks/useAddressSearch'
import type { GeocodingResult, GeocodingType } from '@/lib/api/geocoder'

export interface AddressAutocompleteProps {
  onSelect: (result: GeocodingResult) => void
  placeholder?: string
  defaultValue?: string
  className?: string
  /** Location-Bias (verbessert Relevanz) */
  biasLat?: number
  biasLng?: number
  /** Optionale aria-label */
  ariaLabel?: string
}

const TYPE_ICON: Record<GeocodingType, typeof MapPin> = {
  house: Building2, street: MapPin, locality: MapPin, district: MapPin,
  city: MapIcon, county: MapIcon, state: MapIcon, country: MapIcon,
}

export function AddressAutocomplete({
  onSelect,
  placeholder = 'Adresse suchen…',
  defaultValue = '',
  className = '',
  biasLat,
  biasLng,
  ariaLabel = 'Adresse suchen',
}: AddressAutocompleteProps) {
  const listId = useId()
  const inputRef = useRef<HTMLInputElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [open, setOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(-1)

  const {
    query,
    setQuery,
    results,
    isLoading,
    error,
    selectResult,
    clearResults,
  } = useAddressSearch({ biasLat, biasLng, limit: 5 })

  // Init mit defaultValue genau einmal
  useEffect(() => {
    if (defaultValue) setQuery(defaultValue)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Click-outside schließt
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (!containerRef.current?.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', onClick)
    return () => document.removeEventListener('mousedown', onClick)
  }, [])

  useEffect(() => {
    setActiveIndex(-1)
  }, [results])

  function handleSelect(idx: number) {
    const r = results[idx]
    if (!r) return
    selectResult(r)
    onSelect(r)
    setOpen(false)
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (!open) {
      if (e.key === 'ArrowDown' && results.length > 0) {
        setOpen(true)
        e.preventDefault()
      }
      return
    }
    if (e.key === 'ArrowDown') {
      setActiveIndex(i => Math.min(i + 1, results.length - 1))
      e.preventDefault()
    } else if (e.key === 'ArrowUp') {
      setActiveIndex(i => Math.max(i - 1, 0))
      e.preventDefault()
    } else if (e.key === 'Enter') {
      if (activeIndex >= 0) {
        handleSelect(activeIndex)
        e.preventDefault()
      }
    } else if (e.key === 'Escape') {
      setOpen(false)
      e.preventDefault()
    }
  }

  return (
    <div ref={containerRef} className={`relative ${className}`}>
      <div className="relative">
        <Search aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <input
          ref={inputRef}
          type="search"
          role="combobox"
          aria-label={ariaLabel}
          aria-expanded={open && results.length > 0}
          aria-controls={listId}
          aria-activedescendant={
            activeIndex >= 0 ? `${listId}-option-${activeIndex}` : undefined
          }
          autoComplete="off"
          placeholder={placeholder}
          value={query}
          onChange={e => {
            setQuery(e.target.value)
            setOpen(true)
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={handleKeyDown}
          className="w-full rounded-lg border border-gray-200 bg-white py-2 pl-9 pr-9 text-sm focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
        />
        {isLoading ? (
          <Loader2 aria-hidden className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-gray-400" />
        ) : query.length > 0 ? (
          <button
            type="button"
            onClick={() => { setQuery(''); clearResults(); inputRef.current?.focus() }}
            aria-label="Eingabe löschen"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <X aria-hidden className="h-3 w-3" />
          </button>
        ) : null}
      </div>

      {open && (results.length > 0 || error) && (
        <ul
          id={listId}
          role="listbox"
          className="absolute left-0 right-0 z-20 mt-1 max-h-72 overflow-auto rounded-lg border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-gray-800"
        >
          {error && (
            <li className="px-3 py-2 text-xs text-red-600 dark:text-red-300">
              {error}
            </li>
          )}
          {results.map((r, i) => {
            const Icon = TYPE_ICON[r.type] ?? MapPin
            const active = i === activeIndex
            return (
              <li
                key={r.id}
                id={`${listId}-option-${i}`}
                role="option"
                aria-selected={active}
                onMouseEnter={() => setActiveIndex(i)}
                onClick={() => handleSelect(i)}
                className={`flex cursor-pointer items-start gap-2 px-3 py-2 text-sm transition-colors ${
                  active
                    ? 'bg-primary-50 text-primary-900 dark:bg-primary-900/40 dark:text-primary-100'
                    : 'text-gray-800 hover:bg-gray-50 dark:text-gray-200 dark:hover:bg-gray-700'
                }`}
              >
                <Icon aria-hidden className="mt-0.5 h-4 w-4 flex-shrink-0 text-gray-400" />
                <div className="flex-1 min-w-0">
                  <div className="font-medium">{r.name}</div>
                  <div className="truncate text-xs text-gray-500 dark:text-gray-400">
                    {r.displayName}
                  </div>
                </div>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}

export default AddressAutocomplete
