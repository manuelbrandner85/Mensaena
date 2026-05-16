'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import {
  MapPin, Clock, Check, X, MessageCircle,
  ChevronDown, ChevronUp, Loader2, Eye,
} from 'lucide-react'
import { cn } from '@/lib/design-system'
import { getTypeConfig } from '@/lib/post-types'
import { formatRelativeTime } from '@/lib/notifications'
import type { Match, MatchStatus } from '../types'
import { MATCH_STATUS_LABELS, MATCH_STATUS_COLORS } from '../types'
import MatchScore from './MatchScore'

interface MatchSuggestionCardProps {
  match: Match
  userId: string
  respondingId: string | null
  onAccept: (matchId: string) => void
  onDecline: (matchId: string) => void
  onOpenChat: (conversationId: string) => void
  onOpenDetail: (match: Match) => void
  onMarkAsSeen: (matchId: string) => void
}

export default function MatchSuggestionCard({
  match,
  userId,
  respondingId,
  onAccept,
  onDecline,
  onOpenChat,
  onOpenDetail,
  onMarkAsSeen,
}: MatchSuggestionCardProps) {
  const [expanded, setExpanded] = useState(false)
  const isOffer = userId === match.offer_user_id
  const myPost = isOffer ? match.offer_post : match.request_post
  const partnerPost = isOffer ? match.request_post : match.offer_post
  const partner = isOffer ? match.request_user : match.offer_user
  const isSeen = isOffer ? match.seen_by_offer : match.seen_by_request
  const isResponding = respondingId === match.id
  const hasResponded = isOffer ? match.offer_responded : match.request_responded

  const partnerTypeConfig = getTypeConfig(partnerPost.type)
  const statusColors = MATCH_STATUS_COLORS[match.status]

  // Mark as seen when card becomes visible
  useEffect(() => {
    if (!isSeen && match.status === 'suggested') {
      const timer = setTimeout(() => onMarkAsSeen(match.id), 1000)
      return () => clearTimeout(timer)
    }
  }, [isSeen, match.id, match.status, onMarkAsSeen])

  const handleAccept = useCallback(() => onAccept(match.id), [match.id, onAccept])
  const handleDecline = useCallback(() => onDecline(match.id), [match.id, onDecline])

  // ── Swipe gesture (mobile) ────────────────────────────────────────
  const isActionable = match.status === 'suggested' || (match.status === 'pending' && !hasResponded)
  const SWIPE_THRESHOLD = 100
  const touchStartX = useRef<number | null>(null)
  const touchStartY = useRef<number | null>(null)
  const [dragX, setDragX] = useState(0)
  const [dragging, setDragging] = useState(false)
  const [gestureLocked, setGestureLocked] = useState<'h' | 'v' | null>(null)

  const onTouchStart = (e: React.TouchEvent) => {
    if (!isActionable || isResponding) return
    touchStartX.current = e.touches[0].clientX
    touchStartY.current = e.touches[0].clientY
    setDragging(true)
    setGestureLocked(null)
  }
  const onTouchMove = (e: React.TouchEvent) => {
    if (touchStartX.current == null || touchStartY.current == null) return
    const dx = e.touches[0].clientX - touchStartX.current
    const dy = e.touches[0].clientY - touchStartY.current
    if (gestureLocked == null) {
      if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
        setGestureLocked(Math.abs(dx) > Math.abs(dy) ? 'h' : 'v')
      }
    }
    if (gestureLocked === 'h') {
      setDragX(dx)
    }
  }
  const onTouchEnd = () => {
    if (gestureLocked === 'h') {
      if (dragX > SWIPE_THRESHOLD) {
        handleAccept()
      } else if (dragX < -SWIPE_THRESHOLD) {
        handleDecline()
      }
    }
    touchStartX.current = null
    touchStartY.current = null
    setDragX(0)
    setDragging(false)
    setGestureLocked(null)
  }

  const swipeProgress = Math.min(1, Math.abs(dragX) / SWIPE_THRESHOLD)
  const swipeDirection: 'accept' | 'decline' | null =
    dragX > 20 ? 'accept' : dragX < -20 ? 'decline' : null

  return (
    <div
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
      onTouchCancel={onTouchEnd}
      style={{
        transform: dragging ? `translateX(${dragX}px) rotate(${dragX * 0.03}deg)` : undefined,
        transition: dragging ? 'none' : 'transform 0.25s ease-out',
      }}
      className={cn(
        'bg-mn-elevated rounded-xl border transition-all duration-200 overflow-hidden relative',
        !isSeen && match.status === 'suggested'
          ? 'border-white/5 ring-1 ring-indigo-100 shadow-sm'
          : 'border-white/5 hover:border-white/5',
      )}
    >
      {/* Swipe overlay feedback */}
      {isActionable && swipeDirection && (
        <div
          className={cn(
            'pointer-events-none absolute inset-0 z-10 flex items-center px-6',
            swipeDirection === 'accept' ? 'justify-start' : 'justify-end',
            swipeDirection === 'accept' ? 'bg-mn-bronze/10' : 'bg-red-500/10',
          )}
          style={{ opacity: swipeProgress }}
        >
          <div
            className={cn(
              'rounded-full p-3 text-white shadow-lg',
              swipeDirection === 'accept' ? 'bg-mn-bronze' : 'bg-red-500',
            )}
            style={{ transform: `scale(${0.7 + swipeProgress * 0.5})` }}
          >
            {swipeDirection === 'accept' ? <Check className="w-6 h-6" /> : <X className="w-6 h-6" />}
          </div>
        </div>
      )}
      {/* Header row */}
      <div className="p-4 flex items-start gap-3">
        {/* Score ring */}
        <div className="flex-shrink-0">
          <MatchScore score={match.match_score} size="md" />
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          {/* Partner name + status badge */}
          <div className="flex items-center gap-2 flex-wrap mb-1">
            <button
              onClick={() => onOpenDetail(match)}
              className="font-semibold text-mn-ink text-sm hover:text-mn-teal-soft transition-colors truncate"
            >
              {partner.name || 'Unbekannt'}
            </button>

            <span
              className={cn(
                'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border',
                statusColors.text,
                statusColors.bg,
                statusColors.border,
              )}
            >
              {MATCH_STATUS_LABELS[match.status]}
            </span>

            {!isSeen && match.status === 'suggested' && (
              <span className="flex items-center gap-0.5 text-xs text-mn-teal-soft font-medium">
                <Eye className="w-3 h-3" /> Neu
              </span>
            )}
          </div>

          {/* Partner post title */}
          <p className="text-sm text-mn-ink-soft font-medium truncate mb-1">
            {partnerTypeConfig.emoji} {partnerPost.title}
          </p>

          {/* Meta info */}
          <div className="flex items-center gap-3 text-xs text-mn-mute">
            {match.distance_km != null && (
              <span className="flex items-center gap-0.5">
                <MapPin className="w-3 h-3" />
                {match.distance_km < 1
                  ? `${Math.round(match.distance_km * 1000)}m`
                  : `${Math.round(match.distance_km)}km`}
              </span>
            )}

            <span className="flex items-center gap-0.5">
              <Clock className="w-3 h-3" />
              {formatRelativeTime(match.created_at)}
            </span>

            {partner.trust_score > 0 && (
              <span className="flex items-center gap-0.5">
                Vertrauen: {partner.trust_score.toFixed(1)}
              </span>
            )}
          </div>
        </div>

        {/* Expand button */}
        <button
          onClick={() => setExpanded(!expanded)}
          className="p-1 text-mn-mute hover:text-mn-ink-soft transition-colors flex-shrink-0"
          aria-label={expanded ? 'Weniger anzeigen' : 'Mehr anzeigen'}
        >
          {expanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
        </button>
      </div>

      {/* Expanded details */}
      {expanded && (
        <div className="px-4 pb-3 space-y-3 border-t border-white/5 pt-3">
          {/* My post */}
          <div className="bg-mn-surface rounded-lg p-3">
            <p className="text-xs font-medium text-mn-mute uppercase tracking-wide mb-1">
              Dein Beitrag
            </p>
            <p className="text-sm font-medium text-mn-ink">
              {getTypeConfig(myPost.type).emoji} {myPost.title}
            </p>
            {myPost.location && (
              <p className="text-xs text-mn-mute mt-0.5 flex items-center gap-1">
                <MapPin className="w-3 h-3" /> {myPost.location}
              </p>
            )}
          </div>

          {/* Partner post */}
          <div className="bg-mn-surface/50 rounded-lg p-3">
            <p className="text-xs font-medium text-mn-teal-soft uppercase tracking-wide mb-1">
              Vorgeschlagener Beitrag
            </p>
            <p className="text-sm font-medium text-mn-ink">
              {partnerTypeConfig.emoji} {partnerPost.title}
            </p>
            {partnerPost.description && (
              <p className="text-xs text-mn-ink-soft mt-1 line-clamp-2">{partnerPost.description}</p>
            )}
            {partnerPost.location && (
              <p className="text-xs text-mn-mute mt-0.5 flex items-center gap-1">
                <MapPin className="w-3 h-3" /> {partnerPost.location}
              </p>
            )}
          </div>

          {/* Score breakdown */}
          <div className="flex justify-center">
            <div className="w-full max-w-xs">
              <MatchScore
                score={match.match_score}
                breakdown={match.score_breakdown}
                size="sm"
                showBreakdown
                animated={false}
              />
            </div>
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="px-4 pb-3 flex items-center gap-2 pt-1">
        {/* Expiry info */}
        {match.status === 'suggested' && (
          <span className="text-xs text-mn-mute">
            Laueft ab: {new Date(match.expires_at).toLocaleDateString('de-DE')}
          </span>
        )}

        <div className="flex gap-2 ml-auto">
          {/* Show chat button for accepted matches */}
          {match.status === 'accepted' && match.conversation_id && (
            <button
              onClick={() => onOpenChat(match.conversation_id!)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600 text-white text-xs font-medium rounded-lg hover:bg-indigo-700 transition-colors"
            >
              <MessageCircle className="w-3.5 h-3.5" />
              Chat öffnen
            </button>
          )}

          {/* Accept/Decline for actionable matches */}
          {(match.status === 'suggested' || (match.status === 'pending' && !hasResponded)) && (
            <>
              <button
                onClick={handleDecline}
                disabled={isResponding}
                className="inline-flex items-center gap-1 px-3 py-1.5 bg-mn-elevated text-mn-ink-soft text-xs font-medium rounded-lg border border-white/5 hover:bg-mn-surface hover:text-mn-herzrot hover:border-mn-herzrot/20 transition-colors disabled:opacity-50"
              >
                {isResponding ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <X className="w-3.5 h-3.5" />
                )}
                Ablehnen
              </button>

              <button
                onClick={handleAccept}
                disabled={isResponding}
                className="inline-flex items-center gap-1 px-3 py-1.5 bg-mn-bronze text-white text-xs font-medium rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
              >
                {isResponding ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Check className="w-3.5 h-3.5" />
                )}
                Annehmen
              </button>
            </>
          )}

          {/* Detail button */}
          <button
            onClick={() => onOpenDetail(match)}
            className="inline-flex items-center gap-1 px-3 py-1.5 bg-mn-surface text-mn-ink-soft text-xs font-medium rounded-lg hover:bg-mn-elevated transition-colors"
          >
            Details
          </button>
        </div>
      </div>
    </div>
  )
}
