'use client'

import { useState } from 'react'
import {
  UserPlus, CheckCircle, XCircle, Play, Flag, Ban,
  AlertTriangle, Scale, MessageCircle, RefreshCw, Send, User,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import { UPDATE_TYPE_LABELS, type InteractionUpdate } from '../types'

const UPDATE_ICONS: Record<string, { icon: typeof UserPlus; color: string }> = {
  created:       { icon: UserPlus,      color: 'bg-blue-100 text-blue-600' },
  accepted:      { icon: CheckCircle,   color: 'bg-primary-100 text-primary-600' },
  declined:      { icon: XCircle,       color: 'bg-red-100 text-red-600' },
  in_progress:   { icon: Play,          color: 'bg-amber-100 text-amber-600' },
  completed:     { icon: Flag,          color: 'bg-green-100 text-green-600' },
  cancelled:     { icon: Ban,           color: 'bg-red-100 text-red-600' },
  disputed:      { icon: AlertTriangle, color: 'bg-orange-100 text-orange-600' },
  resolved:      { icon: Scale,         color: 'bg-gray-100 text-gray-600' },
  message:       { icon: MessageCircle, color: 'bg-gray-100 text-gray-600' },
  status_change: { icon: RefreshCw,     color: 'bg-blue-100 text-blue-600' },
}

interface Props {
  updates: InteractionUpdate[]
  loading: boolean
  canAddNote: boolean
  onAddNote: (content: string) => void
}

export default function InteractionTimeline({ updates, loading, canAddNote, onAddNote }: Props) {
  const [note, setNote] = useState('')
  const [sending, setSending] = useState(false)

  const handleSend = async () => {
    if (!note.trim()) return
    setSending(true)
    await onAddNote(note.trim())
    setNote('')
    setSending(false)
  }

  return (
    <div className="bg-white rounded-xl border border-gray-100 p-5">
      <h3 className="text-sm font-semibold text-gray-800 mb-4">Verlauf</h3>

      {loading ? (
        <div className="space-y-4 animate-pulse">
          {[1, 2, 3].map(i => (
            <div key={i} className="flex gap-3">
              <div className="w-6 h-6 bg-gray-200 rounded-full" />
              <div className="flex-1">
                <div className="h-4 w-3/4 bg-gray-200 rounded mb-1" />
                <div className="h-3 w-1/2 bg-gray-200 rounded" />
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="relative">
          {/* Timeline line */}
          <div className="absolute left-3 top-3 bottom-0 w-0.5 bg-gray-200" />

          <div className="space-y-4">
            {updates.map((update, idx) => {
              const iconCfg = UPDATE_ICONS[update.update_type] ?? UPDATE_ICONS.message
              const Icon = iconCfg.icon

              return (
                <div key={update.id} className="relative flex gap-3">
                  <div className={cn(
                    'w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 z-10',
                    iconCfg.color,
                  )}>
                    <Icon className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0 pb-1">
                    <p className="text-sm">
                      <span className="font-medium text-gray-800">{update.author_name ?? 'Nutzer'}</span>
                      {' '}
                      <span className="text-gray-500">{UPDATE_TYPE_LABELS[update.update_type] ?? update.update_type}</span>
                    </p>
                    {update.content && (
                      <p className="text-sm text-gray-600 mt-0.5">{update.content}</p>
                    )}
                    <p className="text-xs text-gray-400 mt-1">{formatRelativeTime(update.created_at)}</p>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Add note input */}
      {canAddNote && (
        <div className="flex items-center gap-2 mt-4 pt-4 border-t border-gray-100">
          <div className="w-7 h-7 rounded-full bg-primary-100 flex items-center justify-center flex-shrink-0">
            <User className="w-3.5 h-3.5 text-primary-600" />
          </div>
          <input
            type="text"
            value={note}
            onChange={e => setNote(e.target.value)}
            placeholder="Notiz hinzufuegen..."
            className="flex-1 text-sm border border-gray-200 rounded-lg px-3 py-2 focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
            onKeyDown={e => e.key === 'Enter' && handleSend()}
          />
          <button
            onClick={handleSend}
            disabled={!note.trim() || sending}
            className="p-2 rounded-lg bg-primary-600 text-white hover:bg-primary-700 transition-colors disabled:opacity-50"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  )
}
