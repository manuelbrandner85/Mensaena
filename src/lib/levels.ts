// ============================================================
// Punkte & Level System – Mensaena
// ============================================================

export interface UserLevel {
  level: number
  name: string
  emoji: string
  minPoints: number
  maxPoints: number
  color: string
  bgColor: string
  borderColor: string
}

export const LEVELS: UserLevel[] = [
  { level: 1, name: 'Neuling',    emoji: '🌱', minPoints: 0,    maxPoints: 99,   color: 'text-gray-600',   bgColor: 'bg-gray-100',   borderColor: 'border-gray-300' },
  { level: 2, name: 'Nachbar',    emoji: '🏘️', minPoints: 100,  maxPoints: 299,  color: 'text-primary-700', bgColor: 'bg-primary-50',  borderColor: 'border-primary-300' },
  { level: 3, name: 'Helfer',     emoji: '🤝', minPoints: 300,  maxPoints: 599,  color: 'text-blue-700',   bgColor: 'bg-blue-50',    borderColor: 'border-blue-300' },
  { level: 4, name: 'Held',       emoji: '🦸', minPoints: 600,  maxPoints: 999,  color: 'text-purple-700', bgColor: 'bg-purple-50',   borderColor: 'border-purple-300' },
  { level: 5, name: 'Legende',    emoji: '👑', minPoints: 1000, maxPoints: Infinity, color: 'text-amber-700', bgColor: 'bg-amber-50', borderColor: 'border-amber-400' },
]

export function getUserLevel(points: number): UserLevel {
  return LEVELS.findLast(l => points >= l.minPoints) ?? LEVELS[0]
}

export function getNextLevel(points: number): UserLevel | null {
  const current = getUserLevel(points)
  return LEVELS.find(l => l.level === current.level + 1) ?? null
}

export function getLevelProgress(points: number): number {
  const current = getUserLevel(points)
  const next = getNextLevel(points)
  if (!next) return 100
  const range = next.minPoints - current.minPoints
  const progress = points - current.minPoints
  return Math.min(Math.round((progress / range) * 100), 100)
}

export function getPointsToNextLevel(points: number): number {
  const next = getNextLevel(points)
  if (!next) return 0
  return next.minPoints - points
}
