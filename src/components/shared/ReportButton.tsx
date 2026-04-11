'use client'

import { useState } from 'react'
import { Flag, X, Loader2, CheckCircle2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'

interface ReportButtonProps {
  contentType: 'post' | 'comment' | 'message' | 'profile' | 'board_post' | 'event' | 'organization'
  contentId: string
  className?: string
  /** Compact icon-only variant */
  compact?: boolean
}

const REASONS = [
  'Spam oder Werbung',
  'Beleidigung oder Hass',
  'Falsche Informationen',
  'Unangemessener Inhalt',
  'Betrug oder Phishing',
  'Sonstiges',
]

export default function ReportButton({ contentType, contentId, className, compact = false }: ReportButtonProps) {
  const [showModal, setShowModal] = useState(false)
  const [reason, setReason] = useState('')
  const [customReason, setCustomReason] = useState('')
  const [saving, setSaving] = useState(false)

  const handleReport = async () => {
    const finalReason = reason === 'Sonstiges' ? customReason.trim() : reason
    if (!finalReason) { toast.error('Bitte wähle einen Grund'); return }

    setSaving(true)
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { toast.error('Bitte melde dich an'); setSaving(false); return }

    const { error } = await supabase.from('content_reports').insert({
      reporter_id: user.id,
      content_type: contentType,
      content_id: contentId,
      reason: finalReason,
      status: 'pending',
    })

    if (error) {
      if (error.code === '23505') {
        toast.error('Du hast diesen Inhalt bereits gemeldet')
      } else {
        toast.error('Meldung fehlgeschlagen: ' + error.message)
      }
    } else {
      toast.success('Meldung wurde gesendet', { icon: <CheckCircle2 className="w-5 h-5 text-green-500" /> })
    }

    setSaving(false)
    setShowModal(false)
    setReason('')
    setCustomReason('')
  }

  return (
    <>
      <button
        onClick={() => setShowModal(true)}
        className={cn(
          'flex items-center gap-1.5 text-gray-400 hover:text-red-500 transition-colors',
          compact ? 'p-1.5 rounded-lg hover:bg-red-50' : 'px-3 py-1.5 text-xs rounded-lg hover:bg-red-50',
          className,
        )}
        title="Melden"
      >
        <Flag className="w-4 h-4" />
        {!compact && <span>Melden</span>}
      </button>

      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowModal(false)}>
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 flex items-center gap-2">
                <Flag className="w-5 h-5 text-red-500" /> Inhalt melden
              </h3>
              <button onClick={() => setShowModal(false)} className="p-1 rounded-lg hover:bg-gray-100 text-gray-400">
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-sm text-gray-500">Warum möchtest du diesen Inhalt melden?</p>

            <div className="space-y-2">
              {REASONS.map(r => (
                <button
                  key={r}
                  onClick={() => setReason(r)}
                  className={cn(
                    'w-full text-left px-4 py-2.5 rounded-xl text-sm border transition-all',
                    reason === r
                      ? 'bg-red-50 border-red-200 text-red-700 font-medium'
                      : 'bg-gray-50 border-gray-100 text-gray-700 hover:bg-gray-100',
                  )}
                >
                  {r}
                </button>
              ))}
            </div>

            {reason === 'Sonstiges' && (
              <textarea
                value={customReason}
                onChange={e => setCustomReason(e.target.value)}
                placeholder="Beschreibe den Grund..."
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-300 resize-none h-20"
                maxLength={500}
              />
            )}

            <div className="flex gap-3">
              <button onClick={() => setShowModal(false)}
                className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-xl text-sm font-semibold hover:bg-gray-200 transition-colors">
                Abbrechen
              </button>
              <button onClick={handleReport} disabled={saving || !reason || (reason === 'Sonstiges' && !customReason.trim())}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-red-600 text-white rounded-xl text-sm font-semibold hover:bg-red-700 transition-colors disabled:opacity-50">
                {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Flag className="w-4 h-4" />}
                Melden
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
