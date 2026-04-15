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
    iconBg: 'bg-primary-100',
    iconColor: 'text-primary-700',
    label: 'Zeitbank',
  },
  group: {
    icon: Users,
    iconBg: 'bg-blue-100',
    iconColor: 'text-blue-700',
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
    iconBg: 'bg-purple-100',
    iconColor: 'text-purple-700',
    label: 'Beitrag',
  },
}

export default function ProfileActivityFeed({ items }: Props) {
  return (
    <div className="relative bg-white rounded-2xl shadow-soft border border-gray-100 p-5 sm:p-6 overflow-hidden">
      {/* Top accent */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
      />
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-lg font-bold text-gray-900">Aktivität</h2>
        <span className="text-xs text-gray-400">
          Letzte {items.length} Aktion{items.length === 1 ? '' : 'en'}
        </span>
      </div>

      {items.length === 0 ? (
        <div className="text-center py-12 bg-[#EEF9F9]/60 rounded-xl border border-dashed border-primary-200">
          <Sparkles className="w-10 h-10 text-primary-400 mx-auto mb-3" />
          <p className="text-sm text-gray-600 font-medium">
            Noch keine Aktivität
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Trete einer Gruppe bei oder trage deine erste Hilfe ein.
          </p>
        </div>
      ) : (
        <ol className="relative">
          {/* Vertikale Timeline-Linie */}
          <div className="absolute left-5 top-2 bottom-2 w-px bg-gradient-to-b from-primary-200 via-gray-200 to-transparent" />

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
                    <p className="text-sm font-semibold text-gray-900 leading-snug">
                      {item.title}
                    </p>
                    <span className="flex-shrink-0 text-[11px] text-gray-400 whitespace-nowrap mt-0.5">
                      {formatRelativeTime(item.timestamp)}
                    </span>
                  </div>
                  {item.description && (
                    <p className="mt-0.5 text-xs text-gray-500 line-clamp-2 leading-relaxed">
                      {item.description}
                    </p>
                  )}
                  {item.badge && (
                    <span className="mt-1.5 inline-flex items-center text-[10px] font-medium px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">
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
