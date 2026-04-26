'use client'

import { useState } from 'react'
import { Heart, Loader2, X } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { handleSupabaseError } from '@/lib/errors'

const EMOJIS = ['🙏', '❤️', '🌟', '🌻', '🍀'] as const
const MAX_MESSAGE = 200

interface ThankYouButtonProps {
  currentUserId?: string
  toUserId: string
  postId?: string
  /** Show only icon when compact (e.g. in PostCard action bar) */
  compact?: boolean
}

export default function ThankYouButton({
  currentUserId,
  toUserId,
  postId,
  compact = true,
}: ThankYouButtonProps) {
  const [open, setOpen] = useState(false)
  const [emoji, setEmoji] = useState<string>(EMOJIS[0])
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [sent, setSent] = useState(false)

  // Don't show to post-owner or anonymous viewers
  const disabled = !currentUserId || currentUserId === toUserId

  if (disabled) return null

  const handleOpen = () => setOpen(true)
  const handleClose = () => {
    if (sending) return
    setOpen(false)
    setMessage('')
    setEmoji(EMOJIS[0])
  }

  const handleSend = async () => {
    setSending(true)
    const supabase = createClient()
    const { error } = await supabase.from('thanks').insert({
      from_user_id: currentUserId,
      to_user_id:   toUserId,
      post_id:      postId ?? null,
      emoji,
      message:      message.trim() || null,
    })
    setSending(false)
    if (error) {
      // Unique constraint violation → already thanked this post
      if (error.code === '23505') {
        toast('Du hast schon ein Danke gesendet.')
        setSent(true)
        setTimeout(() => setOpen(false), 800)
        return
      }
      handleSupabaseError(error)
      return
    }
    toast.success('Danke gesendet 🙏')
    setSent(true)
    setTimeout(() => { setOpen(false); setSent(false) }, 800)
  }

  return (
    <>
      <button
        type="button"
        onClick={handleOpen}
        title="Danke sagen"
        className={cn(
          'flex items-center gap-1.5 rounded-lg transition-colors',
          compact
            ? 'p-1.5 hover:bg-warm-100 text-rose-400 hover:text-rose-600'
            : 'px-3 py-2 text-xs font-medium bg-rose-50 text-rose-600 hover:bg-rose-100 border border-rose-200',
        )}
      >
        <Heart className={compact ? 'w-4 h-4' : 'w-3.5 h-3.5'} />
        {!compact && 'Danke sagen'}
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
          onClick={handleClose}
        >
          <div
            className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-4 animate-slide-up"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="font-bold text-ink-900">Danke sagen</p>
                <p className="text-xs text-ink-500 mt-0.5">
                  Ein kleines Zeichen der Wertschätzung
                </p>
              </div>
              <button
                onClick={handleClose}
                aria-label="Schließen"
                className="text-ink-400 hover:text-ink-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Emoji-Auswahl */}
            <div className="flex items-center justify-between gap-2">
              {EMOJIS.map((e) => (
                <button
                  key={e}
                  type="button"
                  onClick={() => setEmoji(e)}
                  className={cn(
                    'flex-1 aspect-square rounded-xl text-3xl transition-all',
                    emoji === e
                      ? 'bg-primary-50 ring-2 ring-primary-400 scale-110'
                      : 'bg-stone-50 hover:bg-stone-100 hover:scale-105',
                  )}
                  aria-pressed={emoji === e}
                >
                  {e}
                </button>
              ))}
            </div>

            {/* Nachricht */}
            <div>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value.slice(0, MAX_MESSAGE))}
                placeholder="Kurze Nachricht (optional)…"
                rows={3}
                className="input resize-none text-sm w-full"
                maxLength={MAX_MESSAGE}
              />
              <p className="text-right text-[10px] text-ink-400 mt-1">
                {message.length}/{MAX_MESSAGE}
              </p>
            </div>

            {/* Senden */}
            <button
              onClick={handleSend}
              disabled={sending || sent}
              className={cn(
                'w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-semibold transition-all',
                sent
                  ? 'bg-green-500 text-white'
                  : 'bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-60',
              )}
            >
              {sending && <Loader2 className="w-4 h-4 animate-spin" />}
              {!sending && !sent && <>{emoji} Senden</>}
              {sent && <>Gesendet 🎉</>}
            </button>
          </div>
        </div>
      )}
    </>
  )
}
