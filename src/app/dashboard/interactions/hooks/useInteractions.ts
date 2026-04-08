'use client'

import { useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useInteractionStore } from '../stores/useInteractionStore'
import type { InteractionFilter } from '../types'

export function useInteractions() {
  const {
    interactions, stats, counts, loading, filter, hasMore,
    loadInteractions, loadMore, loadStats, loadCounts,
    createInteraction, setFilter, subscribeRealtime, unsubscribeRealtime,
  } = useInteractionStore()

  useEffect(() => {
    loadInteractions()
    loadStats()
    loadCounts()

    let userId: string | null = null
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        userId = user.id
        subscribeRealtime(user.id)
      }
    })

    return () => { unsubscribeRealtime() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleSetFilter = useCallback((f: Partial<InteractionFilter>) => {
    setFilter(f)
    const newFilter = { ...filter, ...f }
    loadInteractions(newFilter)
  }, [filter, setFilter, loadInteractions])

  return {
    interactions,
    stats,
    counts,
    loading,
    filter,
    hasMore,
    setFilter: handleSetFilter,
    loadMore,
    createInteraction,
    requestedCount: counts?.requested ?? 0,
    activeCount: counts?.active ?? 0,
    awaitingRatingCount: counts?.awaiting_rating ?? 0,
  }
}
