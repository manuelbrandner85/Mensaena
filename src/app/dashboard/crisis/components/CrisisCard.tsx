'use client'

import { useState } from 'react'
import Link from 'next/link'
import { MapPin, Users, Clock, Eye, ChevronRight, HandHeart, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import CrisisStatusBadge from './CrisisStatusBadge'
import CrisisCategoryBadge from './CrisisCategoryBadge'
import CrisisUrgencyIndicator from './CrisisUrgencyIndicator'
import type { Crisis } from '../types'

interface Props {
  crisis: Crisis
  userId?: string
}

const URGENCY_BG: Record<string, string> = {
  critical: 'border-red-300 bg-red-50 border-l-[5px] border-l-red-600',
  high:     'border-orange-200 bg-orange-50/60 border-l-[5px] border-l-orange-500',
  medium:   'border-amber-200 bg-amber-50/30 border-l-[5px] border-l-amber-400',
  low:      'border-stone-200 bg-white border-l-[5px] border-l-stone-300',
}

const URGENCY_ACCENT: Record<string, string> = {
  critical: '#C62828',
  high:     '#F97316',
  medium:   '#F59E0B',
  low:      '#9CA3AF',
}

export default function CrisisCard({ crisis, userId }: Props) {
  const [helping, setHelping] = useState(false)
  const [helped, setHelped] = useState(false)
  const [localCount, setLocalCount] = useState(crisis.helper_count)

  const isActive = crisis.status === 'active' || crisis.status === 'in_progress'
  const needsHelpers = localCount < crisis.needed_helpers

  const handleHelp = async (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (!userId) { toast.error('Bitte zuerst einloggen'); return }
    if (helped) { toast('Du hast bereits geholfen!', { icon: '✅' }); return }
    setHelping(true)
    try {
      const supabase = createClient()
      await supabase.from('crisis_helpers').insert({
        crisis_id: crisis.id,
        user_id: userId,
        message: '',
        skills: [],
      })
      setLocalCount(c => c + 1)
      setHelped(true)
      toast.success('Danke! Du wurdest als Helfer eingetragen.')
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : ''
      if (msg.includes('already') || msg.includes('23505')) {
        toast('Du hilfst bereits bei dieser Krise.', { icon: 'ℹ️' })
        setHelped(true)
      } else {
        toast.error('Fehler beim Eintragen')
      }
    } finally {
      setHelping(false)
    }
  }

  const accent = isActive ? (URGENCY_ACCENT[crisis.urgency] ?? URGENCY_ACCENT.low) : '#9CA3AF'

  return (
    <Link
      href={`/dashboard/crisis/${crisis.id}`}
      className={cn(
        'spotlight hover-lift relative block rounded-2xl border p-4 pt-5 shadow-soft hover:shadow-card transition-all duration-300 group overflow-hidden',
        isActive ? (URGENCY_BG[crisis.urgency] ?? URGENCY_BG.low) : 'border-stone-200 bg-white border-l-[5px] border-l-stone-200',
      )}
      aria-label={`Krise: ${crisis.title}`}
    >
      {/* Top accent line */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: `linear-gradient(90deg, ${accent}, ${accent}33)` }}
      />
      {/* Critical pulse ring */}
      {crisis.urgency === 'critical' && isActive && (
        <div
          className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-500"
          style={{ background: 'radial-gradient(circle at 50% 0%, rgba(198,40,40,0.08), transparent 60%)' }}
        />
      )}

      {/* Top row: badges */}
      <div className="flex flex-wrap items-center gap-2 mb-2">
        <CrisisUrgencyIndicator urgency={crisis.urgency} size="sm" />
        <CrisisCategoryBadge category={crisis.category} size="sm" />
        <CrisisStatusBadge status={crisis.status} size="sm" />
        {crisis.is_verified && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-primary-50 border border-primary-200 rounded-full text-xs text-primary-700 font-semibold">
            Verifiziert
          </span>
        )}
      </div>

      {/* Title */}
      <h3 className="text-sm font-bold text-ink-900 group-hover:text-red-700 transition-colors line-clamp-2 mb-1">
        {crisis.title}
      </h3>

      {/* Description */}
      <p className="text-xs text-ink-600 line-clamp-2 mb-3">
        {crisis.description}
      </p>

      {/* Image preview */}
      {crisis.image_urls && crisis.image_urls.length > 0 && (
        <div className="mb-3 rounded-xl overflow-hidden h-32 bg-stone-100">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={crisis.image_urls[0]}
            alt="Krisenfoto"
            className="w-full h-full object-cover"
            loading="lazy"
            onError={(e) => { e.currentTarget.style.display = 'none' }}
          />
        </div>
      )}

      {/* Meta + Ich helfe row */}
      <div className="flex flex-wrap items-center gap-3 text-xs text-ink-500">
        {crisis.location_text && (
          <span className="flex items-center gap-1">
            <MapPin className="w-3 h-3" />
            <span className="truncate max-w-[120px]">{crisis.location_text}</span>
          </span>
        )}
        <span className="flex items-center gap-1">
          <Users className="w-3 h-3" />
          {localCount}/{crisis.needed_helpers} Helfer
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

        {/* Ich helfe button */}
        {isActive && needsHelpers && (
          <button
            onClick={handleHelp}
            disabled={helping || helped}
            className={cn(
              'shine flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-semibold transition-all',
              helped
                ? 'bg-primary-100 text-primary-700 cursor-default shadow-soft'
                : 'bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white shadow-glow-teal active:scale-95',
            )}
          >
            {helping
              ? <Loader2 className="w-3 h-3 animate-spin" />
              : <HandHeart className="w-3 h-3" />}
            {helped ? 'Dabei!' : 'Ich helfe'}
          </button>
        )}

        {!isActive && <ChevronRight className="w-4 h-4 text-ink-400 group-hover:text-red-500 transition-colors" />}
        {isActive && !needsHelpers && <ChevronRight className="w-4 h-4 text-ink-400 group-hover:text-red-500 transition-colors" />}
      </div>
    </Link>
  )
}
