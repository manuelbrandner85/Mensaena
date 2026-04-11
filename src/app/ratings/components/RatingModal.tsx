'use client'

import { useState, useEffect } from 'react'
import { X, ChevronRight, ChevronLeft, User, Loader2 } from 'lucide-react'
import { useRatingStore } from '@/store/useRatingStore'
import { RATING_CATEGORIES } from '@/lib/trust-score'
import RatingStars from './RatingStars'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import type { RatingCategory } from '@/types'

interface RatingModalProps {
  currentUserId: string
}

export default function RatingModal({ currentUserId }: RatingModalProps) {
  const {
    isRatingModalOpen,
    currentRating,
    loading,
    closeRatingModal,
    submitRating,
  } = useRatingStore()

  const [step, setStep] = useState(0)
  const [rating, setRating] = useState(0)
  const [categories, setCategories] = useState<RatingCategory[]>([])
  const [helpful, setHelpful] = useState<boolean | null>(null)
  const [wouldRecommend, setWouldRecommend] = useState<boolean | null>(null)
  const [comment, setComment] = useState('')

  // Reset when modal opens
  useEffect(() => {
    if (isRatingModalOpen) {
      setStep(0)
      setRating(0)
      setCategories([])
      setHelpful(null)
      setWouldRecommend(null)
      setComment('')
    }
  }, [isRatingModalOpen])

  // Prevent body scroll
  useEffect(() => {
    if (isRatingModalOpen) {
      document.body.style.overflow = 'hidden'
    }
    return () => { document.body.style.overflow = '' }
  }, [isRatingModalOpen])

  if (!isRatingModalOpen || !currentRating) return null

  const toggleCategory = (cat: RatingCategory) => {
    setCategories(prev =>
      prev.includes(cat) ? prev.filter(c => c !== cat) : [...prev, cat],
    )
  }

  const handleSubmit = async () => {
    if (rating === 0) {
      toast.error('Bitte waehle eine Bewertung')
      return
    }

    const success = await submitRating(currentUserId, {
      ratedId: currentRating.partnerId,
      rating,
      comment: comment.trim() || undefined,
      interactionId: currentRating.interactionId || undefined,
      categories,
      helpful: helpful ?? undefined,
      wouldRecommend: wouldRecommend ?? undefined,
    })

    if (success) {
      toast.success('Bewertung abgegeben!')
      closeRatingModal()
    } else {
      toast.error('Bewertung konnte nicht gespeichert werden. Bitte versuche es spaeter.')
    }
  }

  const canNext = step === 0 ? rating > 0 : true
  const isLastStep = step === 2
  const steps = ['Bewertung', 'Details', 'Kommentar']

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={closeRatingModal}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-slide-up overflow-hidden"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-warm-100">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden flex-shrink-0">
              {currentRating.partnerAvatar ? (
                <img src={currentRating.partnerAvatar} alt="" className="w-full h-full object-cover" />
              ) : (
                <User className="w-5 h-5 text-primary-600" />
              )}
            </div>
            <div>
              <p className="font-bold text-gray-900 text-sm">
                {currentRating.partnerName || 'Nutzer'} bewerten
              </p>
              {currentRating.postTitle && (
                <p className="text-xs text-gray-500 line-clamp-1">
                  {currentRating.postTitle}
                </p>
              )}
            </div>
          </div>
          <button
            onClick={closeRatingModal}
            className="p-2 rounded-xl hover:bg-warm-100 text-gray-500 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Step indicator */}
        <div className="flex items-center gap-2 px-5 py-3 bg-warm-50">
          {steps.map((label, i) => (
            <div key={label} className="flex items-center gap-2 flex-1">
              <div className={cn(
                'w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold transition-colors',
                i === step ? 'bg-primary-600 text-white' : i < step ? 'bg-primary-200 text-primary-700' : 'bg-gray-200 text-gray-400',
              )}>
                {i + 1}
              </div>
              <span className={cn(
                'text-xs font-medium hidden sm:block',
                i === step ? 'text-gray-900' : 'text-gray-400',
              )}>
                {label}
              </span>
              {i < steps.length - 1 && (
                <div className={cn('flex-1 h-0.5 rounded', i < step ? 'bg-primary-300' : 'bg-gray-200')} />
              )}
            </div>
          ))}
        </div>

        {/* Step content */}
        <div className="p-5 min-h-[260px]">
          {/* Step 0: Stars */}
          {step === 0 && (
            <div className="flex flex-col items-center gap-6 py-4">
              <p className="text-lg font-semibold text-gray-900 text-center">
                Wie war die Zusammenarbeit?
              </p>
              <RatingStars
                value={rating}
                onChange={setRating}
                size="lg"
                showLabel
              />
              {rating > 0 && (
                <p className="text-sm text-gray-500 animate-fade-in">
                  {rating} von 5 Sternen
                </p>
              )}
            </div>
          )}

          {/* Step 1: Categories + yes/no */}
          {step === 1 && (
            <div className="space-y-5">
              <div>
                <p className="text-sm font-semibold text-gray-900 mb-3">
                  Was trifft zu? (optional)
                </p>
                <div className="flex flex-wrap gap-2">
                  {RATING_CATEGORIES.map(cat => (
                    <button
                      key={cat.value}
                      type="button"
                      onClick={() => toggleCategory(cat.value as RatingCategory)}
                      className={cn(
                        'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium border transition-all',
                        categories.includes(cat.value as RatingCategory)
                          ? 'bg-primary-100 text-primary-700 border-primary-300'
                          : 'bg-white text-gray-600 border-gray-200 hover:bg-warm-50',
                      )}
                    >
                      <span>{cat.emoji}</span>
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-700">War die Hilfe hilfreich?</span>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setHelpful(helpful === true ? null : true)}
                      className={cn(
                        'px-3 py-1 rounded-lg text-sm font-medium border transition-all',
                        helpful === true ? 'bg-green-100 text-green-700 border-green-300' : 'bg-white text-gray-500 border-gray-200',
                      )}
                    >
                      Ja
                    </button>
                    <button
                      type="button"
                      onClick={() => setHelpful(helpful === false ? null : false)}
                      className={cn(
                        'px-3 py-1 rounded-lg text-sm font-medium border transition-all',
                        helpful === false ? 'bg-red-100 text-red-700 border-red-300' : 'bg-white text-gray-500 border-gray-200',
                      )}
                    >
                      Nein
                    </button>
                  </div>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-700">Wuerdest du weiterempfehlen?</span>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setWouldRecommend(wouldRecommend === true ? null : true)}
                      className={cn(
                        'px-3 py-1 rounded-lg text-sm font-medium border transition-all',
                        wouldRecommend === true ? 'bg-green-100 text-green-700 border-green-300' : 'bg-white text-gray-500 border-gray-200',
                      )}
                    >
                      Ja
                    </button>
                    <button
                      type="button"
                      onClick={() => setWouldRecommend(wouldRecommend === false ? null : false)}
                      className={cn(
                        'px-3 py-1 rounded-lg text-sm font-medium border transition-all',
                        wouldRecommend === false ? 'bg-red-100 text-red-700 border-red-300' : 'bg-white text-gray-500 border-gray-200',
                      )}
                    >
                      Nein
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 2: Comment */}
          {step === 2 && (
            <div className="space-y-4">
              <p className="text-sm font-semibold text-gray-900">
                Moechtest du noch etwas schreiben? (optional)
              </p>
              <textarea
                value={comment}
                onChange={e => setComment(e.target.value.slice(0, 500))}
                placeholder="Deine Erfahrung mit diesem Nutzer..."
                rows={4}
                className="input resize-none w-full text-sm"
              />
              <p className="text-right text-[10px] text-gray-400">{comment.length}/500</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between p-5 border-t border-warm-100 bg-warm-50">
          <button
            type="button"
            onClick={() => step > 0 ? setStep(step - 1) : closeRatingModal()}
            className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            {step > 0 ? 'Zurück' : 'Abbrechen'}
          </button>

          {isLastStep ? (
            <button
              type="button"
              onClick={handleSubmit}
              disabled={loading || rating === 0}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                'Bewertung abgeben'
              )}
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setStep(step + 1)}
              disabled={!canNext}
              className="flex items-center gap-1 px-5 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
            >
              Weiter
              <ChevronRight className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
