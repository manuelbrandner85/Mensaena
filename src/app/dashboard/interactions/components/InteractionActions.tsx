'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  Check, X, Play, Flag, Ban, AlertTriangle, Star,
  MessageCircle, Loader2,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Interaction } from '../types'

interface Props {
  interaction: Interaction
  canAccept: boolean
  canDecline: boolean
  canStart: boolean
  canComplete: boolean
  canCancel: boolean
  canDispute: boolean
  canRate: boolean
  onAccept: (id: string, accept: boolean, msg?: string) => Promise<void>
  onStart: (id: string) => Promise<void>
  onComplete: (id: string, notes?: string) => Promise<void>
  onCancel: (id: string, reason?: string) => Promise<void>
  onDispute: (id: string, reason: string) => Promise<void>
}

export default function InteractionActions({
  interaction: i, canAccept, canDecline, canStart,
  canComplete, canCancel, canDispute, canRate,
  onAccept, onStart, onComplete, onCancel, onDispute,
}: Props) {
  const router = useRouter()
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [showDeclineInput, setShowDeclineInput] = useState(false)
  const [showCancelInput, setShowCancelInput] = useState(false)
  const [showDisputeInput, setShowDisputeInput] = useState(false)
  const [showCompleteInput, setShowCompleteInput] = useState(false)
  const [inputValue, setInputValue] = useState('')

  const wrap = async (key: string, fn: () => Promise<void>) => {
    setActionLoading(key)
    try { await fn() } finally { setActionLoading(null) }
  }

  const hasAnyAction = canAccept || canDecline || canStart || canComplete || canCancel || canDispute || canRate
  if (!hasAnyAction && !i.conversation_id) return null

  return (
    <div className="bg-mn-elevated rounded-xl border border-white/5 p-5 space-y-3">
      <h3 className="text-sm font-semibold text-mn-ink mb-1">Aktionen</h3>

      {/* Chat link */}
      {i.conversation_id && (
        <button
          onClick={() => router.push(`/dashboard/chat?conv=${i.conversation_id}`)}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-mn-surface text-mn-amber border border-white/5 hover:bg-mn-elevated transition-all"
        >
          <MessageCircle className="w-4 h-4" /> Zum Chat
        </button>
      )}

      {/* Accept */}
      {canAccept && (
        <button
          disabled={!!actionLoading}
          onClick={() => wrap('accept', () => onAccept(i.id, true))}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-mn-amber text-white hover:bg-primary-700 transition-all disabled:opacity-50"
        >
          {actionLoading === 'accept' ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
          Annehmen
        </button>
      )}

      {/* Decline */}
      {canDecline && !showDeclineInput && (
        <button
          onClick={() => setShowDeclineInput(true)}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-mn-surface text-mn-herzrot border border-mn-herzrot/20 hover:bg-mn-elevated transition-all"
        >
          <X className="w-4 h-4" /> Ablehnen
        </button>
      )}
      {showDeclineInput && (
        <div className="space-y-2">
          <textarea
            value={inputValue}
            onChange={e => setInputValue(e.target.value)}
            placeholder="Grund (optional)..."
            rows={2}
            className="w-full text-sm border border-white/5 rounded-lg px-3 py-2 focus:ring-2 focus:ring-mn-herzrot/30"
          />
          <div className="flex gap-2">
            <button
              disabled={!!actionLoading}
              onClick={() => wrap('decline', async () => {
                await onAccept(i.id, false, inputValue || undefined)
                setShowDeclineInput(false)
                setInputValue('')
              })}
              className="flex-1 py-2 rounded-lg text-sm font-medium bg-red-600 text-white hover:bg-mn-herzrot/8 disabled:opacity-50"
            >
              {actionLoading === 'decline' ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Ablehnen'}
            </button>
            <button onClick={() => { setShowDeclineInput(false); setInputValue('') }} className="px-4 py-2 rounded-lg text-sm text-mn-ink-soft bg-mn-elevated hover:bg-mn-raised">
              Abbrechen
            </button>
          </div>
        </div>
      )}

      {/* Start progress */}
      {canStart && (
        <button
          disabled={!!actionLoading}
          onClick={() => wrap('start', () => onStart(i.id))}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-amber-500 text-white hover:bg-amber-600 transition-all disabled:opacity-50"
        >
          {actionLoading === 'start' ? <Loader2 className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4" />}
          Hilfe starten
        </button>
      )}

      {/* Complete */}
      {canComplete && !showCompleteInput && (
        <button
          onClick={() => setShowCompleteInput(true)}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-green-600 text-white hover:bg-mn-leben/8 transition-all"
        >
          <Flag className="w-4 h-4" /> Als abgeschlossen markieren
        </button>
      )}
      {showCompleteInput && (
        <div className="space-y-2">
          <textarea
            value={inputValue}
            onChange={e => setInputValue(e.target.value)}
            placeholder="Abschlussnotiz (optional)..."
            rows={2}
            className="w-full text-sm border border-white/5 rounded-lg px-3 py-2 focus:ring-2 focus:ring-primary-400"
          />
          <div className="flex gap-2">
            <button
              disabled={!!actionLoading}
              onClick={() => wrap('complete', async () => {
                await onComplete(i.id, inputValue || undefined)
                setShowCompleteInput(false)
                setInputValue('')
              })}
              className="flex-1 py-2 rounded-lg text-sm font-medium bg-green-600 text-white hover:bg-mn-leben/8 disabled:opacity-50"
            >
              {actionLoading === 'complete' ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Abschliessen'}
            </button>
            <button onClick={() => { setShowCompleteInput(false); setInputValue('') }} className="px-4 py-2 rounded-lg text-sm text-mn-ink-soft bg-mn-elevated hover:bg-mn-raised">
              Abbrechen
            </button>
          </div>
        </div>
      )}

      {/* Rate */}
      {canRate && (
        <button
          onClick={() => router.push(`/dashboard/interactions/${i.id}?rate=1`)}
          className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-mn-amber/5 text-mn-amber border border-mn-amber/20 hover:bg-mn-amber/10 transition-all"
        >
          <Star className="w-4 h-4" /> Bewerten
        </button>
      )}

      {/* Cancel */}
      {canCancel && !showCancelInput && (
        <button
          onClick={() => setShowCancelInput(true)}
          className="w-full flex items-center justify-center gap-2 py-2 rounded-xl text-xs font-medium text-mn-mute hover:text-mn-herzrot hover:bg-mn-surface transition-all"
        >
          <Ban className="w-3.5 h-3.5" /> Absagen
        </button>
      )}
      {showCancelInput && (
        <div className="space-y-2">
          <textarea
            value={inputValue}
            onChange={e => setInputValue(e.target.value)}
            placeholder="Grund der Absage..."
            rows={2}
            className="w-full text-sm border border-white/5 rounded-lg px-3 py-2 focus:ring-2 focus:ring-mn-herzrot/30"
          />
          <div className="flex gap-2">
            <button
              disabled={!!actionLoading}
              onClick={() => wrap('cancel', async () => {
                await onCancel(i.id, inputValue || undefined)
                setShowCancelInput(false)
                setInputValue('')
              })}
              className="flex-1 py-2 rounded-lg text-sm font-medium bg-red-600 text-white hover:bg-mn-herzrot/8 disabled:opacity-50"
            >
              {actionLoading === 'cancel' ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Absagen'}
            </button>
            <button onClick={() => { setShowCancelInput(false); setInputValue('') }} className="px-4 py-2 rounded-lg text-sm text-mn-ink-soft bg-mn-elevated hover:bg-mn-raised">
              Abbrechen
            </button>
          </div>
        </div>
      )}

      {/* Dispute */}
      {canDispute && !showDisputeInput && (
        <button
          onClick={() => setShowDisputeInput(true)}
          className="w-full flex items-center justify-center gap-2 py-2 rounded-xl text-xs font-medium text-mn-mute hover:text-mn-amber-warm hover:bg-mn-surface transition-all"
        >
          <AlertTriangle className="w-3.5 h-3.5" /> Problem melden
        </button>
      )}
      {showDisputeInput && (
        <div className="space-y-2">
          <textarea
            value={inputValue}
            onChange={e => setInputValue(e.target.value)}
            placeholder="Beschreibe das Problem..."
            rows={3}
            className="w-full text-sm border border-white/5 rounded-lg px-3 py-2 focus:ring-2 focus:ring-orange-400"
          />
          <div className="flex gap-2">
            <button
              disabled={!!actionLoading || !inputValue.trim()}
              onClick={() => wrap('dispute', async () => {
                await onDispute(i.id, inputValue)
                setShowDisputeInput(false)
                setInputValue('')
              })}
              className="flex-1 py-2 rounded-lg text-sm font-medium bg-orange-600 text-white hover:bg-mn-amber/10 disabled:opacity-50"
            >
              {actionLoading === 'dispute' ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Melden'}
            </button>
            <button onClick={() => { setShowDisputeInput(false); setInputValue('') }} className="px-4 py-2 rounded-lg text-sm text-mn-ink-soft bg-mn-elevated hover:bg-mn-raised">
              Abbrechen
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
