'use client'

import { useEffect, useState, useCallback, useRef } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import {
  Search, MapPin, Phone, Globe, Leaf, CheckCircle2,
  Truck, Scissors, ShoppingBag, X, ChevronDown, SlidersHorizontal,
  ArrowRight, RefreshCw, Map, List, Download, ArrowUpDown,
} from 'lucide-react'
import type { FarmListing, FarmCategory } from '@/types/farm'
import { FARM_CATEGORIES, FARM_PRODUCTS, CATEGORY_ICONS, CATEGORY_COLORS, COUNTRY_LABELS } from '@/types/farm'
import { createClient } from '@/lib/supabase/client'
import type { MapFilters } from '@/components/supply/FarmsMapView'
import { SupplyEmergencySwap } from '@/components/features/exchange'

// Karte lazy laden (kein SSR)
const FarmsMapView = dynamic(() => import('@/components/supply/FarmsMapView'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-[500px] bg-green-50 rounded-2xl border border-green-200">
      <div className="text-center">
        <div className="w-10 h-10 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
        <p className="text-green-600 text-sm font-medium">Karte wird geladen…</p>
      </div>
    </div>
  ),
})

// ─── Typen ────────────────────────────────────────────────────
interface Filters {
  categories: string[]   // Multi-Select
  country: string
  bio: boolean
  delivery: boolean
  product: string
  state: string
  sortBy: 'name' | 'verified' | 'recent' | 'bio'
}

const DEFAULT_FILTERS: Filters = {
  categories: [], country: '', bio: false, delivery: false,
  product: '', state: '', sortBy: 'verified',
}

const ITEMS_PER_PAGE = 24

// PostgREST or()-Filter: `,` `(` `)` `"` `\` brechen die Filter-Syntax, % und _ sind ilike-Wildcards.
function sanitizeForOrFilter(value: string): string {
  return value.replace(/[,()"\\]/g, ' ').trim()
}
function escapeIlike(value: string): string {
  return value.replace(/[%_\\]/g, '\\$&')
}

const DE_STATES = [
  'Baden-Württemberg','Bayern','Berlin','Brandenburg','Bremen',
  'Hamburg','Hessen','Mecklenburg-Vorpommern','Niedersachsen',
  'Nordrhein-Westfalen','Rheinland-Pfalz','Saarland','Sachsen',
  'Sachsen-Anhalt','Schleswig-Holstein','Thüringen',
]
const AT_STATES = [
  'Burgenland','Kärnten','Niederösterreich','Oberösterreich',
  'Salzburg','Steiermark','Tirol','Vorarlberg','Wien',
]
const CH_CANTONS = [
  'Aargau','Appenzell Ausserrhoden','Appenzell Innerrhoden','Basel-Landschaft',
  'Basel-Stadt','Bern','Freiburg','Genf','Glarus','Graubünden','Jura',
  'Luzern','Neuenburg','Nidwalden','Obwalden','St. Gallen','Schaffhausen',
  'Schwyz','Solothurn','Thurgau','Tessin','Uri','Waadt','Wallis','Zug','Zürich',
]

// ─── FarmCard ─────────────────────────────────────────────────
function FarmCard({ farm, isFav, onToggleFav }: { farm: FarmListing; isFav?: boolean; onToggleFav?: () => void }) {
  const categoryColor = CATEGORY_COLORS[farm.category] ?? 'bg-gray-100 text-gray-700'
  const categoryIcon  = CATEGORY_ICONS[farm.category] ?? '🏡'

  return (
    <div className="group bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-lg hover:border-green-300 transition-all duration-200 overflow-hidden flex flex-col relative">
      {/* Fav Button */}
      {onToggleFav && (
        <button
          onClick={(e) => { e.preventDefault(); onToggleFav() }}
          className="absolute top-3 right-3 z-10 w-7 h-7 flex items-center justify-center rounded-full bg-white/80 shadow text-base hover:scale-110 transition-transform"
          title={isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen'}
        >
          {isFav ? '❤️' : '🤍'}
        </button>
      )}

      <Link href={`/dashboard/supply/farm/${farm.slug}`} className="flex flex-col flex-1">
        {/* Header */}
        <div className="bg-gradient-to-br from-green-50 to-primary-50 px-5 pt-5 pb-4">
          <div className="flex items-start justify-between gap-3">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1 flex-wrap">
                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${categoryColor}`}>
                  {categoryIcon} {farm.category}
                </span>
                {farm.is_bio && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-lime-100 text-lime-800">
                    <Leaf className="w-3 h-3" /> Bio
                  </span>
                )}
                {farm.is_verified && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    <CheckCircle2 className="w-3 h-3" /> Verifiziert
                  </span>
                )}
              </div>
              <h3 className="text-base font-semibold text-gray-900 group-hover:text-green-700 transition-colors line-clamp-2 leading-tight">
                {farm.name}
              </h3>
            </div>
            <div className="text-2xl shrink-0">{categoryIcon}</div>
          </div>

          <div className="flex items-center gap-1.5 text-sm text-gray-500 mt-2">
            <MapPin className="w-3.5 h-3.5 shrink-0" />
            <span className="truncate">
              {farm.postal_code ? `${farm.postal_code} ` : ''}{farm.city}
              {farm.state ? `, ${farm.state}` : ''}
            </span>
          </div>
        </div>

        {/* Body */}
        <div className="px-5 py-3 flex-1 flex flex-col gap-3">
          {farm.description && (
            <p className="text-sm text-gray-600 line-clamp-2 leading-relaxed">{farm.description}</p>
          )}
          {farm.products && farm.products.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {farm.products.slice(0, 5).map((p) => (
                <span key={p} className="text-xs bg-amber-50 text-amber-700 px-2 py-0.5 rounded-full border border-amber-100">
                  {p}
                </span>
              ))}
              {farm.products.length > 5 && (
                <span className="text-xs text-gray-400">+{farm.products.length - 5} mehr</span>
              )}
            </div>
          )}
          {farm.delivery_options && farm.delivery_options.length > 0 && (
            <div className="flex items-center gap-1.5 text-xs text-purple-700">
              <Truck className="w-3.5 h-3.5" />
              <span>{farm.delivery_options.slice(0, 2).join(' · ')}</span>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-gray-50 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {farm.phone && (
              <a href={`tel:${farm.phone}`} onClick={(e) => e.stopPropagation()} className="text-gray-400 hover:text-green-700">
                <Phone className="w-3.5 h-3.5" />
              </a>
            )}
            {farm.website && (
              <a href={farm.website} target="_blank" rel="noopener noreferrer" onClick={(e) => e.stopPropagation()} className="text-gray-400 hover:text-green-700">
                <Globe className="w-3.5 h-3.5" />
              </a>
            )}
            <span className="text-xs text-gray-400">{COUNTRY_LABELS[farm.country] ?? farm.country}</span>
          </div>
          <span className="flex items-center gap-1 text-xs text-green-700 font-medium group-hover:gap-2 transition-all">
            Details <ArrowRight className="w-3.5 h-3.5" />
          </span>
        </div>
      </Link>
    </div>
  )
}

// ─── Produkt-Autocomplete ─────────────────────────────────────
function ProductAutocomplete({
  value, onChange, suggestions,
}: { value: string; onChange: (v: string) => void; suggestions: string[] }) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState(value)
  const ref = useRef<HTMLDivElement>(null)

  // Close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const filtered = q
    ? suggestions.filter((s) => s.toLowerCase().includes(q.toLowerCase())).slice(0, 8)
    : suggestions.slice(0, 8)

  return (
    <div ref={ref} className="relative">
      <input
        type="text"
        value={q}
        placeholder="Produkt suchen…"
        onChange={(e) => { setQ(e.target.value); setOpen(true) }}
        onFocus={() => setOpen(true)}
        className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
      />
      {q && (
        <button onClick={() => { setQ(''); onChange('') }} className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400">
          <X className="w-3.5 h-3.5" />
        </button>
      )}
      {open && filtered.length > 0 && (
        <div className="absolute top-full mt-1 left-0 right-0 bg-white rounded-xl shadow-lg border border-gray-100 z-50 max-h-48 overflow-y-auto">
          {filtered.map((s) => (
            <button
              key={s}
              onMouseDown={() => { setQ(s); onChange(s); setOpen(false) }}
              className={`w-full text-left px-3 py-2 text-sm hover:bg-green-50 transition-colors ${value === s ? 'text-green-700 font-semibold bg-green-50' : 'text-gray-700'}`}
            >
              {s}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

// ─── FilterPanel ──────────────────────────────────────────────
function FilterPanel({
  filters, onChange, onReset, activeCount, allProducts,
}: {
  filters: Filters
  onChange: (f: Partial<Filters>) => void
  onReset: () => void
  activeCount: number
  allProducts: string[]
}) {
  const [open, setOpen] = useState(false)

  const regionOptions = filters.country === 'DE' ? DE_STATES
    : filters.country === 'AT' ? AT_STATES
    : filters.country === 'CH' ? CH_CANTONS
    : [...DE_STATES, ...AT_STATES, ...CH_CANTONS].sort()

  const toggleCategory = (c: string) => {
    const cats = filters.categories.includes(c)
      ? filters.categories.filter((x) => x !== c)
      : [...filters.categories, c]
    onChange({ categories: cats })
  }

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className={`flex items-center gap-2 px-4 py-2.5 rounded-xl border font-medium text-sm transition-all ${
          activeCount > 0
            ? 'bg-green-600 text-white border-green-600 shadow-md'
            : 'bg-white text-gray-700 border-gray-200 hover:border-green-300'
        }`}
      >
        <SlidersHorizontal className="w-4 h-4" />
        <span className="hidden sm:inline">Filter</span>
        {activeCount > 0 && (
          <span className="bg-white text-green-700 text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
            {activeCount}
          </span>
        )}
        <ChevronDown className={`w-4 h-4 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>

      {open && (
        <div className="absolute top-full mt-2 right-0 z-50 bg-white rounded-2xl shadow-xl border border-gray-100 p-5 w-80 sm:w-96 space-y-4 max-h-[80vh] overflow-y-auto">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-gray-900">Filter</h3>
            <button onClick={() => setOpen(false)} className="text-gray-400 hover:text-gray-600"><X className="w-4 h-4" /></button>
          </div>

          {/* Multi-Kategorie */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">
              Typ <span className="normal-case font-normal text-gray-400">(Mehrfachauswahl)</span>
            </label>
            <div className="flex flex-wrap gap-1.5">
              <button
                onClick={() => onChange({ categories: [] })}
                className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                  filters.categories.length === 0 ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                }`}
              >
                Alle
              </button>
              {FARM_CATEGORIES.map((c) => (
                <button
                  key={c}
                  onClick={() => toggleCategory(c)}
                  className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                    filters.categories.includes(c) ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                  }`}
                >
                  {CATEGORY_ICONS[c]} {c}
                </button>
              ))}
            </div>
          </div>

          {/* Land */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">Land</label>
            <div className="flex gap-2">
              {(['', 'AT', 'DE', 'CH'] as const).map((c) => (
                <button
                  key={c}
                  onClick={() => onChange({ country: c, state: '' })}
                  className={`flex-1 py-1.5 rounded-xl text-xs font-medium border transition-all ${
                    filters.country === c ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                  }`}
                >
                  {c === '' ? 'Alle' : COUNTRY_LABELS[c]}
                </button>
              ))}
            </div>
          </div>

          {/* Region */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">
              {filters.country === 'CH' ? 'Kanton' : filters.country === 'AT' ? 'Bundesland' : 'Region'}
            </label>
            <select
              value={filters.state}
              onChange={(e) => onChange({ state: e.target.value })}
              className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
            >
              <option value="">Alle Regionen</option>
              {regionOptions.map((bl) => <option key={bl} value={bl}>{bl}</option>)}
            </select>
          </div>

          {/* Produkt Autocomplete */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">Produkt</label>
            <ProductAutocomplete
              value={filters.product}
              onChange={(v) => onChange({ product: v })}
              suggestions={allProducts}
            />
          </div>

          {/* Sortierung */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">Sortierung</label>
            <div className="grid grid-cols-2 gap-1.5">
              {([
                { value: 'verified', label: '✓ Verifiziert zuerst' },
                { value: 'name',     label: '🔤 Name A–Z' },
                { value: 'recent',   label: '🕐 Neueste zuerst' },
                { value: 'bio',      label: '🌿 Bio zuerst' },
              ] as const).map(({ value, label }) => (
                <button
                  key={value}
                  onClick={() => onChange({ sortBy: value })}
                  className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition-all text-left ${
                    filters.sortBy === value ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Checkboxen */}
          <div className="space-y-2">
            <label className="flex items-center gap-3 cursor-pointer group">
              <div
                onClick={() => onChange({ bio: !filters.bio })}
                className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-all cursor-pointer ${
                  filters.bio ? 'bg-lime-500 border-lime-500' : 'border-gray-300 group-hover:border-lime-400'
                }`}
              >
                {filters.bio && <span className="text-white text-xs">✓</span>}
              </div>
              <span className="text-sm text-gray-700 flex items-center gap-1.5">
                <Leaf className="w-4 h-4 text-lime-600" /> Nur Bio-Betriebe
              </span>
            </label>
            <label className="flex items-center gap-3 cursor-pointer group">
              <div
                onClick={() => onChange({ delivery: !filters.delivery })}
                className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-all cursor-pointer ${
                  filters.delivery ? 'bg-purple-500 border-purple-500' : 'border-gray-300 group-hover:border-purple-400'
                }`}
              >
                {filters.delivery && <span className="text-white text-xs">✓</span>}
              </div>
              <span className="text-sm text-gray-700 flex items-center gap-1.5">
                <Truck className="w-4 h-4 text-purple-600" /> Mit Lieferung
              </span>
            </label>
          </div>

          {activeCount > 0 && (
            <button
              onClick={() => { onReset(); setOpen(false) }}
              className="w-full flex items-center justify-center gap-2 py-2 text-sm text-red-600 hover:bg-red-50 rounded-xl transition-colors"
            >
              <RefreshCw className="w-4 h-4" /> Filter zurücksetzen
            </button>
          )}
        </div>
      )}
    </div>
  )
}

// ─── Smart Pagination ─────────────────────────────────────────
function Pagination({ page, pages, onChange }: { page: number; pages: number; onChange: (p: number) => void }) {
  if (pages <= 1) return null
  const getPageNumbers = () => {
    const delta = 2
    const range: (number | '...')[] = [1]
    const left  = Math.max(2, page - delta)
    const right = Math.min(pages - 1, page + delta)
    if (left > 2) range.push('...')
    for (let i = left; i <= right; i++) range.push(i)
    if (right < pages - 1) range.push('...')
    if (pages > 1) range.push(pages)
    return range
  }
  return (
    <div className="flex items-center justify-center gap-1.5 mt-8 flex-wrap">
      <button onClick={() => onChange(Math.max(1, page - 1))} disabled={page === 1}
        className="px-3 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-40">←</button>
      {getPageNumbers().map((p, idx) =>
        p === '...' ? (
          <span key={`e${idx}`} className="px-2 text-gray-400 text-sm">…</span>
        ) : (
          <button key={p} onClick={() => onChange(p as number)}
            className={`w-9 h-9 rounded-xl text-sm font-medium transition-all ${p === page ? 'bg-green-600 text-white shadow-sm' : 'border border-gray-200 text-gray-700 hover:bg-gray-50'}`}>
            {p}
          </button>
        )
      )}
      <button onClick={() => onChange(Math.min(pages, page + 1))} disabled={page === pages}
        className="px-3 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-40">→</button>
    </div>
  )
}

// ─── CSV Export ───────────────────────────────────────────────
// D1.9 Security: Exclude personal contact data (phone, email) from CSV export
// to prevent bulk data harvesting. Only public business info is exported.
function exportCSV(farms: FarmListing[]) {
  const headers = ['Name','Kategorie','Stadt','PLZ','Bundesland','Land','Adresse','Website','Bio','Verifiziert','Produkte','Lieferung']
  const rows = farms.map((f) => [
    f.name, f.category, f.city, f.postal_code || '', f.state || '', COUNTRY_LABELS[f.country] ?? f.country,
    f.address || '', f.website || '',
    f.is_bio ? 'Ja' : 'Nein', f.is_verified ? 'Ja' : 'Nein',
    (f.products || []).join('; '), (f.delivery_options || []).join('; '),
  ])
  const csv = [headers, ...rows].map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url  = URL.createObjectURL(blob)
  const a    = document.createElement('a')
  a.href = url; a.download = `mensaena-betriebe-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(a); a.click()
  document.body.removeChild(a); URL.revokeObjectURL(url)
}

// ─── Hauptseite ───────────────────────────────────────────────
export default function SupplyPage() {
  const [farms,       setFarms]       = useState<FarmListing[]>([])
  const [total,       setTotal]       = useState(0)
  const [pages,       setPages]       = useState(1)
  const [page,        setPage]        = useState(1)
  const [loading,     setLoading]     = useState(true)
  const [viewMode,    setViewMode]    = useState<'list' | 'map'>('list')
  const [searchQuery, setSearchQuery] = useState('')
  const [debouncedQ,  setDebouncedQ]  = useState('')
  const [filters,     setFilters]     = useState<Filters>(DEFAULT_FILTERS)
  const debounceRef   = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [selectedFarm, setSelectedFarm] = useState<FarmListing | null>(null)
  const [allProducts,  setAllProducts]  = useState<string[]>(FARM_PRODUCTS)
  const [favorites,    setFavorites]    = useState<string[]>([])   // farm IDs

  // Load favorites from localStorage
  useEffect(() => {
    try {
      const saved = localStorage.getItem('mensaena_favorites')
      if (saved) setFavorites(JSON.parse(saved))
    } catch { /* ignore */ }
  }, [])

  const toggleFav = useCallback((id: string) => {
    setFavorites((prev) => {
      const next = prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
      try { localStorage.setItem('mensaena_favorites', JSON.stringify(next)) } catch { /* ignore */ }
      return next
    })
  }, [])

  // Debounce search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => setDebouncedQ(searchQuery), 400)
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current) }
  }, [searchQuery])

  // Fetch distinct products from DB
  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    supabase.from('farm_listings').select('products').eq('is_public', true).limit(500)
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) { console.error('supply products query failed:', error.message); return }
        if (!data) return
        const set = new Set<string>()
        data.forEach((r) => (r.products || []).forEach((p: string) => set.add(p)))
        const sorted = Array.from(set).sort()
        if (sorted.length > 0) setAllProducts(sorted)
      })
    return () => { cancelled = true }
  }, [])

  // Paginated list fetch
  const fetchFarms = useCallback(async () => {
    setLoading(true)
    try {
      const supabase = createClient()
      const offset = (page - 1) * ITEMS_PER_PAGE
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let query: any = supabase
        .from('farm_listings')
        .select('*', { count: 'exact' })
        .eq('is_public', true)
        .range(offset, offset + ITEMS_PER_PAGE - 1)

      // Sorting
      if (filters.sortBy === 'name')     query = query.order('name', { ascending: true })
      else if (filters.sortBy === 'recent') query = query.order('created_at', { ascending: false })
      else if (filters.sortBy === 'bio') { query = query.order('is_bio', { ascending: false }); query = query.order('name', { ascending: true }) }
      else { query = query.order('is_verified', { ascending: false }); query = query.order('name', { ascending: true }) }

      if (debouncedQ) {
        const safe = escapeIlike(sanitizeForOrFilter(debouncedQ))
        if (safe) {
          query = query.or(`name.ilike.%${safe}%,city.ilike.%${safe}%,description.ilike.%${safe}%,state.ilike.%${safe}%`)
        }
      }
      const cats = filters.categories
      if (cats.length === 1) query = query.eq('category', cats[0])
      else if (cats.length > 1) query = query.in('category', cats)
      if (filters.country)  query = query.eq('country', filters.country)
      if (filters.state)    query = query.ilike('state', `%${escapeIlike(filters.state)}%`)
      if (filters.bio)      query = query.eq('is_bio', true)
      if (filters.product)  query = query.contains('products', [filters.product])
      if (filters.delivery) query = query.not('delivery_options', 'eq', '{}')

      const { data, count, error } = await query
      if (error) console.error('supply fetchFarms failed:', error.message)
      setFarms(data || [])
      setTotal(count || 0)
      setPages(Math.ceil((count || 0) / ITEMS_PER_PAGE))
    } catch (err) {
      console.error('supply fetchFarms threw:', err)
      setFarms([])
    } finally {
      setLoading(false)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, debouncedQ, filters])

  useEffect(() => { fetchFarms() }, [fetchFarms])
  useEffect(() => { setPage(1) }, [debouncedQ, filters])

  const activeFilterCount = [
    ...filters.categories, filters.country, filters.product, filters.state,
    filters.bio ? 'bio' : '', filters.delivery ? 'del' : '',
    filters.sortBy !== 'verified' ? 'sort' : '',
  ].filter(Boolean).length

  const updateFilters = (partial: Partial<Filters>) => setFilters((prev) => ({ ...prev, ...partial }))

  // Map filters (MapFilters interface)
  const mapFilters: MapFilters = {
    category: filters.categories.length === 1 ? filters.categories[0] : '',
    categories: filters.categories,
    country: filters.country,
    bio: filters.bio,
    delivery: filters.delivery,
    product: filters.product,
    state: filters.state,
  }

  return (
    <div>
      {/* Editorial header */}
      <header className="max-w-7xl mx-auto px-4 sm:px-6 pt-6 pb-2">
        <div className="meta-label meta-label--subtle mb-4">§ 15 / Regionale Versorgung</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-amber-50 border border-amber-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Leaf className="w-6 h-6 text-amber-700" />
            </div>
            <div>
              <h1 className="page-title">Regionale Versorgung</h1>
              <p className="page-subtitle mt-2">
                <span className="font-serif italic text-ink-800 tabular-nums">{total > 0 ? total.toLocaleString() : '600+'}</span>{' '}
                Bauernhöfe, Hofläden und <span className="text-accent">Direktvermarkter</span> aus AT · DE · CH.
              </p>
            </div>
          </div>
          <div className="flex-shrink-0">
            <Link
              href="/dashboard/supply/farm/add"
              className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors"
            >
              + Betrieb eintragen
            </Link>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 mt-5">
          {[
            { icon: <Leaf className="w-3.5 h-3.5" />, label: 'Bio & Regional' },
            { icon: <Truck className="w-3.5 h-3.5" />, label: 'Lieferung' },
            { icon: <Scissors className="w-3.5 h-3.5" />, label: 'Selbsternte' },
            { icon: <ShoppingBag className="w-3.5 h-3.5" />, label: 'Direktkauf' },
          ].map(({ icon, label }) => (
            <span key={label} className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-stone-100 border border-stone-200 text-xs font-medium text-ink-700">
              {icon} {label}
            </span>
          ))}
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 mb-6">
        <SupplyEmergencySwap />
      </div>

      {/* ── Sticky Controls ──────────────────────────────────── */}
      <div className="sticky top-0 z-40 bg-white/95 backdrop-blur-sm border-b border-gray-100 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3">
          <div className="flex items-center gap-2 sm:gap-3">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Betrieb, Stadt, Region oder Produkt suchen…"
                className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300 focus:border-transparent bg-gray-50"
              />
              {searchQuery && (
                <button onClick={() => setSearchQuery('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Filter Panel */}
            <FilterPanel
              filters={filters}
              onChange={updateFilters}
              onReset={() => setFilters(DEFAULT_FILTERS)}
              activeCount={activeFilterCount}
              allProducts={allProducts}
            />

            {/* CSV Export (list mode only) */}
            {viewMode === 'list' && farms.length > 0 && (
              <button
                onClick={() => exportCSV(farms)}
                title="Als CSV exportieren"
                className="flex items-center gap-1.5 px-3 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-700 hover:border-green-300 hover:text-green-700 transition-all"
              >
                <Download className="w-4 h-4" />
                <span className="hidden sm:inline">CSV</span>
              </button>
            )}

            {/* View Toggle */}
            <div className="flex bg-gray-100 rounded-xl p-1 gap-1 shrink-0">
              <button
                onClick={() => setViewMode('list')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${viewMode === 'list' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
              >
                <List className="w-4 h-4" /><span className="hidden sm:inline">Liste</span>
              </button>
              <button
                onClick={() => setViewMode('map')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${viewMode === 'map' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
              >
                <Map className="w-4 h-4" /><span className="hidden sm:inline">Karte</span>
              </button>
            </div>
          </div>

          {/* Active Filter Chips */}
          {activeFilterCount > 0 && (
            <div className="flex flex-wrap gap-2 mt-2">
              {filters.categories.map((c) => (
                <FilterChip
                  key={c}
                  label={`${CATEGORY_ICONS[c as FarmCategory]} ${c}`}
                  onRemove={() => updateFilters({ categories: filters.categories.filter((x) => x !== c) })}
                />
              ))}
              {filters.country && (
                <FilterChip label={COUNTRY_LABELS[filters.country]} onRemove={() => updateFilters({ country: '', state: '' })} />
              )}
              {filters.state && (
                <FilterChip label={`📍 ${filters.state}`} onRemove={() => updateFilters({ state: '' })} />
              )}
              {filters.product && (
                <FilterChip label={`🛒 ${filters.product}`} onRemove={() => updateFilters({ product: '' })} />
              )}
              {filters.bio && (
                <FilterChip label="🌿 Nur Bio" onRemove={() => updateFilters({ bio: false })} />
              )}
              {filters.delivery && (
                <FilterChip label="🚚 Mit Lieferung" onRemove={() => updateFilters({ delivery: false })} />
              )}
              {filters.sortBy !== 'verified' && (
                <FilterChip
                  label={`⬆️ Sortierung: ${filters.sortBy === 'name' ? 'Name' : filters.sortBy === 'recent' ? 'Neueste' : 'Bio'}`}
                  onRemove={() => updateFilters({ sortBy: 'verified' })}
                />
              )}
              <button
                onClick={() => setFilters(DEFAULT_FILTERS)}
                className="text-xs text-red-500 hover:text-red-700 px-2 py-1 rounded-full hover:bg-red-50 transition-colors"
              >
                Alle löschen
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ── Content ──────────────────────────────────────────── */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-6">

        {/* Stats bar */}
        <div className="flex items-center justify-between mb-5 flex-wrap gap-2">
          <p className="text-sm text-gray-500">
            {loading ? (
              <span className="flex items-center gap-2">
                <RefreshCw className="w-4 h-4 animate-spin text-green-500" /> Lade Betriebe…
              </span>
            ) : (
              <>
                <span className="font-semibold text-gray-900">{total.toLocaleString()}</span> Betriebe gefunden
                {debouncedQ && <span> für „<em>{debouncedQ}</em>"</span>}
              </>
            )}
          </p>
          <div className="flex items-center gap-2">
            {favorites.length > 0 && (
              <span className="text-xs text-gray-500">❤️ {favorites.length} Favoriten</span>
            )}
            {pages > 1 && viewMode === 'list' && (
              <p className="text-xs text-gray-400">Seite {page} von {pages}</p>
            )}
          </div>
        </div>

        {/* Sortierung Inline (nur Listenansicht) */}
        {viewMode === 'list' && !loading && farms.length > 0 && (
          <div className="flex items-center gap-2 mb-4">
            <ArrowUpDown className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-xs text-gray-500">Sortieren:</span>
            {([
              { value: 'verified', label: 'Verifiziert' },
              { value: 'name',     label: 'Name A–Z' },
              { value: 'recent',   label: 'Neueste' },
              { value: 'bio',      label: 'Bio' },
            ] as const).map(({ value, label }) => (
              <button
                key={value}
                onClick={() => updateFilters({ sortBy: value })}
                className={`px-3 py-1 rounded-full text-xs font-medium border transition-all ${
                  filters.sortBy === value ? 'bg-green-600 text-white border-green-600' : 'border-gray-200 text-gray-600 hover:border-green-300'
                }`}
              >
                {label}
              </button>
            ))}
          </div>
        )}

        {/* Map View */}
        {viewMode === 'map' && (
          <div className="mb-6">
            <FarmsMapView
              searchQ={debouncedQ}
              filters={mapFilters}
              selectedFarm={selectedFarm}
              onSelectFarm={setSelectedFarm}
            />
          </div>
        )}

        {/* List View */}
        {viewMode === 'list' && (
          <>
            {loading ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                {Array.from({ length: 12 }).map((_, i) => (
                  <div key={i} className="bg-gray-100 rounded-2xl h-64 animate-pulse" />
                ))}
              </div>
            ) : farms.length === 0 ? (
              <div className="text-center py-20">
                <span className="text-6xl mb-4 block">🌾</span>
                <h3 className="text-xl font-semibold text-gray-800 mb-2">Keine Betriebe gefunden</h3>
                <p className="text-gray-500 mb-6">Versuche andere Suchbegriffe oder Filter.</p>
                <button
                  onClick={() => { setSearchQuery(''); setFilters(DEFAULT_FILTERS) }}
                  className="px-6 py-3 bg-green-600 text-white rounded-xl font-medium hover:bg-green-700 transition-colors"
                >
                  Filter zurücksetzen
                </button>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                {farms.map((farm) => (
                  <FarmCard
                    key={farm.id}
                    farm={farm}
                    isFav={favorites.includes(farm.id)}
                    onToggleFav={() => toggleFav(farm.id)}
                  />
                ))}
              </div>
            )}
            <Pagination page={page} pages={pages} onChange={setPage} />
          </>
        )}

        {/* Map Mode – selected farm card */}
        {viewMode === 'map' && selectedFarm && (
          <div className="mt-4 max-w-sm">
            <FarmCard
              farm={selectedFarm}
              isFav={favorites.includes(selectedFarm.id)}
              onToggleFav={() => toggleFav(selectedFarm.id)}
            />
          </div>
        )}

        {/* CTA */}
        <div className="mt-12 bg-gradient-to-r from-green-600 to-primary-600 rounded-3xl p-8 text-white text-center">
          <div className="text-4xl mb-3">🏡</div>
          <h3 className="text-xl font-bold mb-2">Deinen Betrieb eintragen?</h3>
          <p className="text-green-100 text-sm mb-5 max-w-md mx-auto">
            Du führst einen Hof, Hofladen oder Direktvermarktungsbetrieb? Trage dich kostenlos ein und
            werde von tausenden Mensaena-Nutzern entdeckt.
          </p>
          <Link
            href="/dashboard/supply/farm/add"
            className="inline-flex items-center gap-2 bg-white text-green-700 px-6 py-3 rounded-xl font-semibold hover:bg-green-50 transition-colors"
          >
            Jetzt kostenlos eintragen <ArrowRight className="w-4 h-4" />
          </Link>
        </div>
      </div>
    </div>
  )
}

function FilterChip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <span className="inline-flex items-center gap-1.5 bg-green-100 text-green-800 text-xs font-medium px-3 py-1.5 rounded-full">
      {label}
      <button onClick={onRemove} className="hover:text-red-600 transition-colors"><X className="w-3 h-3" /></button>
    </span>
  )
}
