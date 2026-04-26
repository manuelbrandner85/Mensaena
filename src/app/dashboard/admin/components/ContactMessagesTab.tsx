'use client'

import { useCallback, useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Mail, Loader2, RefreshCw, CheckCircle2, Circle, ExternalLink } from 'lucide-react'

interface ContactMessage {
  id: string
  name: string
  email: string
  subject: string
  message: string
  read: boolean
  created_at: string
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString('de-DE', {
      day: '2-digit', month: '2-digit', year: '2-digit',
      hour: '2-digit', minute: '2-digit',
    })
  } catch { return iso }
}

export default function ContactMessagesTab() {
  const [messages, setMessages] = useState<ContactMessage[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'unread' | 'read'>('all')
  const [expanded, setExpanded] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data, error } = await supabase
      .from('contact_messages')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200)
    if (error) {
      console.error('[ContactMessagesTab] load failed:', error.message)
      setMessages([])
    } else {
      setMessages((data ?? []) as ContactMessage[])
    }
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  async function toggleRead(id: string, current: boolean) {
    const supabase = createClient()
    await supabase.from('contact_messages').update({ read: !current }).eq('id', id)
    setMessages(prev => prev.map(m => m.id === id ? { ...m, read: !current } : m))
  }

  const filtered = filter === 'all'
    ? messages
    : messages.filter(m => filter === 'unread' ? !m.read : m.read)

  const unreadCount = messages.filter(m => !m.read).length

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <div className="grid grid-cols-3 gap-1 bg-stone-100 rounded-xl p-1 text-xs font-medium">
            {(['all', 'unread', 'read'] as const).map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-lg transition-colors ${
                  filter === f ? 'bg-white shadow-sm text-ink-800' : 'text-ink-500 hover:text-ink-700'
                }`}
              >
                {f === 'all' ? `Alle (${messages.length})` : f === 'unread' ? `Ungelesen (${unreadCount})` : 'Gelesen'}
              </button>
            ))}
          </div>
        </div>
        <button
          onClick={load}
          disabled={loading}
          className="flex items-center gap-1.5 text-xs text-ink-500 hover:text-ink-700 transition-colors"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          Aktualisieren
        </button>
      </div>

      {/* List */}
      {loading ? (
        <div className="flex justify-center py-16">
          <Loader2 className="w-6 h-6 animate-spin text-primary-500" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-ink-400">
          <Mail className="w-8 h-8 mx-auto mb-3 opacity-40" />
          <p className="text-sm">Keine Nachrichten</p>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(m => (
            <div
              key={m.id}
              className={`bg-white rounded-2xl border shadow-sm overflow-hidden transition-all ${
                m.read ? 'border-stone-100' : 'border-primary-200 bg-primary-50/30'
              }`}
            >
              <div
                className="flex items-start gap-3 p-4 cursor-pointer"
                onClick={() => setExpanded(expanded === m.id ? null : m.id)}
              >
                <button
                  onClick={e => { e.stopPropagation(); toggleRead(m.id, m.read) }}
                  className="flex-shrink-0 mt-0.5"
                  title={m.read ? 'Als ungelesen markieren' : 'Als gelesen markieren'}
                >
                  {m.read
                    ? <CheckCircle2 className="w-4 h-4 text-stone-300 hover:text-stone-400 transition-colors" />
                    : <Circle className="w-4 h-4 text-primary-500 hover:text-primary-600 transition-colors" />
                  }
                </button>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className={`text-sm font-semibold ${m.read ? 'text-ink-600' : 'text-ink-900'}`}>
                      {m.name}
                    </span>
                    <a
                      href={`mailto:${m.email}`}
                      onClick={e => e.stopPropagation()}
                      className="text-xs text-primary-600 hover:underline flex items-center gap-0.5"
                    >
                      {m.email}
                      <ExternalLink className="w-2.5 h-2.5" />
                    </a>
                    <span className="text-xs text-ink-400 ml-auto flex-shrink-0">{formatDate(m.created_at)}</span>
                  </div>
                  <p className={`text-xs mt-0.5 ${m.read ? 'text-ink-400' : 'text-ink-600 font-medium'}`}>
                    {m.subject}
                  </p>
                </div>
              </div>
              {expanded === m.id && (
                <div className="px-4 pb-4 pt-1 border-t border-stone-100">
                  <p className="text-sm text-ink-700 whitespace-pre-wrap leading-relaxed">{m.message}</p>
                  <a
                    href={`mailto:${m.email}?subject=Re: ${encodeURIComponent(m.subject)}`}
                    className="inline-flex items-center gap-1.5 mt-3 text-xs font-medium text-primary-600 hover:text-primary-700"
                  >
                    <Mail className="w-3 h-3" />
                    Antworten per E-Mail
                  </a>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
