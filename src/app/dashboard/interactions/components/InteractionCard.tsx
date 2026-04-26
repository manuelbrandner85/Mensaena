'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { User, Sparkles, Check, X, Play, Flag, Star } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import InteractionStatusBadge from './InteractionStatusBadge'
import { STATUS_CONFIG, type Interaction } from '../types'

interface Props {
  interaction: Interaction
  onAccept?: (id: string) => void
  onDecline?: (id: string) => void
  onStart?: (id: string) => void
  onComplete?: (id: string) => void
  onRate?: (id: string) => void
  isNewRequest?: boolean
}

export default function InteractionCard({
  interaction: i, onAccept, onDecline, onStart, onComplete, onRate, isNewRequest,
}: Props) {
  const router = useRouter()
  const cfg = STATUS_CONFIG[i.status] ?? STATUS_CONFIG.requested
  const borderColor = {
    requested: 'border-l-blue-500',
    accepted: 'border-l-primary-500',
    in_progress: 'border-l-amber-500',
    completed: 'border-l-green-500',
    cancelled_by_helper: 'border-l-red-400',
    cancelled_by_helped: 'border-l-red-400',
    disputed: 'border-l-orange-500',
    resolved: 'border-l-stone-400',
  }[i.status] ?? 'border-l-stone-300'

  const canRate = i.status === 'completed' && (
    (i.myRole === 'helper' && !i.helper_rated) ||
    (i.myRole === 'helped' && !i.helped_rated)
  )

  return (
    <div
      className={cn(
        'bg-white rounded-xl border-l-4 shadow-sm overflow-hidden cursor-pointer',
        'transition-all duration-200 hover:shadow-md hover:-translate-y-[1px]',
        borderColor,
        isNewRequest && 'ring-2 ring-amber-300',
      )}
      onClick={() => router.push(`/dashboard/interactions/${i.id}`)}
    >
      <div className="p-4">
        {/* Header */}
        <div className="flex items-center justify-between mb-2">
          <InteractionStatusBadge status={i.status} size="sm" />
          <span className="text-xs text-ink-400">{formatRelativeTime(i.updated_at)}</span>
        </div>

        {/* Title */}
        <h4 className="font-semibold text-ink-900 text-sm leading-snug mb-2 line-clamp-1">
          {i.post?.title ?? 'Direkte Hilfsanfrage'}
        </h4>

        {/* Partner */}
        <div className="flex items-center gap-2 mb-2">
          <div className="w-8 h-8 rounded-full bg-stone-100 flex items-center justify-center overflow-hidden flex-shrink-0">
            {i.partner.avatar_url
              ? <img src={i.partner.avatar_url} alt="" className="w-full h-full object-cover" />
              : <User className="w-4 h-4 text-ink-400" />
            }
          </div>
          <div className="min-w-0">
            <span className="text-sm font-medium text-ink-800 truncate block">{i.partner.name ?? 'Nutzer'}</span>
            <span className="text-xs text-ink-500">
              {i.myRole === 'helper' ? 'du hilfst' : 'hilft dir'}
            </span>
          </div>
          {i.match_id && (
            <span title="Aus Match entstanden" className="ml-auto">
              <Sparkles className="w-4 h-4 text-amber-500" />
            </span>
          )}
        </div>

        {/* Message preview */}
        {(i.message || i.response_message) && (
          <p className="text-xs text-ink-500 italic line-clamp-2 mb-3">
            {i.response_message ?? i.message}
          </p>
        )}

        {/* Footer: date + quick actions */}
        <div className="flex items-center justify-between pt-2 border-t border-stone-100">
          <span className="text-xs text-ink-400">{new Date(i.created_at).toLocaleDateString('de-DE')}</span>
          <div className="flex items-center gap-1" onClick={e => e.stopPropagation()}>
            {/* Requested & I'm receiver → accept/decline */}
            {isNewRequest && (
              <>
                <button onClick={() => onAccept?.(i.id)} title="Annehmen" className="p-1.5 rounded-lg bg-primary-50 text-primary-600 hover:bg-primary-100 transition-colors">
                  <Check className="w-4 h-4" />
                </button>
                <button onClick={() => onDecline?.(i.id)} title="Ablehnen" className="p-1.5 rounded-lg bg-red-50 text-red-500 hover:bg-red-100 transition-colors">
                  <X className="w-4 h-4" />
                </button>
              </>
            )}
            {/* Accepted & helper → start */}
            {i.status === 'accepted' && i.myRole === 'helper' && (
              <button onClick={() => onStart?.(i.id)} title="Starten" className="p-1.5 rounded-lg bg-amber-50 text-amber-600 hover:bg-amber-100 transition-colors">
                <Play className="w-4 h-4" />
              </button>
            )}
            {/* In progress → complete */}
            {i.status === 'in_progress' && (
              <button onClick={() => onComplete?.(i.id)} title="Abschliessen" className="p-1.5 rounded-lg bg-green-50 text-green-600 hover:bg-green-100 transition-colors">
                <Flag className="w-4 h-4" />
              </button>
            )}
            {/* Completed & can rate */}
            {canRate && (
              <button onClick={() => onRate?.(i.id)} title="Bewerten" className="p-1.5 rounded-lg bg-primary-50 text-primary-600 hover:bg-primary-100 transition-colors">
                <Star className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
