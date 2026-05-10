'use client'

import { Trophy } from 'lucide-react'
import Card from '@/components/ui/Card'
import SectionHeader from '@/components/ui/SectionHeader'
import Avatar from '@/components/ui/Avatar'
import { cn } from '@/lib/utils'

export interface LeaderboardEntry {
  id: string
  display_name: string | null
  avatar_url: string | null
  count: number
  isCurrentUser: boolean
}

const RANK_STYLES = [
  { medal: '🥇', bg: 'bg-amber-50', border: 'border-amber-200', text: 'text-amber-700' },
  { medal: '🥈', bg: 'bg-mn-surface', border: 'border-white/5', text: 'text-mn-ink-soft' },
  { medal: '🥉', bg: 'bg-mn-surface', border: 'border-white/8', text: 'text-mn-amber-warm' },
]

export default function LeaderboardCard({ entries }: { entries: LeaderboardEntry[] }) {
  if (entries.length === 0) return null

  return (
    <Card variant="default">
      <SectionHeader
        title="Botschafter-Bestenliste"
        subtitle="Die aktivsten Nachbarschafts-Botschafter:innen dieser Woche"
        icon={<Trophy className="w-4 h-4" />}
        className="mb-4"
      />

      <ul className="space-y-2">
        {entries.map((entry, i) => {
          const style = RANK_STYLES[i] ?? { medal: `${i + 1}`, bg: 'bg-mn-surface', border: 'border-white/5', text: 'text-mn-mute' }
          return (
            <li
              key={entry.id}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-xl border',
                style.bg,
                style.border,
                entry.isCurrentUser && 'ring-2 ring-primary-300',
              )}
            >
              <span className="text-xl w-7 text-center flex-shrink-0">{style.medal}</span>
              <Avatar src={entry.avatar_url} name={entry.display_name} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-mn-ink truncate">
                  {entry.display_name ?? 'Nachbar:in'}
                  {entry.isCurrentUser && <span className="ml-1.5 text-xs text-mn-amber font-normal">(Du)</span>}
                </p>
              </div>
              <div className={cn('text-sm font-bold tabular-nums flex-shrink-0', style.text)}>
                {entry.count} {entry.count === 1 ? 'Einladung' : 'Einladungen'}
              </div>
            </li>
          )
        })}
      </ul>
    </Card>
  )
}
