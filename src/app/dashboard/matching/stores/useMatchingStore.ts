/**
 * Mensaena Matching Store (Zustand)
 * Global state for the matching system.
 */

import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import type { RealtimeChannel } from '@supabase/supabase-js'
import type { Match, MatchPreferences, MatchCounts, MatchFilter } from '../types'
import { DEFAULT_PREFERENCES } from '../types'
import {
  fetchMyMatches,
  fetchMatchCounts,
  fetchMatchPreferences,
  saveMatchPreferences,
  respondToMatch as respondToMatchAPI,
  markMatchAsSeen,
  cleanupExpiredMatches,
} from '@/lib/matching/match-algorithm'

const PAGE_SIZE = 20

// ── State ───────────────────────────────────────────────────────────

interface MatchingState {
  matches: Match[]
  preferences: MatchPreferences | null
  counts: MatchCounts
  filter: MatchFilter
  loading: boolean
  loadingMore: boolean
  hasMore: boolean
  page: number
  respondingId: string | null
  preferencesLoading: boolean
  _channel: RealtimeChannel | null
  _userId: string | null
}

// ── Actions ─────────────────────────────────────────────────────────

interface MatchingActions {
  init: (userId: string) => void
  loadMatches: (filter?: MatchFilter) => Promise<void>
  loadMore: () => Promise<void>
  loadPreferences: (userId: string) => Promise<void>
  updatePreferences: (updates: Partial<MatchPreferences>) => Promise<boolean>
  loadCounts: () => Promise<void>
  respondToMatch: (matchId: string, accept: boolean, reason?: string) => Promise<{ success: boolean; conversation_id?: string }>
  markAsSeen: (matchId: string) => Promise<void>
  setFilter: (filter: MatchFilter) => void
  subscribeToRealtime: (userId: string) => void
  unsubscribeFromRealtime: () => void
  reset: () => void
}

// ── Store ───────────────────────────────────────────────────────────

const initialState: MatchingState = {
  matches: [],
  preferences: null,
  counts: { suggested: 0, pending: 0, accepted: 0, completed: 0 },
  filter: 'all',
  loading: false,
  loadingMore: false,
  hasMore: false,
  page: 0,
  respondingId: null,
  preferencesLoading: false,
  _channel: null,
  _userId: null,
}

export const useMatchingStore = create<MatchingState & MatchingActions>()(
  (set, get) => ({
    ...initialState,

    // ── Initialize ────────────────────────────────────────────────
    init: (userId) => {
      set({ _userId: userId })
      get().loadCounts()
      get().loadMatches()
      get().loadPreferences(userId)
      get().subscribeToRealtime(userId)
      // Silently expire stale matches so counts are accurate
      cleanupExpiredMatches().then((n) => {
        if (n > 0) get().loadCounts()
      }).catch(() => {})
    },

    // ── Load matches ──────────────────────────────────────────────
    loadMatches: async (filter) => {
      const currentFilter = filter ?? get().filter
      set({ loading: true, filter: currentFilter, page: 0 })

      const data = await fetchMyMatches(currentFilter, PAGE_SIZE, 0)

      set({
        matches: data,
        loading: false,
        hasMore: data.length >= PAGE_SIZE,
        page: 0,
      })
    },

    // ── Load more (pagination) ───────────────────────────────────
    loadMore: async () => {
      if (get().loadingMore || !get().hasMore) return

      const nextPage = get().page + 1
      const offset = nextPage * PAGE_SIZE
      set({ loadingMore: true })

      const data = await fetchMyMatches(get().filter, PAGE_SIZE, offset)

      set((s) => ({
        matches: [...s.matches, ...data],
        loadingMore: false,
        hasMore: data.length >= PAGE_SIZE,
        page: nextPage,
      }))
    },

    // ── Load preferences ─────────────────────────────────────────
    loadPreferences: async (userId) => {
      set({ preferencesLoading: true })
      const prefs = await fetchMatchPreferences(userId)
      set({
        preferences: prefs || {
          id: '',
          user_id: userId,
          ...DEFAULT_PREFERENCES,
          created_at: '',
          updated_at: '',
        },
        preferencesLoading: false,
      })
    },

    // ── Update preferences ───────────────────────────────────────
    updatePreferences: async (updates) => {
      const userId = get()._userId
      if (!userId) return false

      const ok = await saveMatchPreferences(userId, updates)
      if (ok) {
        set((s) => ({
          preferences: s.preferences
            ? { ...s.preferences, ...updates, updated_at: new Date().toISOString() }
            : null,
        }))
      }
      return ok
    },

    // ── Load counts ──────────────────────────────────────────────
    loadCounts: async () => {
      const counts = await fetchMatchCounts(get()._userId ?? undefined)
      set({ counts })
    },

    // ── Respond to match ─────────────────────────────────────────
    respondToMatch: async (matchId, accept, reason) => {
      set({ respondingId: matchId })
      const result = await respondToMatchAPI(matchId, accept, reason)

      if (result.success) {
        // Update local state
        set((s) => ({
          matches: s.matches.map((m) =>
            m.id === matchId
              ? {
                  ...m,
                  status: (result.status as Match['status']) ?? m.status,
                  conversation_id: result.conversation_id ?? m.conversation_id,
                  ...(accept
                    ? s._userId === m.offer_user_id
                      ? { offer_responded: true, offer_accepted: true }
                      : { request_responded: true, request_accepted: true }
                    : s._userId === m.offer_user_id
                      ? { offer_responded: true, offer_accepted: false }
                      : { request_responded: true, request_accepted: false }),
                }
              : m,
          ),
          respondingId: null,
        }))

        // Refresh counts
        get().loadCounts()
      } else {
        set({ respondingId: null })
      }

      return {
        success: result.success,
        conversation_id: result.conversation_id,
      }
    },

    // ── Mark as seen ─────────────────────────────────────────────
    markAsSeen: async (matchId) => {
      const userId = get()._userId
      if (!userId) return

      await markMatchAsSeen(matchId, userId)

      set((s) => ({
        matches: s.matches.map((m) =>
          m.id === matchId
            ? {
                ...m,
                seen_by_offer: userId === m.offer_user_id ? true : m.seen_by_offer,
                seen_by_request: userId === m.request_user_id ? true : m.seen_by_request,
              }
            : m,
        ),
      }))
    },

    // ── Set filter ───────────────────────────────────────────────
    setFilter: (filter) => {
      set({ filter })
      get().loadMatches(filter)
    },

    // ── Realtime subscription ────────────────────────────────────
    subscribeToRealtime: (userId) => {
      if (get()._channel) get().unsubscribeFromRealtime()

      const supabase = createClient()
      const channel = supabase
        .channel(`matching:${userId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'matches',
          },
          (payload) => {
            const raw = payload.new as Record<string, unknown>
            if (raw.offer_user_id !== userId && raw.request_user_id !== userId) return

            get().loadMatches()
            get().loadCounts()

            // Dispatch in-app toast via the notification system
            if (typeof window !== 'undefined') {
              window.dispatchEvent(new CustomEvent('mensaena-notification', {
                detail: {
                  id: `match-${raw.id}`,
                  type: 'new_match',
                  category: 'interaction',
                  title: 'Neuer Match-Vorschlag',
                  content: `Score: ${Math.round((raw.match_score as number) ?? 0)}%`,
                  link: '/dashboard/matching',
                  read: false,
                },
              }))
            }

            // Client-side auto-accept for matches not yet handled by DB trigger
            const prefs = get().preferences
            const threshold = prefs?.auto_accept_threshold
            if (threshold && (raw.match_score as number) >= threshold) {
              const matchId = raw.id as string
              // Only auto-accept if we haven't already responded (DB handles it for new matches
              // but Realtime might fire before DB trigger completes)
              const isOffer = raw.offer_user_id === userId
              const alreadyResponded = isOffer
                ? raw.offer_responded === true
                : raw.request_responded === true
              if (!alreadyResponded) {
                setTimeout(() => get().respondToMatch(matchId, true), 1500)
              }
            }
          },
        )
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'matches',
          },
          (payload) => {
            const raw = payload.new as Record<string, unknown>
            if (raw.offer_user_id === userId || raw.request_user_id === userId) {
              // Update local match status
              set((s) => ({
                matches: s.matches.map((m) =>
                  m.id === raw.id
                    ? {
                        ...m,
                        status: raw.status as Match['status'],
                        offer_responded: raw.offer_responded as boolean,
                        request_responded: raw.request_responded as boolean,
                        offer_accepted: raw.offer_accepted as boolean | null,
                        request_accepted: raw.request_accepted as boolean | null,
                        conversation_id: raw.conversation_id as string | null,
                        updated_at: raw.updated_at as string,
                      }
                    : m,
                ),
              }))
              get().loadCounts()
            }
          },
        )
        .subscribe()

      set({ _channel: channel })
    },

    // ── Unsubscribe ──────────────────────────────────────────────
    unsubscribeFromRealtime: () => {
      const channel = get()._channel
      if (channel) {
        const supabase = createClient()
        supabase.removeChannel(channel)
        set({ _channel: null })
      }
    },

    // ── Reset ────────────────────────────────────────────────────
    reset: () => {
      get().unsubscribeFromRealtime()
      set(initialState)
    },
  }),
)
