export interface TierInfo {
  tier: number
  name: string
  emoji: string | null
  pillClass: string
  description: string
}

export const DONOR_TIERS: TierInfo[] = [
  { tier: 0, name: 'Nutzer',       emoji: null,  pillClass: '',                                    description: '' },
  { tier: 1, name: 'Unterstützer', emoji: '🤍',  pillClass: 'bg-gray-100 text-gray-500',           description: '1 Spende oder ab 5 €' },
  { tier: 2, name: 'Förderer',     emoji: '💛',  pillClass: 'bg-yellow-50 text-yellow-700',        description: '3 Spenden oder ab 25 €' },
  { tier: 3, name: 'Partner',      emoji: '🧡',  pillClass: 'bg-orange-50 text-orange-700',        description: '5 Spenden oder ab 50 €' },
  { tier: 4, name: 'Botschafter',  emoji: '❤️',  pillClass: 'bg-red-50 text-red-600',              description: '10 Spenden oder ab 100 €' },
]

export function getTierInfo(tier: number | null | undefined): TierInfo {
  const t = Math.max(0, Math.min(tier ?? 0, 4))
  return DONOR_TIERS[t]
}

export function calculateDonorTier(count: number, total: number): number {
  if (count >= 10 || total >= 100) return 4
  if (count >= 5  || total >= 50)  return 3
  if (count >= 3  || total >= 25)  return 2
  if (count >= 1  || total >= 5)   return 1
  return 0
}

export const canCreatePoll      = (tier: number, isAdmin: boolean) => isAdmin || tier >= 2
export const canCreateChannel   = (tier: number, isAdmin: boolean) => isAdmin || tier >= 2
export const canScheduleEvent   = (tier: number, isAdmin: boolean) => isAdmin || tier >= 3
export const canPostAnnouncement= (tier: number, isAdmin: boolean) => isAdmin || tier >= 3
