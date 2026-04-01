'use client'
export const runtime = 'edge'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { Filter, Search, Plus } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'

const TYPE_FILTERS = [
  { value: 'all',          label: 'Alle'         },
  { value: 'help_request', label: '🔴 Hilfe gesucht' },
  { value: 'help_offer',   label: '🟢 Hilfe angeboten' },
  { value: 'rescue',       label: '🧡 Retter'     },
  { value: 'animal',       label: '🐾 Tiere'      },
  { value: 'housing',      label: '🏡 Wohnen'     },
  { value: 'supply',       label: '🌾 Versorgung' },
  { value: 'crisis',       label: '🚨 Notfall'    },
]

export default function PostsPage() {
  const [posts, setPosts]       = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [userId, setUserId]     = useState<string>()
  const [loading, setLoading]   = useState(true)
  const [filter, setFilter]     = useState('all')
  const [search, setSearch]     = useState('')

  const load = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) setUserId(user.id)

    let q = supabase.from('posts').select('*, profiles(name,avatar_url)')
      .eq('status', 'active')
      .order('urgency', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(50)

    if (filter !== 'all') q = q.eq('type', filter)

    const { data } = await q
    setPosts(data ?? [])

    if (user) {
      const { data: saved } = await supabase.from('saved_posts').select('post_id').eq('user_id', user.id)
      setSavedIds((saved ?? []).map((s:{post_id:string}) => s.post_id))
    }
    setLoading(false)
  }, [filter])

  useEffect(() => { load() }, [load])

  const filtered = posts.filter(p =>
    !search ||
    p.title.toLowerCase().includes(search.toLowerCase()) ||
    p.description?.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="max-w-5xl space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Alle Beiträge</h1>
          <p className="text-sm text-gray-500 mt-0.5">{filtered.length} aktive Einträge in der Community</p>
        </div>
        <Link href="/dashboard/create" className="btn-primary">
          <Plus className="w-4 h-4" />
          Neuer Beitrag
        </Link>
      </div>

      {/* Suche */}
      <div className="relative">
        <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Beiträge durchsuchen…"
          className="input pl-10 w-full" />
      </div>

      {/* Filter */}
      <div className="flex flex-wrap gap-2">
        {TYPE_FILTERS.map(f => (
          <button key={f.value} onClick={() => setFilter(f.value)}
            className={cn('px-3 py-1.5 rounded-xl text-xs font-medium border transition-all',
              filter === f.value
                ? 'bg-primary-600 text-white border-primary-600'
                : 'bg-white text-gray-600 border-warm-200 hover:border-primary-300')}>
            {f.label}
          </button>
        ))}
      </div>

      {/* Feed */}
      {loading ? (
        <div className="flex justify-center py-16">
          <div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-warm-200">
          <div className="text-4xl mb-3">🌿</div>
          <p className="font-semibold text-gray-700">Keine Beiträge gefunden</p>
          <p className="text-sm text-gray-500 mt-1 mb-4">Passe die Filter an oder erstelle einen neuen Beitrag</p>
          <Link href="/dashboard/create" className="btn-primary">
            <Plus className="w-4 h-4" /> Beitrag erstellen
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map(p => (
            <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds}
              onSaveToggle={(id,s) => setSavedIds(prev => s ? [...prev,id] : prev.filter(x=>x!==id))} />
          ))}
        </div>
      )}
    </div>
  )
}
