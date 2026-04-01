'use client'

export const runtime = 'edge'

import { useEffect, useState, useCallback, useRef } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import {
  Search, Filter, MapPin, Phone, Globe, Leaf, CheckCircle2,
  Truck, Scissors, ShoppingBag, X, ChevronDown, SlidersHorizontal,
  Star, ArrowRight, RefreshCw, Map, List
} from 'lucide-react'
import type { FarmListing, FarmCategory } from '@/types/farm'
import { FARM_CATEGORIES, FARM_PRODUCTS, CATEGORY_ICONS, CATEGORY_COLORS, COUNTRY_LABELS } from '@/types/farm'

// Karte lazy laden
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

// ─── FarmCard ────────────────────────────────────────────────
function FarmCard({ farm }: { farm: FarmListing }) {
  const categoryColor = CATEGORY_COLORS[farm.category] ?? 'bg-gray-100 text-gray-700'
  const categoryIcon = CATEGORY_ICONS[farm.category] ?? '🏡'

  return (
    <Link
      href={`/dashboard/supply/farm/${farm.slug}`}
      className="group bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-lg hover:border-green-300 transition-all duration-200 overflow-hidden flex flex-col"
    >
      {/* Header */}
      <div className="bg-gradient-to-br from-green-50 to-emerald-50 px-5 pt-5 pb-4">
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

        {/* Produkte */}
        {farm.products.length > 0 && (
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

        {/* Lieferung */}
        {farm.delivery_options.length > 0 && (
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
            <a
              href={`tel:${farm.phone}`}
              onClick={(e) => e.stopPropagation()}
              className="flex items-center gap-1 text-xs text-gray-500 hover:text-green-700"
            >
              <Phone className="w-3.5 h-3.5" />
            </a>
          )}
          {farm.website && (
            <a
              href={farm.website}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
              className="flex items-center gap-1 text-xs text-gray-500 hover:text-green-700"
            >
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
  )
}

// ─── FilterPanel ─────────────────────────────────────────────
interface Filters {
  category: string
  country: string
  bio: boolean
  delivery: boolean
  product: string
  state: string
}

function FilterPanel({
  filters,
  onChange,
  onReset,
  activeCount,
}: {
  filters: Filters
  onChange: (f: Partial<Filters>) => void
  onReset: () => void
  activeCount: number
}) {
  const [open, setOpen] = useState(false)

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
        Filter
        {activeCount > 0 && (
          <span className="bg-white text-green-700 text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
            {activeCount}
          </span>
        )}
        <ChevronDown className={`w-4 h-4 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>

      {open && (
        <div className="absolute top-full mt-2 right-0 z-50 bg-white rounded-2xl shadow-xl border border-gray-100 p-5 w-80 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-gray-900">Filter</h3>
            <button onClick={() => setOpen(false)} className="text-gray-400 hover:text-gray-600">
              <X className="w-4 h-4" />
            </button>
          </div>

          {/* Kategorie */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">Typ</label>
            <div className="flex flex-wrap gap-1.5">
              <button
                onClick={() => onChange({ category: '' })}
                className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                  !filters.category ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                }`}
              >
                Alle
              </button>
              {FARM_CATEGORIES.map((c) => (
                <button
                  key={c}
                  onClick={() => onChange({ category: c })}
                  className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                    filters.category === c ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
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
                  onClick={() => onChange({ country: c })}
                  className={`flex-1 py-1.5 rounded-xl text-xs font-medium border transition-all ${
                    filters.country === c ? 'bg-green-600 text-white border-green-600' : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-green-300'
                  }`}
                >
                  {c === '' ? 'Alle' : COUNTRY_LABELS[c]}
                </button>
              ))}
            </div>
          </div>

          {/* Produkt */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 block">Produkt</label>
            <select
              value={filters.product}
              onChange={(e) => onChange({ product: e.target.value })}
              className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
            >
              <option value="">Alle Produkte</option>
              {FARM_PRODUCTS.map((p) => (
                <option key={p} value={p}>{p}</option>
              ))}
            </select>
          </div>

          {/* Checkboxes */}
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

// ─── Hauptseite ──────────────────────────────────────────────
const DEFAULT_FILTERS: Filters = {
  category: '', country: '', bio: false, delivery: false, product: '', state: '',
}

export default function SupplyPage() {
  const [farms, setFarms] = useState<FarmListing[]>([])
  const [total, setTotal] = useState(0)
  const [pages, setPages] = useState(1)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [viewMode, setViewMode] = useState<'list' | 'map'>('list')
  const [searchQuery, setSearchQuery] = useState('')
  const [debouncedQ, setDebouncedQ] = useState('')
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [selectedFarm, setSelectedFarm] = useState<FarmListing | null>(null)

  // Debounce search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => setDebouncedQ(searchQuery), 400)
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current) }
  }, [searchQuery])

  // Fetch
  const fetchFarms = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ page: String(page), limit: '24' })
      if (debouncedQ) params.set('q', debouncedQ)
      if (filters.category) params.set('category', filters.category)
      if (filters.country) params.set('country', filters.country)
      if (filters.bio) params.set('bio', 'true')
      if (filters.delivery) params.set('delivery', 'true')
      if (filters.product) params.set('product', filters.product)
      if (filters.state) params.set('state', filters.state)

      const res = await fetch(`/api/farms?${params}`)
      const json = await res.json()
      setFarms(json.farms || [])
      setTotal(json.total || 0)
      setPages(json.pages || 1)
    } catch {
      setFarms([])
    } finally {
      setLoading(false)
    }
  }, [page, debouncedQ, filters])

  useEffect(() => { fetchFarms() }, [fetchFarms])

  // Reset page on filter/search change
  useEffect(() => { setPage(1) }, [debouncedQ, filters])

  const activeFilterCount = [
    filters.category, filters.country, filters.product, filters.state,
    filters.bio ? 'bio' : '', filters.delivery ? 'del' : '',
  ].filter(Boolean).length

  const updateFilters = (partial: Partial<Filters>) =>
    setFilters((prev) => ({ ...prev, ...partial }))

  return (
    <div className="min-h-screen bg-gradient-to-b from-green-50/40 to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-yellow-500 to-amber-600 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
          <div className="flex items-start justify-between gap-6">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <span className="text-3xl">🌾</span>
                <h1 className="text-2xl md:text-3xl font-bold">Regionale Versorgung</h1>
              </div>
              <p className="text-amber-100 text-sm md:text-base max-w-xl">
                Entdecke {total > 0 ? total.toLocaleString() : '100+'} Bauernhöfe, Hofläden und Direktvermarkter
                aus Österreich, Deutschland & der Schweiz – direkt vom Erzeuger.
              </p>
              <div className="flex flex-wrap gap-3 mt-4">
                {[
                  { icon: <Leaf className="w-4 h-4" />, label: 'Bio & Regional' },
                  { icon: <Truck className="w-4 h-4" />, label: 'Lieferung verfügbar' },
                  { icon: <Scissors className="w-4 h-4" />, label: 'Selbsternte' },
                  { icon: <ShoppingBag className="w-4 h-4" />, label: 'Direktkauf' },
                ].map(({ icon, label }) => (
                  <span key={label} className="flex items-center gap-1.5 bg-white/20 backdrop-blur-sm px-3 py-1.5 rounded-full text-xs font-medium">
                    {icon} {label}
                  </span>
                ))}
              </div>
            </div>
            <div className="hidden md:flex gap-3">
              <Link
                href="/dashboard/supply/farm/add"
                className="flex items-center gap-2 bg-white text-amber-700 px-4 py-2.5 rounded-xl font-semibold text-sm hover:bg-amber-50 transition-colors shadow-sm"
              >
                + Betrieb eintragen
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Controls */}
      <div className="sticky top-0 z-40 bg-white/95 backdrop-blur-sm border-b border-gray-100 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3">
          <div className="flex items-center gap-3">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Betrieb, Stadt, Bundesland oder Produkt suchen…"
                className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300 focus:border-transparent bg-gray-50"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Filter */}
            <FilterPanel
              filters={filters}
              onChange={updateFilters}
              onReset={() => setFilters(DEFAULT_FILTERS)}
              activeCount={activeFilterCount}
            />

            {/* View Toggle */}
            <div className="flex bg-gray-100 rounded-xl p-1 gap-1">
              <button
                onClick={() => setViewMode('list')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                  viewMode === 'list' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                <List className="w-4 h-4" />
                <span className="hidden sm:inline">Liste</span>
              </button>
              <button
                onClick={() => setViewMode('map')}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                  viewMode === 'map' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                <Map className="w-4 h-4" />
                <span className="hidden sm:inline">Karte</span>
              </button>
            </div>
          </div>

          {/* Active Filters Chips */}
          {activeFilterCount > 0 && (
            <div className="flex flex-wrap gap-2 mt-2">
              {filters.category && (
                <FilterChip
                  label={`${CATEGORY_ICONS[filters.category as FarmCategory]} ${filters.category}`}
                  onRemove={() => updateFilters({ category: '' })}
                />
              )}
              {filters.country && (
                <FilterChip label={COUNTRY_LABELS[filters.country]} onRemove={() => updateFilters({ country: '' })} />
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
            </div>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-6">
        {/* Stats */}
        <div className="flex items-center justify-between mb-5">
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
          {pages > 1 && (
            <p className="text-xs text-gray-400">Seite {page} von {pages}</p>
          )}
        </div>

        {/* Map View */}
        {viewMode === 'map' && (
          <div className="mb-6">
            <FarmsMapView
              farms={farms}
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
                  <FarmCard key={farm.id} farm={farm} />
                ))}
              </div>
            )}

            {/* Pagination */}
            {pages > 1 && !loading && (
              <div className="flex items-center justify-center gap-2 mt-8">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page === 1}
                  className="px-4 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  ← Zurück
                </button>
                {Array.from({ length: Math.min(pages, 7) }, (_, i) => {
                  const p = i + 1
                  return (
                    <button
                      key={p}
                      onClick={() => setPage(p)}
                      className={`w-9 h-9 rounded-xl text-sm font-medium transition-all ${
                        p === page
                          ? 'bg-green-600 text-white'
                          : 'border border-gray-200 text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      {p}
                    </button>
                  )
                })}
                {pages > 7 && <span className="text-gray-400">…</span>}
                <button
                  onClick={() => setPage((p) => Math.min(pages, p + 1))}
                  disabled={page === pages}
                  className="px-4 py-2 border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  Weiter →
                </button>
              </div>
            )}
          </>
        )}

        {/* Map Mode – selected farm card */}
        {viewMode === 'map' && selectedFarm && (
          <div className="mt-4">
            <FarmCard farm={selectedFarm} />
          </div>
        )}

        {/* CTA – Betrieb eintragen */}
        <div className="mt-12 bg-gradient-to-r from-green-600 to-emerald-600 rounded-3xl p-8 text-white text-center">
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
      <button onClick={onRemove} className="hover:text-red-600 transition-colors">
        <X className="w-3 h-3" />
      </button>
    </span>
  )
}
