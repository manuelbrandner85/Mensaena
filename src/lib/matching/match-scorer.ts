/**
 * Mensaena Match Scorer
 * Client-side scoring logic that mirrors the DB scoring for display
 * and potential client-side recalculation.
 */

import type { ScoreBreakdown } from '@/app/dashboard/matching/types'

// ── Weight Configuration ────────────────────────────────────────────
export const SCORE_WEIGHTS = {
  category_match: 30,
  distance_score: 25,
  trust_score: 20,
  availability_score: 15,
  activity_score: 10,
} as const

export const MAX_TOTAL_SCORE = Object.values(SCORE_WEIGHTS).reduce((a, b) => a + b, 0) // 100

// ── Haversine Distance Calculator ───────────────────────────────────
const EARTH_RADIUS_KM = 6371.0

/**
 * Calculate the distance between two points on Earth using the Haversine formula.
 * Returns distance in kilometers, or null if coordinates are missing.
 */
export function haversineDistance(
  lat1: number | null | undefined,
  lon1: number | null | undefined,
  lat2: number | null | undefined,
  lon2: number | null | undefined,
): number | null {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null

  const toRad = (deg: number) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2

  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ── Individual Score Calculators ────────────────────────────────────

/**
 * Score based on category and type match.
 * Exact category match: 30pts, same type: 20pts, different: 5pts
 */
export function scoreCategoryMatch(
  postCategory: string | null,
  postType: string,
  candidateCategory: string | null,
  candidateType: string,
  preferredCategories?: string[],
): number {
  let score = 5 // base score for any match

  if (postCategory && candidateCategory && postCategory === candidateCategory) {
    score = 30
  } else if (postType === candidateType) {
    score = 20
  }

  // Bonus for preferred categories
  if (preferredCategories?.length && candidateCategory) {
    if (preferredCategories.includes(candidateCategory)) {
      score = Math.min(30, score + 5)
    }
  }

  return score
}

/**
 * Score based on distance between post/user locations.
 */
export function scoreDistance(distanceKm: number | null): number {
  if (distanceKm === null) return 12.5 // half credit when unknown

  if (distanceKm <= 2) return 25
  if (distanceKm <= 5) return 22
  if (distanceKm <= 10) return 18
  if (distanceKm <= 25) return 12
  if (distanceKm <= 50) return 6
  return 2
}

/**
 * Score based on user trust score (0-5 scale).
 */
export function scoreTrust(trustScore: number): number {
  return Math.min(20, trustScore * 4)
}

/**
 * Score based on availability overlap.
 */
export function scoreAvailability(
  postDays: string[] | null,
  candidateDays: string[] | null,
  postHasAvailability: boolean,
  candidateHasAvailability: boolean,
): number {
  if (!postHasAvailability || !candidateHasAvailability) return 7.5

  if (postDays && candidateDays) {
    const overlap = postDays.some((d) => candidateDays.includes(d))
    return overlap ? 15 : 5
  }

  return 10
}

/**
 * Score based on user activity recency.
 */
export function scoreActivity(lastActiveDate: string | null): number {
  if (!lastActiveDate) return 5

  const daysSince = Math.floor(
    (Date.now() - new Date(lastActiveDate).getTime()) / (1000 * 60 * 60 * 24),
  )

  if (daysSince <= 1) return 10
  if (daysSince <= 3) return 8
  if (daysSince <= 7) return 6
  if (daysSince <= 14) return 3
  return 1
}

// ── Full Score Calculation ──────────────────────────────────────────

export interface ScoreInput {
  postCategory: string | null
  postType: string
  candidateCategory: string | null
  candidateType: string
  distanceKm: number | null
  candidateTrustScore: number
  postAvailabilityDays: string[] | null
  candidateAvailabilityDays: string[] | null
  postHasAvailability: boolean
  candidateHasAvailability: boolean
  candidateLastActive: string | null
  preferredCategories?: string[]
}

/**
 * Calculate the full match score and breakdown.
 */
export function calculateMatchScore(input: ScoreInput): {
  total: number
  breakdown: ScoreBreakdown
} {
  const breakdown: ScoreBreakdown = {
    category_match: scoreCategoryMatch(
      input.postCategory,
      input.postType,
      input.candidateCategory,
      input.candidateType,
      input.preferredCategories,
    ),
    distance_score: scoreDistance(input.distanceKm),
    trust_score: scoreTrust(input.candidateTrustScore),
    availability_score: scoreAvailability(
      input.postAvailabilityDays,
      input.candidateAvailabilityDays,
      input.postHasAvailability,
      input.candidateHasAvailability,
    ),
    activity_score: scoreActivity(input.candidateLastActive),
  }

  const total = Object.values(breakdown).reduce((sum, val) => sum + val, 0)

  return { total: Math.round(total * 100) / 100, breakdown }
}

/**
 * Get a percentage score (0-100) from raw score.
 */
export function scoreToPercent(score: number): number {
  return Math.round((score / MAX_TOTAL_SCORE) * 100)
}

/**
 * Get a qualitative label for a match score.
 */
export function getScoreLabel(score: number): string {
  const pct = scoreToPercent(score)
  if (pct >= 80) return 'Hervorragend'
  if (pct >= 65) return 'Sehr gut'
  if (pct >= 50) return 'Gut'
  if (pct >= 35) return 'Befriedigend'
  return 'Ausreichend'
}

/**
 * Get a color for a score percentage.
 */
export function getScoreColor(score: number): string {
  const pct = scoreToPercent(score)
  if (pct >= 80) return '#10b981' // emerald
  if (pct >= 65) return '#22c55e' // green
  if (pct >= 50) return '#3b82f6' // blue
  if (pct >= 35) return '#f59e0b' // amber
  return '#ef4444' // red
}
