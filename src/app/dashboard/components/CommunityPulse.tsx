'use client'

import { Users, FileText, Handshake, Zap } from 'lucide-react'
import { Card } from '@/components/ui'
import type { CommunityPulse as CommunityPulseType } from '../types'

interface CommunityPulseProps {
  pulse: CommunityPulseType
}

export default function CommunityPulse({ pulse }: CommunityPulseProps) {
  const allZero = pulse.activeUsersToday === 0 && pulse.newPostsToday === 0 && pulse.interactionsThisWeek === 0

  const rows = [
    { icon: Users, label: 'Aktiv heute', value: pulse.activeUsersToday },
    { icon: FileText, label: 'Neue Beiträge heute', value: pulse.newPostsToday },
    { icon: Handshake, label: 'Interaktionen diese Woche', value: pulse.interactionsThisWeek },
  ]

  return (
    <Card variant="flat" padding="md">
      <div className="flex items-center gap-2 text-sm font-semibold text-mn-ink">
        <Zap className="w-4 h-4 text-mn-amber" />
        Gemeinschafts-Puls
        <span className="relative flex h-2 w-2 ml-1">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary-400 opacity-75" />
          <span className="relative inline-flex rounded-full h-2 w-2 bg-mn-amber" />
        </span>
      </div>

      {allZero ? (
        <p className="text-xs text-mn-mute mt-3">
          Die Gemeinschaft wächst – mach den Anfang! 🌱
        </p>
      ) : (
        <div className="divide-y divide-stone-100 mt-2">
          {rows.map((row) => {
            const Icon = row.icon
            return (
              <div key={row.label} className="flex items-center justify-between py-2">
                <div className="flex items-center gap-2">
                  <Icon className="w-4 h-4 text-mn-mute" />
                  <span className="text-xs text-mn-ink-soft">{row.label}</span>
                </div>
                <span className="font-semibold text-sm text-mn-ink">{row.value}</span>
              </div>
            )
          })}
        </div>
      )}

      {pulse.newestNeighborName && (
        <div className="mt-2 pt-2 border-t border-white/5">
          <p className="text-xs text-mn-amber">
            Neuestes Mitglied: {pulse.newestNeighborName} 🎉
          </p>
        </div>
      )}
    </Card>
  )
}
