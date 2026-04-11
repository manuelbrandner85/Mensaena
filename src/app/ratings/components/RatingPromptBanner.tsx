'use client'

import { useState, useEffect } from 'react'
import { Star, X, User } from 'lucide-react'
import { useRatingStore } from '@/store/useRatingStore'
import type { PendingRating } from '@/types'

interface RatingPromptBannerProps {
  userId: string
}

const DISMISS_KEY = 'mensaena_rating_prompt_dismissed'

export default function RatingPromptBanner({ userId }: RatingPromptBannerProps) {
  const { pendingRatings, loadPendingRatings, openRatingModal } = useRatingStore()
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    loadPendingRatings(userId)
  }, [userId, loadPendingRatings])

  // Check for dismiss with 24h expiry
  useEffect(() => {
    const stored = localStorage.getItem(DISMISS_KEY)
    if (stored) {
      const ts = parseInt(stored, 10)
      if (Date.now() - ts < 24 * 60 * 60 * 1000) {
        setDismissed(true)
      } else {
        localStorage.removeItem(DISMISS_KEY)
      }
    }
  }, [])

  if (dismissed || pendingRatings.length === 0) return null

  const first = pendingRatings[0]

  const handleDismiss = () => {
    setDismissed(true)
    localStorage.setItem(DISMISS_KEY, String(Date.now()))
  }

  const handleRate = (pr: PendingRating) => {
    openRatingModal({
      partnerId: pr.partner_id,
      partnerName: pr.partner_name,
      partnerAvatar: pr.partner_avatar,
      interactionId: pr.interaction_id,
      postTitle: pr.post_title,
    })
  }

  return (
    <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex items-start gap-4 animate-fade-in">
      {/* Avatar or icon */}
      <div className="w-12 h-12 rounded-full bg-amber-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
        {first.partner_avatar ? (
          <img src={first.partner_avatar} alt="" className="w-full h-full object-cover" />
        ) : (
          <User className="w-6 h-6 text-amber-600" />
        )}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="text-sm font-semibold text-amber-900">
              {pendingRatings.length === 1
                ? 'Du hast eine offene Bewertung'
                : `Du hast ${pendingRatings.length} offene Bewertungen`}
            </p>
            <p className="text-xs text-amber-700 mt-0.5">
              Bewerte {first.partner_name || 'deinen Nachbarn'} für die Zusammenarbeit
              {first.post_title ? ` bei "${first.post_title}"` : ''}
            </p>
          </div>
          <button
            onClick={handleDismiss}
            className="p-1 rounded-lg hover:bg-amber-200 transition-colors flex-shrink-0"
            title="Spaeter erinnern"
          >
            <X className="w-4 h-4 text-amber-500" />
          </button>
        </div>

        <button
          onClick={() => handleRate(first)}
          className="mt-2 flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium bg-amber-600 text-white hover:bg-amber-700 transition-all active:scale-95"
        >
          <Star className="w-4 h-4" /> Jetzt bewerten
        </button>
      </div>
    </div>
  )
}
