'use client'

import { useEffect, useState } from 'react'
import { Heart } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatRelativeTime } from '@/lib/utils'

interface ThanksRow {
  id: string
  emoji: string
  message: string | null
  created_at: string
  from_user_id: string
  profiles?: { name: string | null; avatar_url: string | null } | null
}

interface ThanksReceivedProps {
  userId: string
}

export default function ThanksReceived({ userId }: ThanksReceivedProps) {
  const [count, setCount] = useState<number | null>(null)
  const [latest, setLatest] = useState<ThanksRow[]>([])

  useEffect(() => {
    let cancelled = false
    const supabase = createClient()

    ;(async () => {
      const [countRes, listRes] = await Promise.all([
        supabase.from('thanks')
          .select('*', { count: 'exact', head: true })
          .eq('to_user_id', userId),
        supabase.from('thanks')
          .select('id, emoji, message, created_at, from_user_id, profiles:profiles!thanks_from_user_id_fkey(name, avatar_url)')
          .eq('to_user_id', userId)
          .order('created_at', { ascending: false })
          .limit(3),
      ])
      if (cancelled) return
      setCount(countRes.count ?? 0)
      setLatest(((listRes.data as unknown) as ThanksRow[]) ?? [])
    })()

    return () => { cancelled = true }
  }, [userId])

  if (count === null) {
    return <div className="rounded-2xl bg-stone-100 animate-pulse h-32" />
  }

  if (count === 0) return null

  return (
    <div className="bg-white rounded-2xl border border-stone-200 shadow-soft p-5">
      <div className="flex items-center gap-2 mb-3">
        <div className="w-8 h-8 rounded-lg bg-rose-100 flex items-center justify-center flex-shrink-0">
          <Heart className="w-4 h-4 text-rose-600 fill-rose-200" />
        </div>
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-ink-500">
            Wertschätzung
          </p>
          <p className="text-base font-bold text-ink-800 leading-tight">
            Du hast {count} {count === 1 ? 'Danke' : 'Dankes'} erhalten
          </p>
        </div>
      </div>

      {latest.length > 0 && (
        <ul className="space-y-2 mt-3">
          {latest.map((t) => (
            <li key={t.id} className="flex items-start gap-2.5 text-sm">
              <span className="text-xl leading-none flex-shrink-0 mt-0.5" aria-hidden>
                {t.emoji}
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-ink-700 truncate">
                  {t.profiles?.name ?? 'Ein Nachbar'}
                </p>
                {t.message && (
                  <p className="text-xs text-ink-500 line-clamp-2 leading-relaxed">
                    „{t.message}"
                  </p>
                )}
                <p className="text-[10px] text-ink-400 mt-0.5">
                  {formatRelativeTime(t.created_at)}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
