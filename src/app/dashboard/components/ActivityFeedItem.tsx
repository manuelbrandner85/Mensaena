'use client'

import { useRouter } from 'next/navigation'
import {
  FileText, Handshake, Star, UserPlus, Calendar, AlertTriangle,
} from 'lucide-react'
import { cn } from '@/lib/design-system'
import type { ActivityItem } from '../types'

const ICON_MAP: Record<string, React.ElementType> = {
  FileText,
  Handshake,
  Star,
  UserPlus,
  Calendar,
  AlertTriangle,
}

const COLOR_BG: Record<string, string> = {
  blue: 'bg-blue-100',
  teal: 'bg-primary-100',
  amber: 'bg-amber-100',
  purple: 'bg-purple-100',
  indigo: 'bg-indigo-100',
  red: 'bg-red-100',
}

const COLOR_TEXT: Record<string, string> = {
  blue: 'text-blue-600',
  teal: 'text-primary-600',
  amber: 'text-amber-600',
  purple: 'text-purple-600',
  indigo: 'text-indigo-600',
  red: 'text-red-600',
}

function formatTimeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'gerade'
  if (m < 60) return `vor ${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return `vor ${h}h`
  const d = Math.floor(h / 24)
  if (d < 7) return `vor ${d}d`
  const w = Math.floor(d / 7)
  if (w < 5) return `vor ${w}w`
  return new Date(iso).toLocaleDateString('de-DE')
}

export default function ActivityFeedItem({ activity }: { activity: ActivityItem }) {
  const router = useRouter()
  const Icon = ICON_MAP[activity.iconName] ?? FileText
  const bgColor = COLOR_BG[activity.color] ?? 'bg-gray-100'
  const textColor = COLOR_TEXT[activity.color] ?? 'text-gray-600'

  return (
    <button
      onClick={() => router.push(activity.linkTo)}
      className="w-full flex gap-3 p-4 hover:bg-gray-50 transition-colors cursor-pointer text-left"
    >
      {/* Icon */}
      <div className={cn('w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0', bgColor)}>
        <Icon className={cn('w-5 h-5', textColor)} />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 truncate">{activity.title}</p>
        <p className="text-xs text-gray-500 line-clamp-1">{activity.description}</p>
      </div>

      {/* Time */}
      <span className="text-xs text-gray-400 flex-shrink-0 mt-0.5">
        {formatTimeAgo(activity.timestamp)}
      </span>
    </button>
  )
}
