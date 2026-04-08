'use client'

import { useEffect, useCallback } from 'react'
import { useOrganizationStore } from '../stores/useOrganizationStore'

/**
 * Main hook – loads organization list and stats.
 * Reloads when filters change.
 */
export function useOrganizations() {
  const store = useOrganizationStore()

  // Initial load
  useEffect(() => {
    store.loadOrganizations()
    store.loadStats()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Re-load when filters change
  useEffect(() => {
    store.loadOrganizations()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    store.filters.search,
    store.filters.category,
    store.filters.country,
    store.filters.verified_only,
    store.filters.is_emergency,
    store.filters.min_rating,
    store.filters.sort_by,
    store.filters.latitude,
    store.filters.longitude,
    store.filters.radius_km,
  ])

  const refresh = useCallback(() => {
    store.loadOrganizations()
    store.loadStats()
  }, [store])

  return {
    organizations: store.organizations,
    stats: store.stats,
    loading: store.loading,
    loadingStats: store.loadingStats,
    hasMore: store.hasMore,
    filters: store.filters,
    setFilters: store.setFilters,
    resetFilters: store.resetFilters,
    loadMore: store.loadMoreOrganizations,
    refresh,
  }
}
