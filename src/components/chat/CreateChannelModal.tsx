'use client'

import { useState } from 'react'
import { X, Hash, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { cn } from '@/lib/utils'

const CHANNEL_EMOJIS = ['💬', '🏘️', '🌿', '🤝', '🎉', '📢', '🛒', '🎮', '📚', '🏃', '🌍', '🍽️', '🐾', '💡', '🎨', '⚽']

interface Props {
  userId: string
  onClose: () => void
  onCreated: () => void
}

export default function CreateChannelModal({ userId, onClose, onCreated }: Props) {
  const [name, setName] = useState('')
  const [emoji, setEmoji] = useState('💬')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  async function handleCreate() {
    const trimmed = name.trim()
    if (!trimmed) return
    setLoading(true)
    try {
      // 1. Conversation erstellen
      const { data: conv, error: convErr } = await supabase
        .from('conversations')
        .insert({ type: 'group', title: trimmed })
        .select('id')
        .single()
      if (convErr || !conv) throw convErr ?? new Error('Conversation failed')

      // 2. Channel erstellen
      const slug = `${trimmed.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 36)}-${Date.now().toString(36)}`
      const { error: chErr } = await supabase.from('chat_channels').insert({
        name: trimmed,
        slug,
        emoji,
        description: description.trim() || null,
        category: 'Community',
        conversation_id: conv.id,
        created_by: userId,
      })
      if (chErr) throw chErr

      toast.success('Kanal erstellt!')
      onCreated()
      onClose()
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e)
      toast.error(`Fehler: ${msg}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-bold text-gray-900 text-lg">Kanal erstellen</h3>
            <p className="text-xs text-gray-500 mt-0.5">Förderer-Feature – für alle sichtbar</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-500 transition-all">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-4">
          {/* Emoji */}
          <div>
            <p className="text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wide">Emoji</p>
            <div className="flex flex-wrap gap-2">
              {CHANNEL_EMOJIS.map(e => (
                <button key={e} type="button" onClick={() => setEmoji(e)}
                  className={cn(
                    'w-9 h-9 rounded-xl text-lg flex items-center justify-center transition-all',
                    emoji === e ? 'bg-primary-100 ring-2 ring-primary-400 shadow-sm' : 'hover:bg-gray-100'
                  )}>
                  {e}
                </button>
              ))}
            </div>
          </div>

          {/* Name */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Kanalname *</label>
            <div className="relative mt-1.5">
              <Hash className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400 pointer-events-none" />
              <input
                value={name}
                onChange={e => setName(e.target.value)}
                maxLength={40}
                placeholder="mein-kanal"
                className="w-full pl-8 pr-3 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 bg-gray-50 placeholder-gray-400"
              />
            </div>
          </div>

          {/* Description */}
          <div>
            <label className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Beschreibung (optional)</label>
            <input
              value={description}
              onChange={e => setDescription(e.target.value)}
              maxLength={120}
              placeholder="Worum geht es in diesem Kanal?"
              className="mt-1.5 w-full px-3 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 bg-gray-50 placeholder-gray-400"
            />
          </div>

          <button
            type="button"
            onClick={handleCreate}
            disabled={!name.trim() || loading}
            className="w-full py-3 bg-gradient-to-br from-primary-500 to-primary-600 text-white text-sm font-semibold rounded-xl shadow-sm hover:from-primary-600 hover:to-primary-700 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
          >
            {loading ? <><Loader2 className="w-4 h-4 animate-spin" /> Erstelle…</> : 'Kanal erstellen'}
          </button>
        </div>
      </div>
    </div>
  )
}
