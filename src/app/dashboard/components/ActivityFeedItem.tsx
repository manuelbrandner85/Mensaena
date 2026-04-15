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

// CSS accent colors
const COLOR_ACCENT: Record<string, string> = {
  blue:   '#3B82F6',
  teal:   '#1EAAA6',
  amber:  '#F59E0B',
  purple: '#8B5CF6',
  indigo: '#6366F1',
  red:    '#EF4444',
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

export default function ActivityFeedItem({
  activity,
}: { activity: ActivityItem }) {
  const router = useRouter()
  const Icon = ICON_MAP[activity.iconName] ?? FileText
  const accent = COLOR_ACCENT[activity.color] ?? '#1EAAA6'

  return (
    <button
      onClick={() => router.push(activity.linkTo)}
      className="w-full flex gap-0 text-left group hover:bg-primary-50/40 transition-colors duration-200"
    >
      {/* Timeline node column */}
      <div className="flex flex-col items-center w-10 flex-shrink-0 pt-4 pb-0">
        {/* Node dot */}
        <div
          className="w-2 h-2 rounded-full flex-shrink-0 ring-2 ring-white shadow-sm group-hover:scale-125 transition-transform duration-200"
          style={{ backgroundColor: accent }}
        />
        {/* Connector line — drawn by .timeline-track::before */}
      </div>

      {/* Icon badge */}
      <div className="flex-shrink-0 pt-3.5 pr-3">
        <div
          className="w-8 h-8 rounded-xl flex items-center justify-center"
          style={{ background: `${accent}18` }}
        >
          <Icon className="w-3.5 h-3.5" style={{ color: accent }} />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 py-3.5 pr-4 border-b border-gray-50 group-last:border-0">
        <div className="flex items-start justify-between gap-2">
          <p className="text-sm font-medium text-gray-900 leading-snug line-clamp-1">{activity.title}</p>
          <span className="text-xs text-gray-400 flex-shrink-0 mt-0.5 tabular-nums">
            {formatTimeAgo(activity.timestamp)}
          </span>
        </div>
        {activity.description && (
          <p className="text-xs text-gray-500 mt-0.5 line-clamp-1 leading-relaxed">{activity.description}</p>
        )}
      </div>
    </button>
  )
}
