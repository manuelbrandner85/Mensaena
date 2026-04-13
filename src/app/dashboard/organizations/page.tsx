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
    <div className="min-h-screen bg-gray-50">
      {/* Hero header */}
      <div className="bg-gradient-to-br from-primary-600 via-primary-500 to-teal-500 px-4 pt-6 pb-8">
        <div className="max-w-5xl mx-auto">
          <div className="flex items-center gap-2 mb-1">
            <Building2 className="w-6 h-6 text-white/80" />
            <span className="text-white/80 text-sm font-medium">Hilfsverzeichnis</span>
          </div>
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <h1 className="text-2xl font-bold text-white mb-1">Hilfsorganisationen</h1>
              <p className="text-primary-100 text-sm">
                Tierheime, Tafeln, Beratungsstellen und mehr – für Deutschland, Österreich und die Schweiz
              </p>
            </div>
            <div className="flex gap-2">
              <Link
                href="/dashboard/organizations/suggest"
                className="flex items-center gap-1.5 px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-sm font-medium transition-colors"
              >
                <Plus className="w-4 h-4" />
                Vorschlagen
              </Link>
              <button
                onClick={requestLocation}
                className="flex items-center gap-1.5 px-3 py-2 bg-white/10 hover:bg-white/20 text-white rounded-xl text-sm transition-colors"
                title="Meinen Standort verwenden"
                aria-label="Standort ermitteln"
              >
                <Navigation className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search */}
          <div className="relative mt-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={searchInput}
              onChange={e => handleSearch(e.target.value)}
              placeholder="Organisation, Stadt oder Stichwort suchen..."
              className="w-full pl-9 pr-4 py-3 rounded-xl bg-white text-gray-800 placeholder-gray-400 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
              aria-label="Organisationen suchen"
            />
            {searchInput && (
              <button
                onClick={() => { setSearchInput(''); setFilters({ search: '' }) }}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                aria-label="Suche löschen"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 -mt-2">
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
