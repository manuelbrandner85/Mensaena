'use client'

import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { TrustRating, TrustScoreData } from '@/types'

const PAGE_SIZE = 10

export function useRatings(userId: string | undefined) {
  const [ratings, setRatings] = useState<TrustRating[]>([])
  const [trustScore, setTrustScore] = useState<TrustScoreData | null>(null)
  const [loading, setLoading] = useState(true)
  const [hasMore, setHasMore] = useState(false)
  const [page, setPage] = useState(0)
  const [filter, setFilter] = useState<'all' | 'given' | 'received'>('received')

  const loadRatings = useCallback(async (pageNum: number = 0, append: boolean = false) => {
    if (!userId) return
    setLoading(true)
    const supabase = createClient()

    let query = supabase
      .from('trust_ratings')
      .select('*, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
      .order('created_at', { ascending: false })
      .range(pageNum * PAGE_SIZE, (pageNum + 1) * PAGE_SIZE - 1)

    if (filter === 'received') {
      query = query.eq('rated_id', userId)
    } else if (filter === 'given') {
      query = query.eq('rater_id', userId)
    } else {
      query = query.or(`rater_id.eq.${userId},rated_id.eq.${userId}`)
    }

    const { data, error } = await query

    if (!error && data) {
      const mapped: TrustRating[] = (data as Record<string, unknown>[]).map((r) => ({
        id: r.id as string,
        rater_id: r.rater_id as string,
        rated_id: r.rated_id as string,
        rating: (r.rating as number) ?? (r.score as number) ?? 0,
        score: r.score as number | undefined,
        comment: r.comment as string | null,
        interaction_id: r.interaction_id as string | null,
        categories: (r.categories as TrustRating['categories']) ?? [],
        helpful: r.helpful as boolean | null,
        would_recommend: r.would_recommend as boolean | null,
        response: r.response as string | null,
        response_at: r.response_at as string | null,
        edited_at: r.edited_at as string | null,
        reported: (r.reported as boolean) ?? false,
        created_at: r.created_at as string,
        rater_name: (r.profiles as Record<string, unknown>)?.name as string | null ?? null,
        rater_avatar: (r.profiles as Record<string, unknown>)?.avatar_url as string | null ?? null,
      }))

      if (append) {
        setRatings(prev => [...prev, ...mapped])
      } else {
        setRatings(mapped)
      }
      setHasMore(mapped.length === PAGE_SIZE)
    }

    setLoading(false)
  }, [userId, filter])

  const loadTrustScore = useCallback(async () => {
    if (!userId) return
    const supabase = createClient()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { data, error } = await (supabase.rpc as any)('calculate_trust_score', {
      p_user_id: userId,
    })

    if (!error && data) {
      setTrustScore(data as unknown as TrustScoreData)
    }
  }, [userId])

  useEffect(() => {
    setPage(0)
    loadRatings(0, false)
    loadTrustScore()
  }, [loadRatings, loadTrustScore])

  const loadMore = useCallback(() => {
    const nextPage = page + 1
    setPage(nextPage)
    loadRatings(nextPage, true)
  }, [page, loadRatings])

  const changeFilter = useCallback((f: 'all' | 'given' | 'received') => {
    setFilter(f)
    setPage(0)
  }, [])

  return {
    ratings,
    trustScore,
    loading,
    hasMore,
    filter,
    setFilter: changeFilter,
    loadMore,
    refresh: () => { loadRatings(0, false); loadTrustScore() },
  }
}
