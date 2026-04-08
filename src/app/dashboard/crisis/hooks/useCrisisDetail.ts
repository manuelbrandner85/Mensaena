'use client'

import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useCrisisStore } from '../stores/useCrisisStore'

/**
 * Detail hook – loads a single crisis with updates and helpers.
 * Sets up realtime subscriptions for that crisis's updates/helpers.
 */
export function useCrisisDetail(crisisId: string) {
  const store = useCrisisStore()

  useEffect(() => {
    if (!crisisId) return
    store.loadCrisisDetail(crisisId)
    store.loadUpdates(crisisId)
    store.loadHelpers(crisisId)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [crisisId])

  // Realtime for updates and helpers of this crisis
  useEffect(() => {
    if (!crisisId) return
    const supabase = createClient()

    const channel = supabase
      .channel(`crisis-detail:${crisisId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'crisis_updates', filter: `crisis_id=eq.${crisisId}` },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            // Re-fetch to get profile data
            store.loadUpdates(crisisId)
          }
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'crisis_helpers', filter: `crisis_id=eq.${crisisId}` },
        (payload) => {
          store.loadHelpers(crisisId)
          // Also refresh the crisis to update helper_count
          store.loadCrisisDetail(crisisId)
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'crises', filter: `id=eq.${crisisId}` },
        (payload) => store.handleRealtimeCrisis(payload)
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [crisisId])

  return {
    crisis: store.currentCrisis,
    updates: store.updates,
    helpers: store.helpers,
    loading: store.loadingDetail,
    loadingUpdates: store.loadingUpdates,
    loadingHelpers: store.loadingHelpers,
    updateCrisisStatus: store.updateCrisisStatus,
    verifyCrisis: store.verifyCrisis,
    markFalseAlarm: store.markFalseAlarm,
    addUpdate: store.addUpdate,
    uploadImage: store.uploadImage,
  }
}
