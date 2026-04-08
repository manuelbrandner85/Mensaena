/**
 * Trust-Score Level-System fuer Mensaena.
 * Levels 0-5 mit Schwellwerten, Farben und Icons.
 */

import type { TrustLevelInfo } from '@/types'

// ── Level-Definitionen ──────────────────────────────────────────────

const TRUST_LEVELS: TrustLevelInfo[] = [
  {
    level: 0,
    name: 'Neuling',
    color: 'text-gray-500',
    bgColor: 'bg-gray-100',
    borderColor: 'border-gray-200',
    icon: '\uD83C\uDF31',
    description: 'Noch keine Bewertungen erhalten',
    minRatings: 0,
    minAvg: 0,
  },
  {
    level: 1,
    name: 'Nachbar',
    color: 'text-blue-600',
    bgColor: 'bg-blue-50',
    borderColor: 'border-blue-200',
    icon: '\uD83C\uDF3F',
    description: 'Erste Schritte in der Community',
    minRatings: 2,
    minAvg: 2.0,
  },
  {
    level: 2,
    name: 'Helfer',
    color: 'text-green-600',
    bgColor: 'bg-green-50',
    borderColor: 'border-green-200',
    icon: '\u2B50',
    description: 'Aktiver Helfer in der Nachbarschaft',
    minRatings: 5,
    minAvg: 3.0,
  },
  {
    level: 3,
    name: 'Engagiert',
    color: 'text-amber-600',
    bgColor: 'bg-amber-50',
    borderColor: 'border-amber-200',
    icon: '\uD83C\uDF1F',
    description: 'Zuverlaessiger und engagierter Nachbar',
    minRatings: 10,
    minAvg: 3.5,
  },
  {
    level: 4,
    name: 'Mentor',
    color: 'text-purple-600',
    bgColor: 'bg-purple-50',
    borderColor: 'border-purple-200',
    icon: '\uD83D\uDCAB',
    description: 'Vertrauenswuerdiger Mentor der Community',
    minRatings: 15,
    minAvg: 4.0,
  },
  {
    level: 5,
    name: 'Legende',
    color: 'text-amber-700',
    bgColor: 'bg-amber-100',
    borderColor: 'border-amber-300',
    icon: '\uD83C\uDFC6',
    description: 'Aussergewoehnliches Engagement und Vertrauen',
    minRatings: 20,
    minAvg: 4.5,
  },
]

// ── Public API ──────────────────────────────────────────────────────

/**
 * Calculate trust level from score average and count.
 */
export function getTrustLevel(score: number, count: number): number {
  for (let i = TRUST_LEVELS.length - 1; i >= 0; i--) {
    const lvl = TRUST_LEVELS[i]
    if (count >= lvl.minRatings && score >= lvl.minAvg) {
      return lvl.level
    }
  }
  return 0
}

/**
 * Get full TrustLevelInfo for a given level.
 */
export function getTrustLevelInfo(level: number): TrustLevelInfo {
  return TRUST_LEVELS[Math.min(Math.max(level, 0), 5)]
}

/**
 * Get all trust level definitions.
 */
export function getAllTrustLevels(): TrustLevelInfo[] {
  return [...TRUST_LEVELS]
}

/**
 * Calculate progress toward the next trust level.
 * Returns { progress: 0-100, nextLevel, ratingProgress, avgProgress }.
 */
export function getTrustLevelProgress(
  currentLevel: number,
  score: number,
  count: number,
): {
  progress: number
  nextLevel: TrustLevelInfo | null
  ratingProgress: number
  avgProgress: number
} {
  if (currentLevel >= 5) {
    return { progress: 100, nextLevel: null, ratingProgress: 100, avgProgress: 100 }
  }

  const next = TRUST_LEVELS[currentLevel + 1]
  const current = TRUST_LEVELS[currentLevel]

  const ratingRange = next.minRatings - current.minRatings
  const ratingDone = Math.min(count - current.minRatings, ratingRange)
  const ratingProgress = ratingRange > 0 ? Math.round((ratingDone / ratingRange) * 100) : 100

  const avgRange = next.minAvg - current.minAvg
  const avgDone = Math.min(score - current.minAvg, avgRange)
  const avgProgress = avgRange > 0 ? Math.round((Math.max(0, avgDone) / avgRange) * 100) : 100

  const progress = Math.round((ratingProgress + avgProgress) / 2)

  return {
    progress: Math.min(100, Math.max(0, progress)),
    nextLevel: next,
    ratingProgress: Math.min(100, Math.max(0, ratingProgress)),
    avgProgress: Math.min(100, Math.max(0, avgProgress)),
  }
}

/**
 * Format trust score as display string.
 */
export function formatTrustScore(score: number): string {
  if (score <= 0) return '0.0'
  return score.toFixed(1)
}

/**
 * German labels for rating categories.
 */
export const RATING_CATEGORIES: { value: string; label: string; emoji: string }[] = [
  { value: 'zuverlaessig', label: 'Zuverlaessig', emoji: '\u2705' },
  { value: 'freundlich', label: 'Freundlich', emoji: '\uD83D\uDE0A' },
  { value: 'hilfsbereit', label: 'Hilfsbereit', emoji: '\uD83E\uDD1D' },
  { value: 'kommunikativ', label: 'Kommunikativ', emoji: '\uD83D\uDCAC' },
  { value: 'puenktlich', label: 'Puenktlich', emoji: '\u23F0' },
  { value: 'kompetent', label: 'Kompetent', emoji: '\uD83D\uDCA1' },
]
