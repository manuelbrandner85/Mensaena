'use client'

import { useState } from 'react'
import { X, Send, Loader2, HandHeart, HelpCircle } from 'lucide-react'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import type { CreateInteractionInput } from '../types'

interface Props {
  postId: string
  postTitle: string
  targetUserId: string
  targetUserName: string
  /** Is the current user offering help (helper) or asking for help (helped)? */
  defaultAsHelper?: boolean
  onClose: () => void
  onCreate: (input: CreateInteractionInput) => Promise<string | null>
}

export default function CreateInteractionModal({
  postId, postTitle, targetUserId, targetUserName,
  defaultAsHelper = true, onClose, onCreate,
}: Props) {
  const [message, setMessage] = useState('')
  const [iAmHelper, setIAmHelper] = useState(defaultAsHelper)
  const [sending, setSending] = useState(false)
  const maxLen = 1000

  const handleCreate = async () => {
    if (!message.trim()) {
      toast.error('Bitte eine kurze Nachricht schreiben')
      return
    }
    setSending(true)
    const id = await onCreate({
      post_id: postId,
      target_user_id: targetUserId,
      message: message.trim(),
      i_am_helper: iAmHelper,
    })
    setSending(false)
    if (id) onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-mn-elevated rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <h3 className="font-bold text-mn-ink text-lg">Hilfe anbieten</h3>
            <p className="text-xs text-mn-mute mt-0.5 line-clamp-1">zu: {postTitle}</p>
          </div>
          <button onClick={onClose} aria-label="Schließen" className="text-mn-mute hover:text-mn-ink-soft transition-colors p-1.5">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Role toggle */}
        <div className="flex gap-2">
          <button
            onClick={() => setIAmHelper(true)}
            className={cn(
              'flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium border transition-all',
              iAmHelper
                ? 'bg-mn-amber/5 text-mn-amber border-mn-amber/20'
                : 'bg-mn-elevated text-mn-ink-soft border-white/5 hover:bg-mn-surface',
            )}
          >
            <HandHeart className="w-4 h-4" /> Ich helfe
          </button>
          <button
            onClick={() => setIAmHelper(false)}
            className={cn(
              'flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium border transition-all',
              !iAmHelper
                ? 'bg-mn-surface text-mn-teal-soft border-white/5'
                : 'bg-mn-elevated text-mn-ink-soft border-white/5 hover:bg-mn-surface',
            )}
          >
            <HelpCircle className="w-4 h-4" /> Ich brauche Hilfe
          </button>
        </div>

        <p className="text-xs text-mn-mute">
          {iAmHelper
            ? `Du bietest ${targetUserName} deine Hilfe an.`
            : `Du fragst ${targetUserName} um Hilfe.`
          }
        </p>

        {/* Message */}
        <div className="space-y-1">
          <textarea
            value={message}
            onChange={e => setMessage(e.target.value.slice(0, maxLen))}
            placeholder="Beschreibe kurz, wie du helfen kannst oder was du brauchst..."
            rows={4}
            className="w-full text-sm border border-white/5 rounded-xl px-4 py-3 focus:ring-2 focus:ring-mn-amber focus:border-mn-amber/30 resize-none"
          />
          <p className="text-right text-xs text-mn-mute">{message.length}/{maxLen}</p>
        </div>

        {/* Submit */}
        <button
          onClick={handleCreate}
          disabled={sending || !message.trim()}
          className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-medium bg-mn-amber text-white hover:bg-primary-700 transition-all disabled:opacity-50"
        >
          {sending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
          Anfrage senden
        </button>
      </div>
    </div>
  )
}
