'use client'

import { useState, useRef, useId, useCallback, useEffect } from 'react'
import { MapPin, Loader2, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import { searchAddress, type PhotonResult } from '@/lib/api/photon'

export interface AddressAutocompleteProps {
  onSelect: (result: PhotonResult) => void
  placeholder?: string
  defaultValue?: string
  className?: string
  biasLat?: number
  biasLon?: number
  label?: string
  id?: string
  required?: boolean
  error?: string
}

function highlightMatch(text: string, query: string): React.ReactNode {
  if (!query.trim()) return text
  const idx = text.toLowerCase().indexOf(query.toLowerCase().trim())
  if (idx === -1) return text
  return (
    <>
      {text.slice(0, idx)}
      <strong className="font-semibold text-ink-900">{text.slice(idx, idx + query.trim().length)}</strong>
      {text.slice(idx + query.trim().length)}
    </>
  )
}

export default function AddressAutocomplete({
  onSelect,
  placeholder = 'Adresse suchen…',
  defaultValue = '',
  className,
  biasLat,
  biasLon,
  label,
  id: idProp,
  required,
  error,
}: AddressAutocompleteProps) {
  const generatedId = useId()
  const inputId = idProp ?? `address-${generatedId}`
  const listboxId = `listbox-${generatedId}`

  const [inputValue, setInputValue] = useState(defaultValue)
  const [results, setResults] = useState<PhotonResult[]>([])
  const [loading, setLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(-1)

  const containerRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Close on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false)
        setActiveIndex(-1)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const runSearch = useCallback(
    async (query: string) => {
      if (query.trim().length < 3) {
        setResults([])
        setOpen(false)
        setLoading(false)
        return
      }
      setLoading(true)
      try {
        const res = await searchAddress(query, {
          lat: biasLat,
          lon: biasLon,
          limit: 6,
        })
        setResults(res)
        setOpen(res.length > 0)
        setActiveIndex(-1)
      } catch (err: unknown) {
        if (err instanceof Error && err.name === 'AbortError') return
        setResults([])
        setOpen(false)
      } finally {
        setLoading(false)
      }
    },
    [biasLat, biasLon],
  )

  function handleInputChange(e: React.ChangeEvent<HTMLInputElement>) {
    const val = e.target.value
    setInputValue(val)
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => runSearch(val), 300)
  }

  function handleSelect(result: PhotonResult) {
    setInputValue(result.displayName)
    setOpen(false)
    setActiveIndex(-1)
    setResults([])
    onSelect(result)
    inputRef.current?.blur()
  }

  function handleClear() {
    setInputValue('')
    setResults([])
    setOpen(false)
    setActiveIndex(-1)
    inputRef.current?.focus()
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (!open || results.length === 0) return

    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActiveIndex((i) => Math.min(i + 1, results.length - 1))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActiveIndex((i) => Math.max(i - 1, 0))
    } else if (e.key === 'Enter' && activeIndex >= 0) {
      e.preventDefault()
      handleSelect(results[activeIndex])
    } else if (e.key === 'Escape') {
      setOpen(false)
      setActiveIndex(-1)
    }
  }

  const activeDescendant =
    open && activeIndex >= 0 ? `${listboxId}-option-${activeIndex}` : undefined

  return (
    <div ref={containerRef} className={cn('relative', className)}>
      {label && (
        <label
          htmlFor={inputId}
          className="block text-sm font-medium text-ink-700 mb-1.5"
        >
          {label}
          {required && <span className="text-emergency ml-0.5" aria-hidden>*</span>}
        </label>
      )}

      <div className="relative">
        <MapPin
          className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 pointer-events-none"
          aria-hidden
        />

        <input
          ref={inputRef}
          id={inputId}
          type="text"
          role="combobox"
          aria-expanded={open}
          aria-autocomplete="list"
          aria-controls={listboxId}
          aria-activedescendant={activeDescendant}
          aria-required={required}
          autoComplete="off"
          spellCheck={false}
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => {
            if (results.length > 0) setOpen(true)
          }}
          placeholder={placeholder}
          className={cn(
            'input w-full pl-9 pr-8 text-[16px] md:text-sm',
            open && 'rounded-b-none border-b-transparent',
            error && 'border-emergency focus:ring-emergency/30',
          )}
        />

        <div className="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
          {loading && (
            <Loader2 className="w-4 h-4 text-primary-500 animate-spin" aria-label="Suche läuft…" />
          )}
          {!loading && inputValue && (
            <button
              type="button"
              onClick={handleClear}
              className="text-ink-400 hover:text-ink-600 p-0.5 rounded transition-colors"
              aria-label="Eingabe löschen"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Dropdown */}
      {open && results.length > 0 && (
        <ul
          id={listboxId}
          role="listbox"
          aria-label="Adressvorschläge"
          className="absolute left-0 right-0 top-full z-50 bg-white border border-warm-200 border-t-0 rounded-b-xl shadow-xl max-h-64 overflow-y-auto divide-y divide-warm-100"
        >
          {results.map((result, idx) => (
            <li
              key={idx}
              id={`${listboxId}-option-${idx}`}
              role="option"
              aria-selected={idx === activeIndex}
              onMouseDown={(e) => {
                e.preventDefault()
                handleSelect(result)
              }}
              onMouseEnter={() => setActiveIndex(idx)}
              className={cn(
                'flex items-start gap-2.5 px-3 py-2.5 cursor-pointer transition-colors text-sm',
                idx === activeIndex
                  ? 'bg-primary-50 text-ink-900'
                  : 'text-ink-700 hover:bg-warm-50',
              )}
            >
              <MapPin className="w-3.5 h-3.5 mt-0.5 flex-shrink-0 text-primary-400" aria-hidden />
              <span className="leading-snug">
                {highlightMatch(result.displayName, inputValue)}
              </span>
            </li>
          ))}
        </ul>
      )}

      {error && (
        <p className="form-error mt-1" role="alert">
          {error}
        </p>
      )}
    </div>
  )
}
