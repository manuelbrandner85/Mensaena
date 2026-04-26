'use client'

import { useState } from 'react'
import Link from 'next/link'
import { User, MoreHorizontal, Flag, MessageSquare, ThumbsUp, Loader2 } from 'lucide-react'
import RatingStars from './RatingStars'
import { RATING_CATEGORIES } from '@/lib/trust-score'
import { cn, formatRelativeTime } from '@/lib/utils'
import { useRatingStore } from '@/store/useRatingStore'
import toast from 'react-hot-toast'
import type { TrustRating } from '@/types'

interface RatingCardProps {
  rating: TrustRating
  currentUserId?: string
  isOwnProfile?: boolean
}

export default function RatingCard({ rating, currentUserId, isOwnProfile }: RatingCardProps) {
  const [showMenu, setShowMenu] = useState(false)
  const [showResponse, setShowResponse] = useState(false)
  const [responseText, setResponseText] = useState('')
  const [responding, setResponding] = useState(false)
  const { submitResponse, reportRating } = useRatingStore()

  const isRated = currentUserId === rating.rated_id
  const categoryLabels = (rating.categories || []).map(cat => {
    const found = RATING_CATEGORIES.find(c => c.value === cat)
    return found ? { ...found } : null
  }).filter(Boolean)

  const handleResponse = async () => {
    if (!responseText.trim()) return
    setResponding(true)
    const success = await submitResponse(rating.id, responseText.trim())
    setResponding(false)
    if (success) {
      toast.success('Antwort gespeichert')
      setShowResponse(false)
      // Update local state
      rating.response = responseText.trim()
      rating.response_at = new Date().toISOString()
    } else {
      toast.error('Antwort konnte nicht gespeichert werden')
    }
  }

  const handleReport = async () => {
    const success = await reportRating(rating.id)
    if (success) {
      toast.success('Bewertung gemeldet')
    } else {
      toast.error('Melden fehlgeschlagen')
    }
    setShowMenu(false)
  }

  return (
    <div className="bg-white rounded-xl border border-warm-200 p-4 space-y-3">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <Link href={`/dashboard/profile/${rating.rater_id}`} className="flex-shrink-0">
            <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden">
              {rating.rater_avatar ? (
                <img src={rating.rater_avatar} alt="" className="w-full h-full object-cover" />
              ) : (
                <User className="w-5 h-5 text-primary-600" />
              )}
            </div>
          </Link>
          <div>
            <Link
              href={`/dashboard/profile/${rating.rater_id}`}
              className="text-sm font-semibold text-ink-900 hover:text-primary-700 transition-colors"
            >
              {rating.rater_name || 'Nutzer'}
            </Link>
            <div className="flex items-center gap-2">
              <RatingStars value={rating.rating} size="sm" readOnly />
              <span className="text-xs text-ink-400">{formatRelativeTime(rating.created_at)}</span>
            </div>
          </div>
        </div>

        {/* Menu */}
        <div className="relative">
          <button
            onClick={() => setShowMenu(!showMenu)}
            className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors"
          >
            <MoreHorizontal className="w-4 h-4 text-ink-400" />
          </button>
          {showMenu && (
            <>
              <div className="fixed inset-0 z-10" onClick={() => setShowMenu(false)} />
              <div className="absolute right-0 top-8 bg-white rounded-xl shadow-xl border border-stone-200 py-1 min-w-[160px] z-20">
                {!rating.reported && (
                  <button
                    onClick={handleReport}
                    className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors flex items-center gap-2"
                  >
                    <Flag className="w-3.5 h-3.5" /> Melden
                  </button>
                )}
                {rating.reported && (
                  <span className="px-4 py-2 text-sm text-ink-400 block">Bereits gemeldet</span>
                )}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Comment */}
      {rating.comment && (
        <p className="text-sm text-ink-700 leading-relaxed italic">
          &#x201E;{rating.comment}&#x201C;
        </p>
      )}

      {/* Category tags */}
      {categoryLabels.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {categoryLabels.map(cat => cat && (
            <span
              key={cat.value}
              className="inline-flex items-center gap-1 text-xs bg-warm-50 text-ink-600 px-2 py-0.5 rounded-full border border-warm-200"
            >
              <span>{cat.emoji}</span> {cat.label}
            </span>
          ))}
        </div>
      )}

      {/* Helpful / Recommend badges */}
      <div className="flex items-center gap-2">
        {rating.helpful === true && (
          <span className="inline-flex items-center gap-1 text-xs bg-green-50 text-green-700 px-2 py-0.5 rounded-full border border-green-200">
            <ThumbsUp className="w-3 h-3" /> Hilfreich
          </span>
        )}
        {rating.would_recommend === true && (
          <span className="inline-flex items-center gap-1 text-xs bg-blue-50 text-blue-700 px-2 py-0.5 rounded-full border border-blue-200">
            Empfohlen
          </span>
        )}
      </div>

      {/* Response area */}
      {rating.response && (
        <div className="ml-6 pl-4 border-l-2 border-primary-200 bg-primary-50/30 rounded-r-lg p-3">
          <p className="text-xs font-semibold text-primary-700 mb-1">Antwort:</p>
          <p className="text-sm text-ink-700">{rating.response}</p>
          {rating.response_at && (
            <p className="text-xs text-ink-400 mt-1">{formatRelativeTime(rating.response_at)}</p>
          )}
        </div>
      )}

      {/* Answer button (for rated user, if no response yet) */}
      {isRated && isOwnProfile && !rating.response && (
        <>
          {!showResponse ? (
            <button
              onClick={() => setShowResponse(true)}
              className="flex items-center gap-1.5 text-xs text-primary-600 hover:text-primary-700 font-medium transition-colors"
            >
              <MessageSquare className="w-3.5 h-3.5" /> Antworten
            </button>
          ) : (
            <div className="space-y-2 mt-2">
              <textarea
                value={responseText}
                onChange={e => setResponseText(e.target.value.slice(0, 300))}
                placeholder="Deine Antwort..."
                rows={2}
                className="input resize-none w-full text-sm"
              />
              <div className="flex items-center gap-2">
                <button
                  onClick={handleResponse}
                  disabled={responding || !responseText.trim()}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
                >
                  {responding ? <Loader2 className="w-3 h-3 animate-spin" /> : 'Senden'}
                </button>
                <button
                  onClick={() => { setShowResponse(false); setResponseText('') }}
                  className="text-xs text-ink-500 hover:text-ink-700"
                >
                  Abbrechen
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
