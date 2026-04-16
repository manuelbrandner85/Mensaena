'use client'

import { useState } from 'react'

const REACTIONS = [
  { emoji: '👍', label: 'Daumen hoch' },
  { emoji: '❤️', label: 'Herz' },
  { emoji: '🙏', label: 'Danke' },
  { emoji: '💪', label: 'Stark' },
  { emoji: '🎉', label: 'Feier' },
  { emoji: '🤝', label: 'Zusammen' },
]

interface Props {
  postId: string
  initialReactions?: Record<string, number>
  userReaction?: string | null
  onReact?: (emoji: string) => void
  size?: 'sm' | 'md'
}

export default function QuickReactions({
  postId,
  initialReactions = {},
  userReaction = null,
  onReact,
  size = 'sm',
}: Props) {
  const [reactions, setReactions] = useState(initialReactions)
  const [myReaction, setMyReaction] = useState(userReaction)
  const [showPicker, setShowPicker] = useState(false)

  const handleReact = (emoji: string) => {
    const isRemove = myReaction === emoji
    setReactions(prev => {
      const updated = { ...prev }
      if (isRemove) {
        updated[emoji] = Math.max((updated[emoji] || 1) - 1, 0)
        if (updated[emoji] === 0) delete updated[emoji]
      } else {
        // Alte Reaktion entfernen
        if (myReaction && updated[myReaction]) {
          updated[myReaction] = Math.max(updated[myReaction] - 1, 0)
          if (updated[myReaction] === 0) delete updated[myReaction]
        }
        updated[emoji] = (updated[emoji] || 0) + 1
      }
      return updated
    })
    setMyReaction(isRemove ? null : emoji)
    setShowPicker(false)
    onReact?.(isRemove ? '' : emoji)
  }

  const totalReactions = Object.values(reactions).reduce((sum, n) => sum + n, 0)
  const isSmall = size === 'sm'

  return (
    <div className="flex items-center gap-1 relative">
      {/* Bestehende Reaktionen anzeigen */}
      {Object.entries(reactions).map(([emoji, count]) => (
        <button
          key={emoji}
          onClick={() => handleReact(emoji)}
          className={`flex items-center gap-0.5 rounded-full border transition-all ${
            myReaction === emoji
              ? 'bg-primary-50 border-primary-300 text-primary-700'
              : 'bg-gray-50 border-gray-200 text-gray-600 hover:bg-gray-100'
          } ${isSmall ? 'px-1.5 py-0.5 text-xs' : 'px-2 py-1 text-sm'}`}
        >
          <span>{emoji}</span>
          {count > 0 && <span className="tabular-nums">{count}</span>}
        </button>
      ))}

      {/* Add-Button */}
      <button
        onClick={() => setShowPicker(p => !p)}
        className={`rounded-full border border-dashed border-gray-300 text-gray-400 hover:border-primary-300 hover:text-primary-500 transition-all ${
          isSmall ? 'w-6 h-6 text-xs' : 'w-8 h-8 text-sm'
        } flex items-center justify-center`}
      >
        +
      </button>

      {/* Picker */}
      {showPicker && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setShowPicker(false)} />
          <div className="absolute bottom-full left-0 mb-1 bg-white border border-gray-200 rounded-xl shadow-lg p-1.5 flex gap-0.5 z-50">
            {REACTIONS.map(r => (
              <button
                key={r.emoji}
                onClick={() => handleReact(r.emoji)}
                title={r.label}
                className={`w-8 h-8 rounded-lg text-lg hover:bg-gray-100 transition-all flex items-center justify-center ${
                  myReaction === r.emoji ? 'bg-primary-50 ring-2 ring-primary-300' : ''
                }`}
              >
                {r.emoji}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
