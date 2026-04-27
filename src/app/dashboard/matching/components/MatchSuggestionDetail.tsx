'use client'

import { useCallback } from 'react'
import {
  X, MapPin, Clock, Check, MessageCircle,
  User, Shield, Tag, ExternalLink, Loader2,
} from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { cn } from '@/lib/design-system'
import { getTypeConfig } from '@/lib/post-types'
import { formatRelativeTime } from '@/lib/notifications'
import type { Match, MatchPostSummary, MatchUserProfile } from '../types'
import { MATCH_STATUS_LABELS, MATCH_STATUS_COLORS } from '../types'
import MatchScore from './MatchScore'

interface MatchSuggestionDetailProps {
  match: Match
  userId: string
  respondingId: string | null
  onClose: () => void
  onAccept: (matchId: string) => void
  onDecline: (matchId: string) => void
  onOpenChat: (conversationId: string) => void
}

function PostSection({ post, label, colorClass }: { post: MatchPostSummary; label: string; colorClass: string }) {
  const typeConfig = getTypeConfig(post.type)

  return (
    <div className={cn('rounded-xl p-4 border', colorClass)}>
      <p className="text-xs font-semibold uppercase tracking-wide mb-2 text-ink-500">{label}</p>
      <h4 className="text-sm font-semibold text-ink-900 mb-1">
        {typeConfig.emoji} {post.title}
      </h4>
      {post.description && (
        <p className="text-xs text-ink-600 mb-2 line-clamp-4">{post.description}</p>
      )}
      <div className="flex flex-wrap gap-2 text-xs text-ink-500">
        {post.category && (
          <span className="flex items-center gap-0.5">
            <Tag className="w-3 h-3" /> {post.category}
          </span>
        )}
        {post.location && (
          <span className="flex items-center gap-0.5">
            <MapPin className="w-3 h-3" /> {post.location}
          </span>
        )}
        {post.urgency && (
          <span className={cn(
            'px-1.5 py-0.5 rounded-full text-xs font-medium',
            post.urgency === 'high' || post.urgency === 'critical'
              ? 'bg-red-100 text-red-700'
              : 'bg-stone-100 text-ink-600',
          )}>
            {post.urgency}
          </span>
        )}
      </div>
      {post.media_urls && post.media_urls.length > 0 && (
        <div className="flex gap-2 mt-3 overflow-x-auto">
          {post.media_urls.slice(0, 3).map((url, i) => (
            <div key={i} className="w-16 h-16 rounded-lg overflow-hidden flex-shrink-0 bg-stone-100">
              <Image src={url} alt="" width={64} height={64} className="w-full h-full object-cover" />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function UserSection({ user, label }: { user: MatchUserProfile; label: string }) {
  return (
    <div className="flex items-center gap-3 p-3 bg-stone-50 rounded-lg">
      <div className="w-10 h-10 rounded-full bg-stone-200 overflow-hidden flex-shrink-0">
        {user.avatar_url ? (
          <Image src={user.avatar_url} alt="" width={40} height={40} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <User className="w-5 h-5 text-ink-400" />
          </div>
        )}
      </div>
      <div className="min-w-0">
        <p className="text-xs text-ink-500 uppercase tracking-wide">{label}</p>
        <Link
          href={`/dashboard/profile/${user.id}`}
          className="text-sm font-medium text-ink-900 hover:text-indigo-600 transition-colors truncate block"
        >
          {user.name || 'Unbekannt'}
        </Link>
        {user.trust_score > 0 && (
          <span className="text-xs text-ink-500 flex items-center gap-0.5">
            <Shield className="w-3 h-3" /> {user.trust_score.toFixed(1)} ({user.trust_score_count} Bewertungen)
          </span>
        )}
      </div>
      <Link
        href={`/dashboard/profile/${user.id}`}
        className="ml-auto p-1 text-ink-400 hover:text-indigo-600 transition-colors"
        aria-label="Profil öffnen"
      >
        <ExternalLink className="w-4 h-4" />
      </Link>
    </div>
  )
}

export default function MatchSuggestionDetail({
  match,
  userId,
  respondingId,
  onClose,
  onAccept,
  onDecline,
  onOpenChat,
}: MatchSuggestionDetailProps) {
  const isOffer = userId === match.offer_user_id
  const hasResponded = isOffer ? match.offer_responded : match.request_responded
  const isResponding = respondingId === match.id
  const statusColors = MATCH_STATUS_COLORS[match.status]

  const handleAccept = useCallback(() => onAccept(match.id), [match.id, onAccept])
  const handleDecline = useCallback(() => onDecline(match.id), [match.id, onDecline])

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="relative bg-white w-full max-w-lg max-h-[90vh] rounded-t-2xl sm:rounded-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-stone-100">
          <div className="flex items-center gap-2">
            <h3 className="text-base font-semibold text-ink-900">Match-Details</h3>
            <span
              className={cn(
                'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border',
                statusColors.text, statusColors.bg, statusColors.border,
              )}
            >
              {MATCH_STATUS_LABELS[match.status]}
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-400 transition-colors"
            aria-label="Schließen"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Score circle centered */}
          <div className="flex justify-center">
            <MatchScore
              score={match.match_score}
              breakdown={match.score_breakdown}
              size="lg"
              showBreakdown
            />
          </div>

          {/* Meta info */}
          <div className="flex flex-wrap items-center justify-center gap-4 text-xs text-ink-500">
            {match.distance_km != null && (
              <span className="flex items-center gap-1">
                <MapPin className="w-3.5 h-3.5" />
                {match.distance_km < 1
                  ? `${Math.round(match.distance_km * 1000)}m Entfernung`
                  : `${Math.round(match.distance_km)}km Entfernung`}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" />
              {formatRelativeTime(match.created_at)}
            </span>
          </div>

          {/* Users */}
          <div className="space-y-2">
            <UserSection user={match.offer_user} label="Anbieter" />
            <UserSection user={match.request_user} label="Suchender" />
          </div>

          {/* Posts */}
          <div className="space-y-3">
            <PostSection
              post={match.offer_post}
              label="Angebot"
              colorClass="bg-primary-50/50 border-primary-100"
            />
            <PostSection
              post={match.request_post}
              label="Gesuch"
              colorClass="bg-blue-50/50 border-blue-100"
            />
          </div>

          {/* Expiry */}
          {(match.status === 'suggested' || match.status === 'pending') && (
            <p className="text-center text-xs text-ink-400">
              Laueft ab am {new Date(match.expires_at).toLocaleDateString('de-DE', {
                day: 'numeric',
                month: 'long',
                year: 'numeric',
              })}
            </p>
          )}
        </div>

        {/* Footer actions */}
        <div className="p-4 border-t border-stone-100 flex items-center gap-2">
          {/* Chat button */}
          {match.status === 'accepted' && match.conversation_id && (
            <button
              onClick={() => onOpenChat(match.conversation_id!)}
              className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-indigo-600 text-white text-sm font-medium rounded-xl hover:bg-indigo-700 transition-colors"
            >
              <MessageCircle className="w-4 h-4" />
              Chat öffnen
            </button>
          )}

          {/* Accept/Decline */}
          {(match.status === 'suggested' || (match.status === 'pending' && !hasResponded)) && (
            <>
              <button
                onClick={handleDecline}
                disabled={isResponding}
                className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-white text-ink-600 text-sm font-medium rounded-xl border border-stone-200 hover:bg-red-50 hover:text-red-600 hover:border-red-200 transition-colors disabled:opacity-50"
              >
                {isResponding ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <X className="w-4 h-4" />
                )}
                Ablehnen
              </button>

              <button
                onClick={handleAccept}
                disabled={isResponding}
                className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-primary-600 text-white text-sm font-medium rounded-xl hover:bg-primary-700 transition-colors disabled:opacity-50"
              >
                {isResponding ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Check className="w-4 h-4" />
                )}
                Annehmen
              </button>
            </>
          )}

          {/* Waiting state */}
          {match.status === 'pending' && hasResponded && (
            <div className="flex-1 text-center text-sm text-amber-600 font-medium py-2.5">
              Warte auf Antwort der anderen Seite...
            </div>
          )}

          {/* Close for other states */}
          {!['suggested', 'pending', 'accepted'].includes(match.status) && (
            <button
              onClick={onClose}
              className="flex-1 inline-flex items-center justify-center px-4 py-2.5 bg-stone-100 text-ink-700 text-sm font-medium rounded-xl hover:bg-stone-200 transition-colors"
            >
              Schließen
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
