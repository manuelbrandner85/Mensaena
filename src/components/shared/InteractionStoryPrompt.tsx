'use client'

import { useState } from 'react'
import { X, BookHeart, Loader2, Sparkles } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

const MAX_TITLE = 120
const MAX_BODY  = 2000

interface InteractionStoryPromptProps {
  interactionId: string
  postTitle: string
  authorId: string
  onClose: () => void
}

type Step = 'ask' | 'write' | 'sending' | 'done'

export default function InteractionStoryPrompt({
  interactionId,
  postTitle,
  authorId,
  onClose,
}: InteractionStoryPromptProps) {
  const [step, setStep]   = useState<Step>('ask')
  const [title, setTitle] = useState('')
  const [body, setBody]   = useState('')

  const handleSubmit = async () => {
    if (title.trim().length < 5 || body.trim().length < 20) {
      toast.error('Bitte fülle Titel und Geschichte aus.')
      return
    }
    setStep('sending')
    const supabase = createClient()
    const { error } = await supabase.from('success_stories').insert({
      interaction_id: interactionId,
      author_id:      authorId,
      title:          title.trim(),
      body:           body.trim(),
    })
    if (error) {
      toast.error('Geschichte konnte nicht gespeichert werden.')
      setStep('write')
      return
    }
    setStep('done')
  }

  return (
    <div
      className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
      onClick={step === 'ask' || step === 'done' ? onClose : undefined}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-5 space-y-4 animate-slide-up"
        onClick={(e) => e.stopPropagation()}
      >
        {/* ── Done state ── */}
        {step === 'done' && (
          <>
            <div className="text-center py-4 space-y-2">
              <div className="text-4xl">🎉</div>
              <p className="font-bold text-ink-800">Danke für deine Geschichte!</p>
              <p className="text-sm text-ink-500">
                Sie wird geprüft und bald auf der Startseite erscheinen.
              </p>
            </div>
            <button onClick={onClose} className="btn-primary w-full">
              Schließen
            </button>
          </>
        )}

        {/* ── Ask state ── */}
        {step === 'ask' && (
          <>
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-primary-100 flex items-center justify-center flex-shrink-0">
                  <BookHeart className="w-4 h-4 text-primary-600" />
                </div>
                <div>
                  <p className="font-bold text-ink-800 leading-tight">Geschichte teilen?</p>
                  <p className="text-xs text-ink-500 mt-0.5">Inspiriere andere Nachbarn</p>
                </div>
              </div>
              <button onClick={onClose} className="text-stone-400 hover:text-stone-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-sm text-ink-600 leading-relaxed">
              Ihr habt bei <span className="font-medium">„{postTitle}"</span> zusammengearbeitet –
              möchtest du eure Erfahrung als kurze Erfolgsgeschichte teilen?
            </p>

            <div className="flex flex-col gap-2">
              <button
                onClick={() => setStep('write')}
                className="btn-primary w-full flex items-center justify-center gap-2"
              >
                <Sparkles className="w-4 h-4" />
                Ja, Geschichte schreiben
              </button>
              <button
                onClick={onClose}
                className="w-full py-2 rounded-xl text-sm text-ink-400 hover:text-ink-600 transition-colors"
              >
                Nein, danke
              </button>
            </div>
          </>
        )}

        {/* ── Write / sending state ── */}
        {(step === 'write' || step === 'sending') && (
          <>
            <div className="flex items-start justify-between">
              <div>
                <p className="font-bold text-ink-800">Eure Erfolgsgeschichte</p>
                <p className="text-xs text-ink-500 mt-0.5">Wird nach Prüfung veröffentlicht</p>
              </div>
              <button
                onClick={onClose}
                disabled={step === 'sending'}
                className="text-stone-400 hover:text-stone-600 disabled:opacity-40"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value.slice(0, MAX_TITLE))}
                  placeholder="Kurzer Titel…"
                  className="input w-full text-sm"
                  disabled={step === 'sending'}
                />
                <p className="text-right text-[10px] text-ink-400 mt-0.5">
                  {title.length}/{MAX_TITLE}
                </p>
              </div>

              <div>
                <textarea
                  value={body}
                  onChange={(e) => setBody(e.target.value.slice(0, MAX_BODY))}
                  placeholder="Was ist passiert? Wie hat die Hilfe ausgesehen? Wie hat es sich angefühlt?…"
                  rows={5}
                  className="input resize-none text-sm w-full"
                  disabled={step === 'sending'}
                />
                <p className="text-right text-[10px] text-ink-400 mt-0.5">
                  {body.length}/{MAX_BODY}
                </p>
              </div>
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleSubmit}
                disabled={step === 'sending'}
                className={cn(
                  'flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-semibold transition-all',
                  'bg-primary-600 text-white hover:bg-primary-700 disabled:opacity-60',
                )}
              >
                {step === 'sending'
                  ? <Loader2 className="w-4 h-4 animate-spin" />
                  : 'Einreichen'}
              </button>
              <button
                onClick={() => setStep('ask')}
                disabled={step === 'sending'}
                className="px-4 py-2.5 rounded-xl text-sm text-ink-500 bg-stone-100 hover:bg-stone-200 transition-all disabled:opacity-40"
              >
                Zurück
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
