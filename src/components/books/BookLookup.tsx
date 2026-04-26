'use client'

import { useState, useCallback, useEffect, useRef } from 'react'
import {
  BookOpen, Search, ScanBarcode, ArrowRight, Loader2,
  AlertCircle, RotateCcw, CheckCircle2, Info,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  getBookByISBN, searchBooks, isValidISBN, cleanISBN,
  type BookResult,
} from '@/lib/api/books'
import BookCard from './BookCard'

// ── Types ─────────────────────────────────────────────────────────────────────

interface BookLookupProps {
  /** Called when the user confirms a book — pre-fills the marketplace form. */
  onBookSelect: (book: BookResult) => void
  className?: string
}

type Mode = 'isbn' | 'search'

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Pretty-print ISBN-13 as 978-X-XXX-XXXXX-X while the user types. */
function prettyISBN(raw: string): string {
  const digits = raw.replace(/[^\dX]/gi, '').toUpperCase().slice(0, 13)
  // Only format once length is known
  if (digits.length === 13) {
    return `${digits.slice(0, 3)}-${digits.slice(3, 4)}-${digits.slice(4, 9)}-${digits.slice(9, 12)}-${digits.slice(12)}`
  }
  if (digits.length === 10) {
    return `${digits.slice(0, 1)}-${digits.slice(1, 5)}-${digits.slice(5, 9)}-${digits.slice(9)}`
  }
  return digits
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function BookLookup({ onBookSelect, className }: BookLookupProps) {
  const [mode, setMode] = useState<Mode>('isbn')

  // ISBN mode
  const [isbnRaw, setIsbnRaw] = useState('')

  // Search mode
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<BookResult[]>([])
  const [searched, setSearched] = useState(false)
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Shared
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<BookResult | null>(null)

  // ── Debounced title search ──────────────────────────────────────────────────
  useEffect(() => {
    if (mode !== 'search') return
    if (query.trim().length < 3) {
      setResults([])
      setSearched(false)
      return
    }
    if (searchTimer.current) clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(async () => {
      setLoading(true)
      setError(null)
      const found = await searchBooks(query)
      setResults(found)
      setSearched(true)
      setLoading(false)
    }, 500)
    return () => {
      if (searchTimer.current) clearTimeout(searchTimer.current)
    }
  }, [query, mode])

  // ── ISBN lookup ─────────────────────────────────────────────────────────────
  const handleISBNLookup = useCallback(async () => {
    const cleaned = cleanISBN(isbnRaw)
    if (!cleaned) { setError('Bitte ISBN eingeben'); return }
    if (!isValidISBN(cleaned)) {
      setError('Ungültige ISBN – bitte eine 10- oder 13-stellige ISBN eingeben')
      return
    }
    setLoading(true)
    setError(null)
    const book = await getBookByISBN(cleaned)
    setLoading(false)
    setSearched(true)
    if (!book) {
      setError('Buch nicht gefunden – du kannst die Infos manuell eingeben')
      return
    }
    setSelected(book)
  }, [isbnRaw])

  // ── Actions ─────────────────────────────────────────────────────────────────
  const handleConfirm = () => {
    if (selected) onBookSelect(selected)
  }

  const handleReset = () => {
    setSelected(null)
    setIsbnRaw('')
    setQuery('')
    setResults([])
    setSearched(false)
    setError(null)
  }

  const switchMode = (m: Mode) => {
    setMode(m)
    setError(null)
    setSearched(false)
    setResults([])
  }

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <div className={cn(
      'rounded-2xl border border-primary-200 bg-gradient-to-br from-primary-50/60 to-blue-50/30 overflow-hidden',
      className,
    )}>
      {/* Header */}
      <div className="flex items-center gap-2.5 px-4 py-3 bg-white/60 border-b border-primary-100">
        <div className="w-8 h-8 rounded-lg bg-primary-600 flex items-center justify-center flex-shrink-0">
          <BookOpen className="w-4 h-4 text-white" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-primary-900 leading-tight">Buchinfo automatisch laden</p>
          <p className="text-[11px] text-primary-600 mt-0.5">Open Library · kein Account nötig</p>
        </div>
      </div>

      <div className="p-4 space-y-4">

        {/* ── Book confirmed ── */}
        {selected ? (
          <div className="space-y-3">
            <div className="flex items-center gap-1.5 text-xs font-medium text-primary-600 bg-primary-50 border border-primary-200 rounded-lg px-3 py-1.5">
              <CheckCircle2 className="w-3.5 h-3.5 flex-shrink-0" />
              Buch gefunden – Formulardaten werden vorausgefüllt
            </div>

            <BookCard book={selected} variant="full" />

            <div className="flex gap-2">
              <button
                type="button"
                onClick={handleConfirm}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary-600 text-white text-sm font-semibold hover:bg-primary-700 active:scale-[0.98] transition-all shadow-sm"
              >
                Dieses Buch anbieten
                <ArrowRight className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={handleReset}
                className="p-2.5 rounded-xl border border-stone-200 bg-white text-stone-500 hover:text-stone-700 hover:bg-stone-50 transition-colors"
                aria-label="Anderes Buch auswählen"
                title="Anderes Buch auswählen"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : (
          <>
            {/* ── Mode toggle ── */}
            <div className="flex rounded-xl bg-white border border-stone-200 p-1 gap-1">
              {([
                { id: 'isbn' as Mode, label: 'ISBN', Icon: ScanBarcode },
                { id: 'search' as Mode, label: 'Titel / Autor', Icon: Search },
              ] as const).map(({ id, label, Icon }) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => switchMode(id)}
                  className={cn(
                    'flex-1 flex items-center justify-center gap-1.5 py-1.5 rounded-lg text-xs font-semibold transition-all',
                    mode === id
                      ? 'bg-primary-600 text-white shadow-sm'
                      : 'text-stone-500 hover:text-stone-800 hover:bg-stone-50',
                  )}
                >
                  <Icon className="w-3.5 h-3.5" />
                  {label}
                </button>
              ))}
            </div>

            {/* ── ISBN mode ── */}
            {mode === 'isbn' && (
              <div className="space-y-2.5">
                <div className="relative">
                  <ScanBarcode className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 pointer-events-none" />
                  <input
                    type="text"
                    inputMode="numeric"
                    value={prettyISBN(isbnRaw)}
                    onChange={(e) => {
                      const digits = e.target.value.replace(/[^\dX]/gi, '').toUpperCase()
                      setIsbnRaw(digits)
                      setError(null)
                      setSearched(false)
                    }}
                    onKeyDown={(e) => { if (e.key === 'Enter') handleISBNLookup() }}
                    placeholder="978-3-16-148410-0"
                    className="input pl-10 font-mono tracking-wider"
                    maxLength={17}
                    autoComplete="off"
                  />
                </div>

                <div className="flex items-start gap-1.5 text-[11px] text-stone-400">
                  <Info className="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
                  <span>Die ISBN findest du über dem Barcode auf der Buchrückseite</span>
                </div>

                <button
                  type="button"
                  onClick={handleISBNLookup}
                  disabled={loading || !isbnRaw.trim()}
                  className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-stone-800 text-white text-sm font-semibold hover:bg-stone-700 disabled:opacity-50 disabled:pointer-events-none transition-colors"
                >
                  {loading
                    ? <Loader2 className="w-4 h-4 animate-spin" />
                    : <Search className="w-4 h-4" />
                  }
                  Buch nachschlagen
                </button>
              </div>
            )}

            {/* ── Search mode ── */}
            {mode === 'search' && (
              <div className="space-y-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 pointer-events-none" />
                  {loading && (
                    <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-primary-500 animate-spin" />
                  )}
                  <input
                    type="text"
                    value={query}
                    onChange={(e) => { setQuery(e.target.value); setError(null) }}
                    placeholder="Titel, Autor oder Stichwort…"
                    className="input pl-10"
                    autoComplete="off"
                    autoCorrect="off"
                  />
                </div>

                {/* Results dropdown */}
                {results.length > 0 && (
                  <div className="rounded-xl border border-stone-200 bg-white shadow-soft overflow-hidden divide-y divide-stone-50">
                    {results.map((book, i) => (
                      <button
                        key={`${book.isbn ?? book.title}-${i}`}
                        type="button"
                        onClick={() => { setSelected(book); setResults([]) }}
                        className="w-full text-left hover:bg-primary-50 transition-colors focus-visible:outline-none focus-visible:bg-primary-50"
                      >
                        <BookCard book={book} variant="compact" />
                      </button>
                    ))}
                  </div>
                )}

                {searched && !loading && results.length === 0 && !error && (
                  <p className="text-xs text-stone-500 text-center py-2">
                    Keine Ergebnisse — du kannst die Informationen manuell eingeben
                  </p>
                )}
              </div>
            )}

            {/* ── Error / not-found ── */}
            {error && (
              <div className="flex items-start gap-2 p-3 rounded-xl bg-amber-50 border border-amber-200">
                <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800 leading-relaxed">{error}</p>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
