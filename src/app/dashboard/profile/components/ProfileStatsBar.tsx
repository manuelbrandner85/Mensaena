'use client'

import Link from 'next/link'
import { Clock, Users, Target, FileText, type LucideIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface ProfileStatsData {
  hoursGiven: number
  hoursReceived: number
  groupsCount: number
  activeChallenges: number
  postsCount: number
}

interface Props {
  stats: ProfileStatsData
}

interface StatCard {
  icon: LucideIcon
  label: string
  value: string
  sub?: string
  href: string
  tint: string
  iconBg: string
  iconColor: string
}

export default function ProfileStatsBar({ stats }: Props) {
  const netto = Math.round((stats.hoursGiven - stats.hoursReceived) * 10) / 10
  const nettoFormatted = netto > 0 ? `+${netto}h` : `${netto}h`

  const cards: StatCard[] = [
    {
      icon: Clock,
      label: 'Zeitbank',
      value: nettoFormatted,
      sub: `${stats.hoursGiven}h gegeben · ${stats.hoursReceived}h erhalten`,
      href: '/dashboard/timebank',
      tint: 'from-mn-amber/8 to-primary-100/40 border-white/8',
      iconBg: 'bg-mn-amber/10',
      iconColor: 'text-mn-amber',
    },
    {
      icon: Users,
      label: 'Gruppen',
      value: String(stats.groupsCount),
      sub: stats.groupsCount === 1 ? 'Mitgliedschaft' : 'Mitgliedschaften',
      href: '/dashboard/groups',
      tint: 'from-mn-teal to-mn-teal-soft/40 border-white/5',
      iconBg: 'bg-mn-elevated',
      iconColor: 'text-mn-teal-soft',
    },
    {
      icon: Target,
      label: 'Challenges',
      value: String(stats.activeChallenges),
      sub: stats.activeChallenges === 1 ? 'aktiv' : 'aktiv',
      href: '/dashboard/challenges',
      tint: 'from-mn-amber/12 to-mn-amber-warm/8/40 border-amber-100',
      iconBg: 'bg-amber-100',
      iconColor: 'text-amber-700',
    },
    {
      icon: FileText,
      label: 'Beiträge',
      value: String(stats.postsCount),
      sub: stats.postsCount === 1 ? 'veröffentlicht' : 'veröffentlicht',
      href: '/dashboard/posts',
      tint: 'from-mn-amber to-mn-amber-warm/40 border-white/5',
      iconBg: 'bg-mn-elevated',
      iconColor: 'text-mn-amber',
    },
  ]

  const accents = ['#1EAAA6', '#3B82F6', '#F59E0B', '#8B5CF6']

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4">
      {cards.map((c, i) => {
        const Icon = c.icon
        const accent = accents[i]
        return (
          <Link
            key={c.label}
            href={c.href}
            className={cn(
              'spotlight hover-lift group relative overflow-hidden rounded-2xl border bg-gradient-to-br p-4 sm:p-5',
              'shadow-cinema-card hover:shadow-cinema-card transition-all',
              c.tint,
            )}
          >
            {/* Top accent line */}
            <div
              className="absolute top-0 left-0 right-0 h-[3px]"
              style={{ background: `linear-gradient(90deg, ${accent}, ${accent}33)` }}
            />
            <div className="flex items-start justify-between mb-3">
              <div
                className={cn(
                  'h-10 w-10 rounded-xl flex items-center justify-center shadow-cinema-card',
                  c.iconBg,
                )}
              >
                <Icon className={cn('w-5 h-5', c.iconColor)} />
              </div>
            </div>
            <div className="display-numeral text-2xl sm:text-3xl font-bold text-mn-ink leading-none tabular-nums">
              {c.value}
            </div>
            <div className="mt-1 text-xs font-medium text-mn-ink-soft">{c.label}</div>
            {c.sub && (
              <div className="mt-1.5 text-[11px] text-mn-mute leading-tight">
                {c.sub}
              </div>
            )}
          </Link>
        )
      })}
    </div>
  )
}
