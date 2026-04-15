'use client'

import { useState, useCallback } from 'react'
import { Building2, Search, Plus, RefreshCw, Navigation, X, Map as MapIcon } from 'lucide-react'
import { cn } from '@/lib/utils'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { useOrganizations } from './hooks/useOrganizations'
import type { Organization } from './types'
import OrganizationsList from './components/OrganizationsList'
import OrganizationFilters from './components/OrganizationFilters'
import OrganizationStatsBar from './components/OrganizationStatsBar'
import OrganizationSkeleton from './components/OrganizationSkeleton'
import { OrganizationsInvite } from '@/components/features/admin'

const OrganizationMap = dynamic(() => import('./components/OrganizationMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-gray-100 rounded-2xl">
      <div className="text-gray-400 text-sm flex items-center gap-2">
        <RefreshCw className="w-4 h-4 animate-spin" />
        Karte wird geladen...
      </div>
    </div>
  ),
})

export default function OrganizationsPage() {
  const {
    organizations, stats, loading, loadingStats,
    hasMore, filters, setFilters, resetFilters, loadMore, refresh,
  } = useOrganizations()

  const [viewMode, setViewMode] = useState<'list' | 'map'>('list')
  const [selectedOrg, setSelectedOrg] = useState<Organization | null>(null)
  const [searchInput, setSearchInput] = useState('')

  const handleSearch = useCallback((value: string) => {
    setSearchInput(value)
    // Debounce search
    const timer = setTimeout(() => {
      setFilters({ search: value })
    }, 350)
    return () => clearTimeout(timer)
  }, [setFilters])

  const handleShowOnMap = useCallback((org: Organization) => {
    setSelectedOrg(org)
    setViewMode('map')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  // Detect user location for distance sorting
  const requestLocation = useCallback(() => {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setFilters({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
          sort_by: 'distance',
        })
      },
      () => { /* permission denied or error */ }
    )
  }, [setFilters])

  const orgsWithCoords = organizations.filter(o => o.latitude && o.longitude)

  return (
    <div className="max-w-5xl mx-auto px-4 py-6">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 14 / Hilfsverzeichnis</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Building2 className="w-6 h-6 text-primary-700" />
            </div>
            <div>
              <h1 className="page-title">Hilfsorganisationen</h1>
              <p className="page-subtitle mt-2">Tierheime, Tafeln, <span className="text-accent">Beratungsstellen</span> – DE · AT · CH.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            <button
              onClick={requestLocation}
              className="p-2.5 rounded-full text-ink-400 hover:bg-stone-100 hover:text-ink-700 transition"
              title="Meinen Standort verwenden"
              aria-label="Standort ermitteln"
            >
              <Navigation className="w-4 h-4" />
            </button>
            <Link
              href="/dashboard/organizations/suggest"
              className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-ink-800 text-paper text-sm font-medium tracking-wide hover:bg-ink-700 transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span>Vorschlagen</span>
            </Link>
          </div>
        </div>

        {/* Search */}
        <div className="relative mt-6">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
          <input
            type="text"
            value={searchInput}
            onChange={e => handleSearch(e.target.value)}
            placeholder="Organisation, Stadt oder Stichwort suchen..."
            className="w-full pl-11 pr-10 py-3 rounded-full bg-paper border border-stone-200 text-ink-800 placeholder-ink-400 text-sm shadow-soft focus:outline-none focus:ring-2 focus:ring-primary-300 focus:border-primary-300"
            aria-label="Organisationen suchen"
          />
          {searchInput && (
            <button
              onClick={() => { setSearchInput(''); setFilters({ search: '' }) }}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-ink-400 hover:text-ink-700"
              aria-label="Suche löschen"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div>
        <div className="mb-4">
          <OrganizationsInvite />
        </div>

        {/* Stats */}
        <div className="mt-4">
          <OrganizationStatsBar stats={stats} loading={loadingStats} />
        </div>

        {/* Filters */}
        <OrganizationFilters
          filters={filters}
          onSetFilters={setFilters}
          onReset={resetFilters}
          viewMode={viewMode}
          onViewModeChange={setViewMode}
          totalCount={organizations.length}
          mapCount={orgsWithCoords.length}
          loading={loading}
        />

        {/* Map view */}
        {viewMode === 'map' && (
          <div className="mt-4 pb-8">
            {selectedOrg && (
              <div className="mb-2 flex items-center gap-2 bg-primary-50 border border-primary-200 rounded-xl px-3 py-2">
                <Navigation className="w-3.5 h-3.5 text-primary-600 flex-shrink-0" />
                <span className="text-xs text-primary-700 font-medium flex-1">Fokus: {selectedOrg.name}</span>
                <button onClick={() => setSelectedOrg(null)} className="text-primary-400 hover:text-primary-700" aria-label="Auswahl aufheben">
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
            {orgsWithCoords.length === 0 ? (
              <div className="bg-white rounded-2xl border border-gray-100 p-8 text-center">
                <MapIcon className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-500 font-medium text-sm">Keine Koordinaten verfügbar</p>
              </div>
            ) : (
              <div className="rounded-2xl overflow-hidden border border-gray-200 shadow-sm" style={{ height: '520px' }}>
                <OrganizationMap organizations={orgsWithCoords} selectedOrg={selectedOrg} onOrgSelect={setSelectedOrg} />
              </div>
            )}
            <p className="text-xs text-gray-400 text-center mt-2">
              {orgsWithCoords.length} von {organizations.length} Organisationen mit GPS-Koordinaten
            </p>
          </div>
        )}

        {/* List view */}
        {viewMode === 'list' && (
          <div className="mt-4 pb-8">
            {loading && organizations.length === 0 ? (
              <OrganizationSkeleton />
            ) : (
              <OrganizationsList
                organizations={organizations}
                loading={loading}
                hasMore={hasMore}
                onLoadMore={loadMore}
                onShowOnMap={handleShowOnMap}
              />
            )}
          </div>
        )}
      </div>
    </div>
  )
}
