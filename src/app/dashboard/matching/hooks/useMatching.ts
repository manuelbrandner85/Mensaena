/**
 * Mensaena Matching Hook
 * Convenience hook that wraps the matching store with auth guard
 * and lifecycle management.
 */

'use client'

import { useEffect, useCallback, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'react-hot-toast'
import { useMatchingStore } from '../stores/useMatchingStore'
import type { MatchFilter } from '../types'

export function useMatching() {
  const router = useRouter()
  const store = useMatchingStore()
  const initialized = useRef(false)

  // ── Auth guard & init ─────────────────────────────────────────
  useEffect(() => {
    if (initialized.current) return

    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) {
        router.replace('/auth')
        return
      }
      if (!initialized.current) {
        initialized.current = true
        store.init(user.id)
      }
    })

    return () => {
      // Cleanup on unmount is handled by the store's unsubscribe
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Accept match ──────────────────────────────────────────────
  const acceptMatch = useCallback(
    async (matchId: string) => {
      const result = await store.respondToMatch(matchId, true)
      if (result.success) {
        if (result.conversation_id) {
          toast.success('Match akzeptiert! Chat wurde erstellt.')
        } else {
          toast.success('Du hast zugestimmt! Warte auf die andere Seite.')
        }
      } else {
        toast.error('Fehler beim Akzeptieren des Matchs')
      }
      return result
    },
    [store],
  )

  // ── Decline match ─────────────────────────────────────────────
  const declineMatch = useCallback(
    async (matchId: string, reason?: string) => {
      const result = await store.respondToMatch(matchId, false, reason)
      if (result.success) {
        toast.success('Match abgelehnt')
      } else {
        toast.error('Fehler beim Ablehnen')
      }
      return result
    },
    [store],
  )

  // ── Open chat from accepted match ─────────────────────────────
  const openChat = useCallback(
    (conversationId: string) => {
      router.push(`/dashboard/chat?conv=${conversationId}`)
    },
    [router],
  )

  // ── Refresh ───────────────────────────────────────────────────
  const refresh = useCallback(async () => {
    await Promise.all([store.loadMatches(), store.loadCounts()])
  }, [store])

  // ── Set filter ────────────────────────────────────────────────
  const setFilter = useCallback(
    (filter: MatchFilter) => {
      store.setFilter(filter)
    },
    [store],
  )

  return {
    // State
    matches: store.matches,
    preferences: store.preferences,
    counts: store.counts,
    filter: store.filter,
    loading: store.loading,
    loadingMore: store.loadingMore,
    hasMore: store.hasMore,
    respondingId: store.respondingId,
    preferencesLoading: store.preferencesLoading,
    userId: store._userId,

    // Actions
    acceptMatch,
    declineMatch,
    openChat,
    refresh,
    setFilter,
    loadMore: store.loadMore,
    markAsSeen: store.markAsSeen,
    updatePreferences: store.updatePreferences,
    loadPreferences: store.loadPreferences,
  }
}
