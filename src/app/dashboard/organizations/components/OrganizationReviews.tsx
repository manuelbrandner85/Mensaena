'use client'

import { useState } from 'react'
import {
  Star, ThumbsUp, Flag, MessageCircle, Pencil, Trash2,
  Send, ShieldCheck, AlertCircle,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import type { OrganizationReview, CreateReviewInput } from '../types'

// ── Review Card ──────────────────────────────────────────────────────────

function ReviewCard({
  review, userId, onToggleHelpful, onReport, onEdit, onDelete,
}: {
  review: OrganizationReview
  userId: string | null
  onToggleHelpful: (reviewId: string) => void
  onReport: (reviewId: string, reason: string) => void
  onEdit: (review: OrganizationReview) => void
  onDelete: (reviewId: string) => void
}) {
  const [showReport, setShowReport] = useState(false)
  const [reportReason, setReportReason] = useState('')
  const isOwn = userId === review.user_id

  return (
    <div className="bg-white rounded-xl border border-gray-100 p-4" role="article" aria-label="Bewertung">
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2">
          {review.profiles?.avatar_url ? (
            <img src={review.profiles.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
          ) : (
            <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
              <span className="text-xs font-medium text-emerald-700">
                {(review.profiles?.name || 'A')[0].toUpperCase()}
              </span>
            </div>
          )}
          <div>
            <p className="text-sm font-medium text-gray-900">
              {review.profiles?.display_name || review.profiles?.name || 'Anonym'}
            </p>
            <p className="text-xs text-gray-400">{formatRelativeTime(review.created_at)}</p>
          </div>
        </div>
        <div className="flex items-center gap-0.5" aria-label={`${review.rating} Sterne`}>
          {[1, 2, 3, 4, 5].map(star => (
            <Star key={star} className={cn('w-3.5 h-3.5', star <= review.rating ? 'text-yellow-400 fill-yellow-400' : 'text-gray-200')} />
          ))}
        </div>
      </div>

      {review.title && <h4 className="font-medium text-gray-900 text-sm mt-2">{review.title}</h4>}
      <p className="text-sm text-gray-600 mt-1 leading-relaxed">{review.content}</p>

      {/* Admin response */}
      {review.admin_response && (
        <div className="mt-3 p-3 bg-emerald-50 rounded-lg border border-emerald-100">
          <div className="flex items-center gap-1.5 mb-1">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
            <span className="text-xs font-medium text-emerald-700">Antwort der Organisation</span>
          </div>
          <p className="text-xs text-emerald-800">{review.admin_response}</p>
        </div>
      )}

      {/* Actions */}
      <div className="flex items-center gap-3 mt-3 pt-2 border-t border-gray-50">
        <button
          onClick={() => onToggleHelpful(review.id)}
          className={cn(
            'flex items-center gap-1 text-xs transition-colors',
            review.user_found_helpful ? 'text-emerald-600 font-medium' : 'text-gray-400 hover:text-emerald-600'
          )}
          aria-label="Hilfreich markieren"
        >
          <ThumbsUp className="w-3.5 h-3.5" />
          Hilfreich {review.helpful_count > 0 && `(${review.helpful_count})`}
        </button>

        {isOwn && (
          <>
            <button onClick={() => onEdit(review)} className="text-xs text-gray-400 hover:text-blue-600 flex items-center gap-1">
              <Pencil className="w-3 h-3" /> Bearbeiten
            </button>
            <button onClick={() => onDelete(review.id)} className="text-xs text-gray-400 hover:text-red-600 flex items-center gap-1">
              <Trash2 className="w-3 h-3" /> Löschen
            </button>
          </>
        )}

        {!isOwn && !review.is_reported && (
          <button
            onClick={() => setShowReport(s => !s)}
            className="text-xs text-gray-400 hover:text-red-500 flex items-center gap-1 ml-auto"
          >
            <Flag className="w-3 h-3" /> Melden
          </button>
        )}
        {review.is_reported && (
          <span className="text-xs text-red-400 flex items-center gap-1 ml-auto">
            <AlertCircle className="w-3 h-3" /> Gemeldet
          </span>
        )}
      </div>

      {/* Report form */}
      {showReport && (
        <div className="mt-2 p-2 bg-red-50 rounded-lg">
          <textarea
            value={reportReason}
            onChange={e => setReportReason(e.target.value)}
            placeholder="Grund der Meldung..."
            className="w-full text-xs p-2 border border-red-200 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-red-300"
            rows={2}
          />
          <div className="flex gap-2 mt-1">
            <button
              onClick={() => { onReport(review.id, reportReason); setShowReport(false); setReportReason('') }}
              disabled={!reportReason.trim()}
              className="text-xs bg-red-600 text-white px-3 py-1 rounded-lg disabled:opacity-50"
            >
              Absenden
            </button>
            <button onClick={() => setShowReport(false)} className="text-xs text-gray-500">Abbrechen</button>
          </div>
        </div>
      )}
    </div>
  )
}

// ── Review Form ──────────────────────────────────────────────────────────

function ReviewForm({
  orgId, userId, onSubmit, submitting, existingReview, onCancel,
}: {
  orgId: string
  userId: string
  onSubmit: (input: CreateReviewInput) => void
  submitting: boolean
  existingReview?: OrganizationReview | null
  onCancel?: () => void
}) {
  const [rating, setRating] = useState(existingReview?.rating ?? 0)
  const [hoverRating, setHoverRating] = useState(0)
  const [title, setTitle] = useState(existingReview?.title ?? '')
  const [content, setContent] = useState(existingReview?.content ?? '')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (rating === 0 || content.length < 10) return
    onSubmit({ organization_id: orgId, rating, title: title || undefined, content })
    if (!existingReview) {
      setRating(0); setTitle(''); setContent('')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-gray-100 p-4">
      <h3 className="font-semibold text-gray-900 text-sm mb-3">
        {existingReview ? 'Bewertung bearbeiten' : 'Bewertung schreiben'}
      </h3>

      {/* Star rating */}
      <div className="flex items-center gap-1 mb-3" role="radiogroup" aria-label="Bewertung">
        {[1, 2, 3, 4, 5].map(star => (
          <button
            key={star}
            type="button"
            onClick={() => setRating(star)}
            onMouseEnter={() => setHoverRating(star)}
            onMouseLeave={() => setHoverRating(0)}
            className="p-0.5"
            aria-label={`${star} Stern${star > 1 ? 'e' : ''}`}
          >
            <Star className={cn(
              'w-6 h-6 transition-colors',
              star <= (hoverRating || rating)
                ? 'text-yellow-400 fill-yellow-400'
                : 'text-gray-200'
            )} />
          </button>
        ))}
        {rating > 0 && (
          <span className="text-xs text-gray-500 ml-2">{rating} / 5</span>
        )}
      </div>

      <input
        type="text"
        value={title}
        onChange={e => setTitle(e.target.value)}
        placeholder="Titel (optional)"
        className="w-full text-sm p-2.5 border border-gray-200 rounded-xl mb-2 focus:outline-none focus:ring-2 focus:ring-emerald-300"
      />
      <textarea
        value={content}
        onChange={e => setContent(e.target.value)}
        placeholder="Deine Erfahrung (mind. 10 Zeichen)..."
        className="w-full text-sm p-2.5 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-emerald-300"
        rows={3}
        required
        minLength={10}
      />

      <div className="flex items-center gap-2 mt-2">
        <button
          type="submit"
          disabled={submitting || rating === 0 || content.length < 10}
          className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors"
        >
          <Send className="w-3.5 h-3.5" />
          {submitting ? 'Wird gesendet...' : existingReview ? 'Aktualisieren' : 'Bewertung absenden'}
        </button>
        {onCancel && (
          <button type="button" onClick={onCancel} className="text-sm text-gray-500 hover:text-gray-700">
            Abbrechen
          </button>
        )}
      </div>
    </form>
  )
}

// ── Main Component ───────────────────────────────────────────────────────

interface Props {
  orgId: string
  reviews: OrganizationReview[]
  loading: boolean
  hasMore: boolean
  submitting: boolean
  userId: string | null
  ratingAvg: number
  ratingCount: number
  onCreateReview: (input: CreateReviewInput, userId: string) => Promise<void>
  onUpdateReview: (reviewId: string, input: { rating?: number; title?: string; content?: string }) => Promise<void>
  onDeleteReview: (reviewId: string, orgId: string) => Promise<void>
  onToggleHelpful: (reviewId: string, userId: string) => Promise<void>
  onReport: (reviewId: string, reason: string) => Promise<void>
  onLoadMore: (orgId: string) => void
}

export default function OrganizationReviews({
  orgId, reviews, loading, hasMore, submitting,
  userId, ratingAvg, ratingCount,
  onCreateReview, onUpdateReview, onDeleteReview, onToggleHelpful, onReport, onLoadMore,
}: Props) {
  const [editingReview, setEditingReview] = useState<OrganizationReview | null>(null)

  const handleEdit = (review: OrganizationReview) => {
    setEditingReview(review)
  }

  return (
    <section className="space-y-4" aria-label="Bewertungen">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-gray-900 text-lg flex items-center gap-2">
          <MessageCircle className="w-5 h-5 text-gray-400" />
          Bewertungen
          {ratingCount > 0 && (
            <span className="text-sm font-normal text-gray-500">
              ({ratingCount})
            </span>
          )}
        </h2>
        {ratingCount > 0 && (
          <div className="flex items-center gap-1">
            {[1, 2, 3, 4, 5].map(star => (
              <Star key={star} className={cn('w-4 h-4', star <= Math.round(ratingAvg) ? 'text-yellow-400 fill-yellow-400' : 'text-gray-200')} />
            ))}
            <span className="text-sm text-gray-600 ml-1">{ratingAvg}</span>
          </div>
        )}
      </div>

      {/* Write form */}
      {userId && !editingReview && (
        <ReviewForm
          orgId={orgId}
          userId={userId}
          onSubmit={(input) => onCreateReview(input, userId)}
          submitting={submitting}
        />
      )}

      {/* Edit form */}
      {editingReview && userId && (
        <ReviewForm
          orgId={orgId}
          userId={userId}
          existingReview={editingReview}
          onSubmit={(input) => {
            onUpdateReview(editingReview.id, { rating: input.rating, title: input.title, content: input.content })
            setEditingReview(null)
          }}
          submitting={submitting}
          onCancel={() => setEditingReview(null)}
        />
      )}

      {/* Review list */}
      {loading && reviews.length === 0 ? (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="bg-white rounded-xl border border-gray-100 p-4 animate-pulse">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 bg-gray-100 rounded-full" />
                <div className="h-3 bg-gray-100 rounded w-24" />
              </div>
              <div className="h-3 bg-gray-50 rounded w-full mb-1" />
              <div className="h-3 bg-gray-50 rounded w-2/3" />
            </div>
          ))}
        </div>
      ) : reviews.length === 0 ? (
        <div className="text-center py-8 bg-white rounded-xl border border-gray-100">
          <MessageCircle className="w-8 h-8 text-gray-300 mx-auto mb-2" />
          <p className="text-gray-500 text-sm">Noch keine Bewertungen vorhanden.</p>
          {userId && <p className="text-gray-400 text-xs mt-1">Sei der Erste!</p>}
        </div>
      ) : (
        <div className="space-y-3">
          {reviews.map(review => (
            <ReviewCard
              key={review.id}
              review={review}
              userId={userId}
              onToggleHelpful={(rid) => userId && onToggleHelpful(rid, userId)}
              onReport={onReport}
              onEdit={handleEdit}
              onDelete={(rid) => onDeleteReview(rid, orgId)}
            />
          ))}
        </div>
      )}

      {hasMore && !loading && (
        <div className="flex justify-center">
          <button
            onClick={() => onLoadMore(orgId)}
            className="px-4 py-2 text-sm text-emerald-600 hover:text-emerald-800 font-medium"
          >
            Mehr Bewertungen laden
          </button>
        </div>
      )}
    </section>
  )
}
