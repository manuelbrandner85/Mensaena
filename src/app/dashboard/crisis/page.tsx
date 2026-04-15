'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import dynamic from 'next/dynamic'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  Siren, Plus, RefreshCw, Search, Filter, MapPin,
  List, Map as MapIcon, ChevronDown, X,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { useCrisis } from './hooks/useCrisis'
import CrisisDashboard from './components/CrisisDashboard'
import CrisisCard from './components/CrisisCard'
import CrisisEmptyState from './components/CrisisEmptyState'
import CrisisSkeleton from './components/CrisisSkeleton'
import QuickHelpNumbers from './components/QuickHelpNumbers'
import SOSButton from './components/SOSButton'

// Lazy-load the map (Leaflet, pulls in large chunk) and the SOS modal
// (only opened on user action). Both should not block the initial route JS.
const CrisisMap = dynamic(() => import('./components/CrisisMap'), {
  ssr: false,
  loading: () => (
    <div className="h-[500px] rounded-2xl bg-stone-100 animate-pulse" />
  ),
})
const SOSModal = dynamic(() => import('./components/SOSModal'), {
  ssr: false,
})
import {
  CRISIS_CATEGORY_CONFIG, URGENCY_CONFIG, STATUS_CONFIG,
  type CrisisCategory, type CrisisUrgency, type CrisisStatus,
} from './types'

export default function CrisisPage() {
  const router = useRouter()
  const [userId, setUserId] = useState<string | null>(null)
  const [authLoading, setAuthLoading] = useState(true)
  const [view, setView] = useState<'list' | 'map'>('list')
  const [showFilters, setShowFilters] = useState(false)
  const [sosOpen, setSosOpen] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const loadMoreRef = useRef<HTMLDivElement>(null)

  // Auth check
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    })
  }, [router])

  const {
    crises, stats, loading, loadingStats, hasMore,
    filters, setFilters, resetFilters, loadMore, refresh,
  } = useCrisis(userId ?? undefined)

  const handleRefresh = useCallback(async () => {
    setRefreshing(true)
    await refresh()
    setRefreshing(false)
  }, [refresh])

  // Infinite scroll
  useEffect(() => {
    if (!loadMoreRef.current || !hasMore) return
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) loadMore() },
      { rootMargin: '200px' }
    )
    observer.observe(loadMoreRef.current)
    return () => observer.disconnect()
  }, [hasMore, loadMore])

  if (authLoading) {
    return <CrisisSkeleton />
  }

  return (
    <div className="max-w-5xl mx-auto">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 16 / Krisenhilfe</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-red-50 border border-red-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Siren className="w-6 h-6 text-red-600" />
            </div>
            <div>
              <h1 className="page-title">Krisenhilfe</h1>
              <p className="page-subtitle mt-2">Notfall-Koordination und <span className="text-accent">schnelle Hilfe</span>.</p>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-shrink-0">
            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="p-2.5 rounded-full text-ink-400 hover:bg-stone-100 hover:text-ink-700 transition"
              aria-label="Aktualisieren"
            >
              <RefreshCw className={cn('w-4 h-4', refreshing && 'animate-spin')} />
            </button>
            <SOSButton onClick={() => setSosOpen(true)} size="sm" />
            <Link
              href="/dashboard/crisis/create"
              className="magnetic shine inline-flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-red-600 text-white text-sm font-medium tracking-wide hover:bg-red-700 transition-colors shadow-md shadow-red-200/60"
            >
              <Plus className="w-4 h-4" />
              <span>Krise melden</span>
            </Link>
          </div>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      {/* Stats dashboard */}
      <div className="mb-6">
        <CrisisDashboard stats={stats} loading={loadingStats} />
      </div>

      {/* Filters & View Toggle */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 mb-4">
        <div className="flex items-center gap-2 flex-1 w-full sm:w-auto">
          {/* Search */}
          <div className="relative flex-1 sm:max-w-xs">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={filters.search}
              onChange={e => setFilters({ search: e.target.value })}
              placeholder="Krisen suchen..."
              className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
              aria-label="Krisen durchsuchen"
            />
            {filters.search && (
              <button
                onClick={() => setFilters({ search: '' })}
                className="absolute right-3 top-1/2 -translate-y-1/2"
                aria-label="Suche leeren"
              >
                <X className="w-4 h-4 text-gray-400" />
              </button>
            )}
          </div>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={cn(
              'p-2 rounded-xl border transition-colors',
              showFilters ? 'bg-red-50 border-red-200 text-red-600' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50',
            )}
            aria-label="Filter anzeigen"
            aria-expanded={showFilters}
          >
            <Filter className="w-4 h-4" />
          </button>
        </div>

        {/* View toggle */}
        <div className="flex items-center bg-gray-100 rounded-xl p-0.5">
          <button
            onClick={() => setView('list')}
            className={cn(
              'flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
              view === 'list' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700',
            )}
          >
            <List className="w-3 h-3" />
            Liste
          </button>
          <button
            onClick={() => setView('map')}
            className={cn(
              'flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
              view === 'map' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700',
            )}
          >
            <MapIcon className="w-3 h-3" />
            Karte
          </button>
        </div>
      </div>

      {/* Expanded filters */}
      {showFilters && (
        <div className="bg-white border border-gray-200 rounded-2xl p-4 mb-4 animate-slide-up">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {/* Status filter */}
            <div>
              <label className="text-xs font-semibold text-gray-600 mb-1 block">Status</label>
              <select
                value={filters.status}
                onChange={e => setFilters({ status: e.target.value as CrisisStatus | 'all' })}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                aria-label="Status filtern"
              >
                <option value="all">Alle aktiven</option>
                {(Object.entries(STATUS_CONFIG) as [CrisisStatus, typeof STATUS_CONFIG[CrisisStatus]][]).map(([key, cfg]) => (
                  <option key={key} value={key}>{cfg.label}</option>
                ))}
              </select>
            </div>

            {/* Category filter */}
            <div>
              <label className="text-xs font-semibold text-gray-600 mb-1 block">Kategorie</label>
              <select
                value={filters.category}
                onChange={e => setFilters({ category: e.target.value as CrisisCategory | 'all' })}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                aria-label="Kategorie filtern"
              >
                <option value="all">Alle</option>
                {(Object.entries(CRISIS_CATEGORY_CONFIG) as [CrisisCategory, typeof CRISIS_CATEGORY_CONFIG[CrisisCategory]][]).map(([key, cfg]) => (
                  <option key={key} value={key}>{cfg.emoji} {cfg.label}</option>
                ))}
              </select>
            </div>

            {/* Urgency filter */}
            <div>
              <label className="text-xs font-semibold text-gray-600 mb-1 block">Dringlichkeit</label>
              <select
                value={filters.urgency}
                onChange={e => setFilters({ urgency: e.target.value as CrisisUrgency | 'all' })}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                aria-label="Dringlichkeit filtern"
              >
                <option value="all">Alle</option>
                {(Object.entries(URGENCY_CONFIG) as [CrisisUrgency, typeof URGENCY_CONFIG[CrisisUrgency]][]).map(([key, cfg]) => (
                  <option key={key} value={key}>{cfg.label}</option>
                ))}
              </select>
            </div>
          </div>

          {(filters.status !== 'all' || filters.category !== 'all' || filters.urgency !== 'all') && (
            <button
              onClick={resetFilters}
              className="mt-3 text-xs text-red-600 hover:text-red-700 font-medium"
            >
              Filter zurücksetzen
            </button>
          )}
        </div>
      )}

      {/* Active Crisis Alert Banner */}
      {!loading && crises.filter(c => c.status === 'active' || c.status === 'in_progress').length > 0 && (
        <div className="mb-4 p-4 bg-red-50 border-2 border-red-300 rounded-2xl animate-pulse-slow">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
              <Siren className="w-5 h-5 text-red-600 animate-bounce" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold text-red-800">
                {crises.filter(c => c.status === 'active' || c.status === 'in_progress').length} aktive Krise(n) in deiner Umgebung
              </p>
              <p className="text-xs text-red-600 mt-0.5">Bitte prüfen und ggf. Hilfe anbieten</p>
            </div>
          </div>
        </div>
      )}

      {/* Content */}
      {loading ? (
        <CrisisSkeleton />
      ) : view === 'map' ? (
        <div className="mb-6">
          <CrisisMap
            crises={crises}
            height="h-[500px]"
            onCrisisClick={(crisis) => router.push(`/dashboard/crisis/${crisis.id}`)}
          />
        </div>
      ) : crises.length === 0 ? (
        <CrisisEmptyState />
      ) : (
        <div className="space-y-3 mb-6">
          {crises.map(crisis => (
            <CrisisCard key={crisis.id} crisis={crisis} userId={userId ?? undefined} />
          ))}

          {/* Load more trigger */}
          {hasMore && (
            <div ref={loadMoreRef} className="py-4 text-center">
              <div className="inline-flex items-center gap-2 text-sm text-gray-500">
                <RefreshCw className="w-4 h-4 animate-spin" />
                Weitere Krisen laden...
              </div>
            </div>
          )}
        </div>
      )}

      {/* Emergency numbers sidebar (below on mobile, right column on desktop) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2">
          <Link
            href="/dashboard/crisis/resources"
            className="block p-4 bg-gradient-to-r from-primary-50 to-cyan-50 border border-primary-200 rounded-2xl hover:shadow-md transition-all"
          >
            <h3 className="text-sm font-bold text-primary-800 mb-1">Ressourcen & Hilfsangebote</h3>
            <p className="text-xs text-primary-600">Professionelle Hilfsangebote, Anlaufstellen und Ressourcen in deiner Nähe</p>
          </Link>
        </div>
        <div>
          <QuickHelpNumbers compact={true} />
        </div>
      </div>

      {/* SOS Modal */}
      <SOSModal isOpen={sosOpen} onClose={() => setSosOpen(false)} />
    </div>
  )
}
