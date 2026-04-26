'use client'

import { useState } from 'react'
import { X, Flag, Loader2, Star } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Props {
  interactionId: string
  onClose: () => void
  onComplete: (id: string, notes?: string) => Promise<void>
}

export default function CompleteInteractionModal({ interactionId, onClose, onComplete }: Props) {
  const [notes, setNotes] = useState('')
  const [sending, setSending] = useState(false)
  const maxLen = 2000

  const handleComplete = async () => {
    setSending(true)
    await onComplete(interactionId, notes.trim() || undefined)
    setSending(false)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-green-100 flex items-center justify-center">
              <Flag className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <h3 className="font-bold text-ink-900">Interaktion abschliessen</h3>
              <p className="text-xs text-ink-500 mt-0.5">Wie lief die Hilfe?</p>
            </div>
          </div>
          <button onClick={onClose} className="text-ink-400 hover:text-ink-600 transition-colors p-1">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Success hints */}
        <div className="bg-green-50 rounded-xl p-4 text-sm text-green-800">
          <p className="font-medium mb-1">Was passiert als nächstes?</p>
          <ul className="text-xs text-green-700 space-y-1">
            <li className="flex items-center gap-1.5">
              <Star className="w-3 h-3 flex-shrink-0" /> Beide Seiten können eine Bewertung abgeben
            </li>
            <li className="flex items-center gap-1.5">
              <Star className="w-3 h-3 flex-shrink-0" /> Dein Vertrauenswert wird aktualisiert
            </li>
          </ul>
        </div>

        {/* Notes */}
        <div className="space-y-1">
          <label className="text-sm font-medium text-ink-700">Abschlussnotiz (optional)</label>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value.slice(0, maxLen))}
            placeholder="Kurzer Kommentar zum Abschluss..."
            rows={3}
            className="w-full text-sm border border-stone-200 rounded-xl px-4 py-3 focus:ring-2 focus:ring-green-400 resize-none"
          />
          <p className="text-right text-[10px] text-ink-400">{notes.length}/{maxLen}</p>
        </div>

        {/* Actions */}
        <div className="flex gap-2">
          <button
            onClick={handleComplete}
            disabled={sending}
            className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-all disabled:opacity-50"
          >
            {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Flag className="w-4 h-4" />}
            Abschliessen
          </button>
          <button
            onClick={onClose}
            className="px-5 py-3 rounded-xl text-sm font-medium text-ink-600 bg-stone-100 hover:bg-stone-200 transition-all"
          >
            Abbrechen
          </button>
        </div>
      </div>
    </div>
  )
}
