'use client'

import Link from 'next/link'
import {
  Clock, Users, Target, FileText, Sparkles, type LucideIcon,
} from 'lucide-react'
import { cn, formatRelativeTime } from '@/lib/utils'

export type ActivityKind = 'timebank' | 'group' | 'challenge' | 'post'

export interface ActivityItem {
  id: string
  kind: ActivityKind
  timestamp: string
  title: string
  description?: string
  href?: string
  badge?: string
}

interface Props {
  items: ActivityItem[]
}

const KIND_CONFIG: Record<
  ActivityKind,
  { icon: LucideIcon; iconBg: string; iconColor: string; label: string }
> = {
  timebank: {
    icon: Clock,
    iconBg: 'bg-mn-amber/10',
    iconColor: 'text-mn-amber',
    label: 'Zeitbank',
  },
  group: {
    icon: Users,
    iconBg: 'bg-mn-elevated',
    iconColor: 'text-mn-teal-soft',
    label: 'Gruppe',
  },
  challenge: {
    icon: Target,
    iconBg: 'bg-amber-100',
    iconColor: 'text-amber-700',
    label: 'Challenge',
  },
  post: {
    icon: FileText,
    iconBg: 'bg-mn-elevated',
    iconColor: 'text-mn-amber',
    label: 'Beitrag',
  },
}

export default function ProfileActivityFeed({ items }: Props) {
  return (
    <div className="relative bg-mn-elevated rounded-2xl shadow-cinema-card border border-white/5 p-5 sm:p-6 overflow-hidden">
      {/* Top accent */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
      />
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-lg font-bold text-mn-ink">Aktivität</h2>
        <span className="text-xs text-mn-mute">
          Letzte {items.length} Aktion{items.length === 1 ? '' : 'en'}
        </span>
      </div>

      {items.length === 0 ? (
        <div className="text-center py-12 bg-[#EEF9F9]/60 rounded-xl border border-dashed border-mn-amber/20">
          <Sparkles className="w-10 h-10 text-primary-400 mx-auto mb-3" />
          <p className="text-sm text-mn-ink-soft font-medium">
            Noch keine Aktivität
          </p>
          <p className="text-xs text-mn-mute mt-1">
            Trete einer Gruppe bei oder trage deine erste Hilfe ein.
          </p>
        </div>
      ) : (
        <ol className="relative">
          {/* Vertikale Timeline-Linie */}
          <div className="absolute left-5 top-2 bottom-2 w-px bg-gradient-to-b from-primary-200 via-stone-200 to-transparent" />

          {items.map((item) => {
            const cfg = KIND_CONFIG[item.kind]
            const Icon = cfg.icon
            const inner = (
              <div
                className={cn(
                  'group relative flex gap-4 py-3 px-2 rounded-xl',
                  'transition-colors hover:bg-[#EEF9F9]/60',
                )}
              >
                {/* Icon-Bubble */}
                <div
                  className={cn(
                    'relative z-10 flex-shrink-0 h-10 w-10 rounded-full ring-4 ring-white flex items-center justify-center',
                    cfg.iconBg,
                  )}
                >
                  <Icon className={cn('w-5 h-5', cfg.iconColor)} />
                </div>

                {/* Inhalt */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <p className="text-sm font-semibold text-mn-ink leading-snug">
                      {item.title}
                    </p>
                    <span className="flex-shrink-0 text-[11px] text-mn-mute whitespace-nowrap mt-0.5">
                      {formatRelativeTime(item.timestamp)}
                    </span>
                  </div>
                  {item.description && (
                    <p className="mt-0.5 text-xs text-mn-mute line-clamp-2 leading-relaxed">
                      {item.description}
                    </p>
                  )}
                  {item.badge && (
                    <span className="mt-1.5 inline-flex items-center text-xs font-medium px-2 py-0.5 rounded-full bg-mn-elevated text-mn-ink-soft">
                      {item.badge}
                    </span>
                  )}
                </div>
              </div>
            )

            return (
              <li key={`${item.kind}-${item.id}`}>
                {item.href ? (
                  <Link href={item.href} className="block">
                    {inner}
                  </Link>
                ) : (
                  inner
                )}
              </li>
            )
          })}
        </ol>
      )}
    </div>
  )
}
