'use client'

import Link from 'next/link'
import { MapPin, Users, Clock, Eye, ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import CrisisStatusBadge from './CrisisStatusBadge'
import CrisisCategoryBadge from './CrisisCategoryBadge'
import CrisisUrgencyIndicator from './CrisisUrgencyIndicator'
import type { Crisis, URGENCY_CONFIG } from '../types'

interface Props {
  crisis: Crisis
}

export default function CrisisCard({ crisis }: Props) {
  const isActive = crisis.status === 'active' || crisis.status === 'in_progress'
  const isCritical = crisis.urgency === 'critical'

  return (
    <Link
      href={`/dashboard/crisis/${crisis.id}`}
      className={cn(
        'block rounded-2xl border p-4 transition-all hover:shadow-md group',
        isCritical && isActive
          ? 'border-red-300 bg-red-50/50 hover:border-red-400'
          : crisis.urgency === 'high' && isActive
          ? 'border-orange-200 bg-orange-50/30 hover:border-orange-300'
          : 'border-gray-200 bg-white hover:border-gray-300',
      )}
      aria-label={`Krise: ${crisis.title}`}
    >
      {/* Top row: badges */}
      <div className="flex flex-wrap items-center gap-2 mb-2">
        <CrisisUrgencyIndicator urgency={crisis.urgency} size="sm" />
        <CrisisCategoryBadge category={crisis.category} size="sm" />
        <CrisisStatusBadge status={crisis.status} size="sm" />
        {crisis.is_verified && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-emerald-50 border border-emerald-200 rounded-full text-xs text-emerald-700 font-semibold">
            Verifiziert
          </span>
        )}
      </div>

      {/* Title */}
      <h3 className="text-sm font-bold text-gray-900 group-hover:text-red-700 transition-colors line-clamp-2 mb-1">
        {crisis.title}
      </h3>

      {/* Description */}
      <p className="text-xs text-gray-600 line-clamp-2 mb-3">
        {crisis.description}
      </p>

      {/* Image preview */}
      {crisis.image_urls && crisis.image_urls.length > 0 && (
        <div className="mb-3 rounded-xl overflow-hidden h-32 bg-gray-100">
          <img
            src={crisis.image_urls[0]}
            alt="Krisenfoto"
            className="w-full h-full object-cover"
            loading="lazy"
          />
        </div>
      )}

      {/* Meta row */}
      <div className="flex flex-wrap items-center gap-3 text-xs text-gray-500">
        {crisis.location_text && (
          <span className="flex items-center gap-1">
            <MapPin className="w-3 h-3" />
            <span className="truncate max-w-[120px]">{crisis.location_text}</span>
          </span>
        )}
        <span className="flex items-center gap-1">
          <Users className="w-3 h-3" />
          {crisis.helper_count}/{crisis.needed_helpers} Helfer
        </span>
        {crisis.affected_count > 0 && (
          <span className="flex items-center gap-1">
            <Eye className="w-3 h-3" />
            ~{crisis.affected_count} Betroffene
          </span>
        )}
        <span className="flex items-center gap-1 ml-auto">
          <Clock className="w-3 h-3" />
          {formatRelativeTime(crisis.created_at)}
        </span>
        <ChevronRight className="w-4 h-4 text-gray-400 group-hover:text-red-500 transition-colors" />
      </div>
    </Link>
  )
}
