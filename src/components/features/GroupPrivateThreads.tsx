'use client'

import { useCallback, useEffect, useState } from 'react'
import Link from 'next/link'
import { MessageCircle, Plus, Loader2, Lock } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

interface Thread {
  id: string
  title: string | null
  created_at: string
  updated_at: string | null
}

interface Props {
  groupId: string
  currentUserId?: string
  isMember: boolean
}

/**
 * GroupPrivateThreads – Private Unterhaltungen pro Gruppe.
 * Nutzt die bestehende `conversations`-Tabelle mit der neuen Spalte `group_id`.
 * Mitglieder können neue Threads starten; nur Gruppenmitglieder sehen sie.
 */
export default function GroupPrivateThreads({ groupId, currentUserId, isMember }: Props) {
  const [threads, setThreads] = useState<Thread[]>([])
  const [loading, setLoading] = useState(true)
  const [creating, setCreating] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [title, setTitle] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data, error } = await supabase
      .from('conversations')
      .select('id, title, created_at, updated_at')
      .eq('group_id', groupId)
      .eq('type', 'group_thread')
      .order('updated_at', { ascending: false })
      .limit(30)
    if (error) {
      console.error('group threads load failed:', error.message)
      setThreads([])
    } else {
      setThreads(data ?? [])
    }
    setLoading(false)
  }, [groupId])

  useEffect(() => { load() }, [load])

  const create = async () => {
    if (!currentUserId) { toast.error('Nicht angemeldet'); return }
    const t = title.trim().slice(0, 120)
    if (t.length < 3) { toast.error('Titel zu kurz'); return }
    setCreating(true)
    const supabase = createClient()

    // 1) Create conversation
    const { data: conv, error: convErr } = await supabase
      .from('conversations')
      .insert({ type: 'group_thread', title: t, group_id: groupId })
      .select('id')
      .single()
    if (convErr || !conv) {
      setCreating(false)
      handleSupabaseError(convErr)
      return
    }

    // 2) Add creator as member
    const { error: memErr } = await supabase
      .from('conversation_members')
      .insert({ conversation_id: conv.id, user_id: currentUserId, role: 'admin' })
    setCreating(false)
    if (handleSupabaseError(memErr)) return

    toast.success('Thread erstellt')
    setTitle(''); setShowNew(false)
    load()
  }

  if (!isMember) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-4 text-center">
        <Lock className="w-5 h-5 mx-auto text-gray-300 mb-2" />
        <p className="text-xs text-gray-500">Nur Mitglieder können private Threads sehen.</p>
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <MessageCircle className="w-4 h-4 text-primary-600" />
          <h3 className="text-sm font-bold text-gray-900">Private Threads</h3>
        </div>
        {!showNew && (
          <button
            type="button"
            onClick={() => setShowNew(true)}
            className="inline-flex items-center gap-1 h-8 px-2.5 text-[11px] font-semibold border border-primary-200 text-primary-700 rounded-lg hover:bg-primary-50 transition-colors"
          >
            <Plus className="w-3 h-3" /> Neu
          </button>
        )}
      </div>

      {showNew && (
        <div className="mb-3 border border-primary-100 rounded-lg p-3 bg-primary-50/40">
          <input
            type="text"
            value={title}
            onChange={e => setTitle(e.target.value)}
            placeholder='Thread-Titel (z.B. „Gartenfest-Planung")'
            maxLength={120}
            className="w-full h-10 px-3 border border-gray-200 rounded-lg text-sm"
            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); create() } }}
          />
          <div className="mt-2 flex justify-end gap-2">
            <button
              type="button"
              onClick={() => { setShowNew(false); setTitle('') }}
              className="h-8 px-3 text-xs text-gray-600 rounded-lg hover:bg-gray-100"
            >
              Abbrechen
            </button>
            <button
              type="button"
              disabled={creating || title.trim().length < 3}
              onClick={create}
              className="inline-flex items-center gap-1 h-8 px-3 text-xs font-semibold bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-60"
            >
              {creating && <Loader2 className="w-3 h-3 animate-spin" />}
              Erstellen
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <p className="text-xs text-gray-400 py-4 text-center">Lade …</p>
      ) : threads.length === 0 ? (
        <p className="text-xs text-gray-400 py-4 text-center">Noch keine Threads.</p>
      ) : (
        <ul className="space-y-1">
          {threads.map(t => (
            <li key={t.id}>
              <Link
                href={`/dashboard/chat?conversation=${t.id}`}
                className="flex items-center justify-between px-3 py-2 rounded-lg hover:bg-stone-50 transition-colors"
              >
                <span className="text-sm font-medium text-gray-800 truncate">{t.title ?? 'Unbenannter Thread'}</span>
                <span className="text-[11px] text-gray-400 flex-shrink-0 ml-2">
                  {new Date(t.updated_at || t.created_at).toLocaleDateString('de-DE')}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
