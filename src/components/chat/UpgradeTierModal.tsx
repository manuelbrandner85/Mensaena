'use client'

import { X, Heart } from 'lucide-react'
import Link from 'next/link'
import { DONOR_TIERS } from '@/lib/donorTier'

interface Props {
  featureLabel: string
  requiredTier: number
  currentTier: number
  donationCount: number
  onClose: () => void
}

export default function UpgradeTierModal({ featureLabel, requiredTier, currentTier, donationCount, onClose }: Props) {
  const required = DONOR_TIERS[requiredTier]
  const current  = DONOR_TIERS[currentTier]

  const neededCount = requiredTier === 2 ? 3 : requiredTier === 3 ? 5 : 10
  const neededTotal = requiredTier === 2 ? 25 : requiredTier === 3 ? 50 : 100
  const progress = Math.min(donationCount / neededCount, 1)

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-3xl shadow-xl w-full max-w-sm p-6"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <span className="text-2xl">{required.emoji}</span>
            <p className="font-bold text-gray-900">{required.name}-Funktion</p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-400">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Info */}
        <div className="bg-gray-50 rounded-2xl p-4 mb-4">
          <p className="text-sm text-gray-700">
            <strong>{featureLabel}</strong> ist ab Stufe{' '}
            <span className={`inline-flex items-center gap-1 font-semibold px-2 py-0.5 rounded-lg text-xs ${required.pillClass}`}>
              {required.emoji} {required.name}
            </span>{' '}
            verfügbar.
          </p>
          <p className="text-xs text-gray-500 mt-1.5">{required.description}</p>
          <p className="text-xs text-gray-400 mt-1">
            Benötigt: mindestens {neededCount} Spenden oder insgesamt {neededTotal} €
          </p>
        </div>

        {/* Progress */}
        <div className="mb-5">
          <div className="flex justify-between text-xs text-gray-500 mb-1.5">
            <span>
              Deine Stufe:{' '}
              {current.emoji ? `${current.emoji} ${current.name}` : current.name}
            </span>
            <span>{donationCount}/{neededCount} Spenden</span>
          </div>
          <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-primary-400 to-primary-600 rounded-full transition-all"
              style={{ width: `${progress * 100}%` }}
            />
          </div>
        </div>

        {/* CTA */}
        <Link
          href="/spenden"
          onClick={onClose}
          className="flex items-center justify-center gap-2 w-full py-3 bg-primary-600 text-white rounded-2xl font-semibold text-sm hover:bg-primary-700 transition-all shadow-sm"
        >
          <Heart className="w-4 h-4" /> Jetzt spenden →
        </Link>
        <p className="text-center text-xs text-gray-400 mt-2">Jede Spende hilft – auch kleine!</p>
      </div>
    </div>
  )
}
