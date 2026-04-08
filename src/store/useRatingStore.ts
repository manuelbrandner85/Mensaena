/**
 * Zustand store for ratings and trust score management.
 */

import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import type { PendingRating, TrustRating, RatingCategory } from '@/types'

interface RatingSubmitData {
  ratedId: string
  rating: number
  comment?: string
  interactionId?: string
  categories?: RatingCategory[]
  helpful?: boolean
  wouldRecommend?: boolean
}

interface RatingStoreState {
  pendingRatings: PendingRating[]
  isRatingModalOpen: boolean
  currentRating: {
    partnerId: string
    partnerName: string | null
    partnerAvatar: string | null
    interactionId: string | null
    postTitle: string | null
  } | null
  loading: boolean
}

interface RatingStoreActions {
  loadPendingRatings: (userId: string) => Promise<void>
  openRatingModal: (data: {
    partnerId: string
    partnerName: string | null
    partnerAvatar: string | null
    interactionId: string | null
    postTitle: string | null
  }) => void
  closeRatingModal: () => void
  submitRating: (raterId: string, data: RatingSubmitData) => Promise<boolean>
  submitResponse: (ratingId: string, text: string) => Promise<boolean>
  reportRating: (ratingId: string) => Promise<boolean>
}

export const useRatingStore = create<RatingStoreState & RatingStoreActions>((set, get) => ({
  pendingRatings: [],
  isRatingModalOpen: false,
  currentRating: null,
  loading: false,

  loadPendingRatings: async (userId: string) => {
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { data, error } = await (supabase.rpc as any)('get_pending_ratings', {
      p_user_id: userId,
    })

    if (!error && data) {
      const ratings = Array.isArray(data) ? data : (data as PendingRating[])
      set({ pendingRatings: ratings as PendingRating[] })
    }
  },

  openRatingModal: (data) => {
    set({
      isRatingModalOpen: true,
      currentRating: data,
    })
  },

  closeRatingModal: () => {
    set({
      isRatingModalOpen: false,
      currentRating: null,
    })
  },

  submitRating: async (raterId: string, data: RatingSubmitData) => {
    set({ loading: true })
    const supabase = createClient()

    // Check abuse: prevent self-rating
    if (raterId === data.ratedId) {
      set({ loading: false })
      return false
    }

    // Check rate limit: max 5 ratings per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count: recentCount } = await supabase
      .from('trust_ratings')
      .select('*', { count: 'exact', head: true })
      .eq('rater_id', raterId)
      .gte('created_at', oneHourAgo)

    if ((recentCount ?? 0) >= 5) {
      set({ loading: false })
      return false
    }

    // Check unique per interaction
    if (data.interactionId) {
      const { data: existing } = await supabase
        .from('trust_ratings')
        .select('id')
        .eq('rater_id', raterId)
        .eq('rated_id', data.ratedId)
        .eq('interaction_id', data.interactionId)
        .maybeSingle()

      if (existing) {
        set({ loading: false })
        return false
      }
    } else {
      // Limit to one rating per 30 days per user-pair if no interaction
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
      const { data: recentPair } = await supabase
        .from('trust_ratings')
        .select('id')
        .eq('rater_id', raterId)
        .eq('rated_id', data.ratedId)
        .is('interaction_id', null)
        .gte('created_at', thirtyDaysAgo)
        .maybeSingle()

      if (recentPair) {
        set({ loading: false })
        return false
      }
    }

    const insertData: Record<string, unknown> = {
      rater_id: raterId,
      rated_id: data.ratedId,
      rating: data.rating,
      score: data.rating,
      comment: data.comment || null,
      interaction_id: data.interactionId || null,
      categories: data.categories || [],
      helpful: data.helpful ?? null,
      would_recommend: data.wouldRecommend ?? null,
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('trust_ratings') as any)
      .insert(insertData)

    if (error) {
      console.warn('[ratings] submit failed:', error.message)
      set({ loading: false })
      return false
    }

    // Remove from pending list
    if (data.interactionId) {
      set(state => ({
        pendingRatings: state.pendingRatings.filter(
          pr => pr.interaction_id !== data.interactionId,
        ),
      }))
    }

    set({ loading: false, isRatingModalOpen: false, currentRating: null })
    return true
  },

  submitResponse: async (ratingId: string, text: string) => {
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('trust_ratings') as any)
      .update({ response: text, response_at: new Date().toISOString() })
      .eq('id', ratingId)

    return !error
  },

  reportRating: async (ratingId: string) => {
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('trust_ratings') as any)
      .update({ reported: true })
      .eq('id', ratingId)

    return !error
  },
}))
