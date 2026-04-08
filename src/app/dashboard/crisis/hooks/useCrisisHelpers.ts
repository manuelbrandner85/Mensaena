'use client'

import { useEffect, useMemo } from 'react'
import { useCrisisStore } from '../stores/useCrisisStore'
import type { HelperStatus } from '../types'

/**
 * Helper-specific hook for a given crisis.
 * Provides helper list, current user's helper status, and actions.
 */
export function useCrisisHelpers(crisisId: string, userId?: string) {
  const store = useCrisisStore()

  useEffect(() => {
    if (crisisId) store.loadHelpers(crisisId)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [crisisId])

  const myHelper = useMemo(() => {
    if (!userId) return null
    return store.helpers.find(h => h.user_id === userId && h.status !== 'withdrawn') ?? null
  }, [store.helpers, userId])

  const activeHelpers = useMemo(() => {
    return store.helpers.filter(h => !['withdrawn', 'completed'].includes(h.status))
  }, [store.helpers])

  const helpersByStatus = useMemo(() => {
    const grouped: Record<HelperStatus, typeof store.helpers> = {
      offered: [], accepted: [], on_way: [], arrived: [], completed: [], withdrawn: [],
    }
    for (const h of store.helpers) {
      grouped[h.status].push(h)
    }
    return grouped
  }, [store.helpers])

  return {
    helpers: store.helpers,
    activeHelpers,
    helpersByStatus,
    myHelper,
    loading: store.loadingHelpers,
    offerHelp: store.offerHelp,
    withdrawHelp: store.withdrawHelp,
    updateHelperStatus: store.updateHelperStatus,
  }
}
