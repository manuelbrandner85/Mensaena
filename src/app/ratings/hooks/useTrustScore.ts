'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { getTrustLevel, getTrustLevelInfo } from '@/lib/trust-score'
import type { TrustLevelInfo } from '@/types'

interface UseTrustScoreResult {
  score: number
  count: number
  level: number
  levelInfo: TrustLevelInfo
  loading: boolean
}

export function useTrustScore(userId: string | undefined): UseTrustScoreResult {
  const [score, setScore] = useState(0)
  const [count, setCount] = useState(0)
  const [level, setLevel] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!userId) { setLoading(false); return }

    const supabase = createClient()

    supabase
      .from('profiles')
      .select('trust_score, trust_score_count, trust_level')
      .eq('id', userId)
      .single()
      .then(({ data, error }) => {
        if (!error && data) {
          const ts = (data as Record<string, unknown>).trust_score as number ?? 0
          const tc = (data as Record<string, unknown>).trust_score_count as number ?? 0
          const tl = (data as Record<string, unknown>).trust_level as number ?? 0

          // Convert trust_score (0-100) back to 1-5 scale for level calc
          const avgOnFiveScale = tc > 0 ? ts / 20 : 0
          const calculatedLevel = tl || getTrustLevel(avgOnFiveScale, tc)

          setScore(avgOnFiveScale)
          setCount(tc)
          setLevel(calculatedLevel)
        }
        setLoading(false)
      })
  }, [userId])

  return {
    score,
    count,
    level,
    levelInfo: getTrustLevelInfo(level),
    loading,
  }
}
