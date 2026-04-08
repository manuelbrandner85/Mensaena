'use client'

import { useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useCrisisStore } from '../stores/useCrisisStore'

/**
 * Main crisis hook – loads crisis list, stats, emergency numbers
 * Sets up realtime subscriptions for the crises table
 */
export function useCrisis(userId?: string) {
  const store = useCrisisStore()

  // Initial load
  useEffect(() => {
    store.loadCrises()
    store.loadStats()
    store.loadEmergencyNumbers()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Re-load when filters change
  useEffect(() => {
    store.loadCrises()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [store.filters.status, store.filters.category, store.filters.urgency, store.filters.search])

  // Realtime subscription for crises
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel('crises-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'crises' },
        (payload) => store.handleRealtimeCrisis(payload)
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const refresh = useCallback(() => {
    store.loadCrises()
    store.loadStats()
  }, [store])

  return {
    crises: store.crises,
    stats: store.stats,
    emergencyNumbers: store.emergencyNumbers,
    loading: store.loading,
    loadingStats: store.loadingStats,
    hasMore: store.hasMore,
    filters: store.filters,
    setFilters: store.setFilters,
    resetFilters: store.resetFilters,
    loadMore: store.loadMoreCrises,
    createCrisis: store.createCrisis,
    uploadImage: store.uploadImage,
    refresh,
  }
}
