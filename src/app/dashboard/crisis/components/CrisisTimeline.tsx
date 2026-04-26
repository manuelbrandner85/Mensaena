'use client'

import { useState } from 'react'
import { Send, ImagePlus, Loader2, Pin, Info, AlertTriangle, CheckCircle2, Users, Package, Megaphone } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatRelativeTime } from '@/lib/utils'
import type { CrisisUpdate, UpdateType } from '../types'

const UPDATE_TYPE_CONFIG: Record<UpdateType, { icon: typeof Info; color: string; label: string }> = {
  info:            { icon: Info,          color: 'text-blue-500 bg-blue-100',     label: 'Info' },
  status_change:   { icon: AlertTriangle, color: 'text-orange-500 bg-orange-100', label: 'Status' },
  resource_update: { icon: Package,       color: 'text-primary-500 bg-primary-100', label: 'Ressourcen' },
  helper_update:   { icon: Users,         color: 'text-indigo-500 bg-indigo-100', label: 'Helfer' },
  resolution:      { icon: CheckCircle2,  color: 'text-green-500 bg-green-100',   label: 'Lösung' },
  warning:         { icon: AlertTriangle, color: 'text-red-500 bg-red-100',       label: 'Warnung' },
  official:        { icon: Megaphone,     color: 'text-purple-500 bg-purple-100', label: 'Offiziell' },
}

interface Props {
  updates: CrisisUpdate[]
  loading: boolean
  onAddUpdate?: (content: string, updateType: UpdateType) => Promise<void>
  canPost?: boolean
}

export default function CrisisTimeline({ updates, loading, onAddUpdate, canPost = false }: Props) {
  const [newContent, setNewContent] = useState('')
  const [updateType, setUpdateType] = useState<UpdateType>('info')
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = async () => {
    if (!newContent.trim() || !onAddUpdate) return
    setSubmitting(true)
    try {
      await onAddUpdate(newContent.trim(), updateType)
      setNewContent('')
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="bg-white border border-stone-100 rounded-2xl shadow-sm overflow-hidden">
      <div className="px-4 pt-4 pb-3 border-b border-stone-100">
        <h4 className="text-sm font-bold text-ink-800">Verlauf & Updates</h4>
      </div>

      {/* Add update form */}
      {canPost && onAddUpdate && (
        <div className="px-4 py-3 border-b border-stone-100 bg-stone-50/50">
          <div className="flex gap-2 mb-2">
            {(['info', 'warning', 'resource_update', 'helper_update'] as UpdateType[]).map(t => {
              const cfg = UPDATE_TYPE_CONFIG[t]
              return (
                <button
                  key={t}
                  onClick={() => setUpdateType(t)}
                  className={cn(
                    'px-2 py-1 rounded-lg text-xs font-medium border transition-all',
                    updateType === t ? `${cfg.color} border-current` : 'bg-white border-stone-200 text-ink-500'
                  )}
                >
                  {cfg.label}
                </button>
              )
            })}
          </div>
          <div className="flex gap-2">
            <input
              type="text"
              value={newContent}
              onChange={e => setNewContent(e.target.value)}
              placeholder="Neues Update schreiben..."
              className="flex-1 px-3 py-2 bg-white border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
              maxLength={2000}
              onKeyDown={e => e.key === 'Enter' && handleSubmit()}
              aria-label="Update-Text eingeben"
            />
            <button
              onClick={handleSubmit}
              disabled={!newContent.trim() || submitting}
              className="px-3 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 disabled:opacity-50 transition-colors"
              aria-label="Update senden"
            >
              {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            </button>
          </div>
        </div>
      )}

      {/* Timeline */}
      <div className="px-4 py-3">
        {loading ? (
          <div className="space-y-3">
            {[0, 1, 2].map(i => (
              <div key={i} className="flex gap-3 animate-pulse">
                <div className="w-8 h-8 rounded-full bg-stone-200" />
                <div className="flex-1 space-y-1">
                  <div className="h-4 w-32 bg-stone-200 rounded" />
                  <div className="h-3 w-full bg-stone-100 rounded" />
                </div>
              </div>
            ))}
          </div>
        ) : updates.length === 0 ? (
          <p className="text-xs text-ink-400 text-center py-4">Noch keine Updates vorhanden.</p>
        ) : (
          <div className="relative">
            {/* Timeline line */}
            <div className="absolute left-4 top-4 bottom-4 w-0.5 bg-stone-200" aria-hidden="true" />

            <div className="space-y-4">
              {updates.map(u => {
                const cfg = UPDATE_TYPE_CONFIG[u.update_type] || UPDATE_TYPE_CONFIG.info
                const Icon = cfg.icon
                return (
                  <div key={u.id} className="relative flex gap-3 pl-1">
                    <div className={cn('w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 z-10', cfg.color)}>
                      <Icon className="w-3.5 h-3.5" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <span className="text-xs font-semibold text-ink-800">
                          {u.profiles?.name || 'Anonym'}
                        </span>
                        <span className="text-xs text-ink-400">{formatRelativeTime(u.created_at)}</span>
                        {u.is_pinned && <Pin className="w-3 h-3 text-amber-500" />}
                      </div>
                      <p className="text-xs text-ink-700 leading-relaxed">{u.content}</p>
                      {u.image_url && (
                        <img
                          src={u.image_url}
                          alt="Update-Foto"
                          className="mt-2 rounded-xl max-h-40 object-cover border border-stone-200"
                          loading="lazy"
                        />
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
