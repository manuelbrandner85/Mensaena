'use client'

import { useCallback, useEffect, useState } from 'react'
import { BookHeart, RefreshCw } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

interface Story {
  id: string
  title: string
  body: string
  author_name: string | null
  author_location: string | null
}

export default function SuccessStoryCard() {
  const [story, setStory]     = useState<Story | null | 'loading'>('loading')
  const [rotating, setRotating] = useState(false)

  const load = useCallback(async () => {
    const supabase = createClient()
    // Fetch a small pool and pick one at random client-side to avoid ORDER BY RANDOM() cost
    const { data } = await supabase
      .from('success_stories')
      .select('id, title, body, profiles!success_stories_author_id_fkey(name, location)')
      .eq('is_approved', true)
      .order('created_at', { ascending: false })
      .limit(20)

    if (!data || data.length === 0) {
      setStory(null)
      return
    }

    const row = data[Math.floor(Math.random() * data.length)]
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles as { name: string | null; location: string | null } | null

    setStory({
      id: row.id as string,
      title: row.title as string,
      body: row.body as string,
      author_name: profile?.name ?? null,
      author_location: profile?.location ?? null,
    })
  }, [])

  useEffect(() => { load() }, [load])

  const handleRefresh = async () => {
    setRotating(true)
    await load()
    setTimeout(() => setRotating(false), 600)
  }

  if (story === 'loading') {
    return <div className="rounded-2xl bg-stone-100 animate-pulse h-36" />
  }

  if (!story) return null

  const excerpt = story.body.length > 180 ? story.body.slice(0, 180).trimEnd() + '…' : story.body

  return (
    <div className="bg-white rounded-2xl border border-stone-200 shadow-soft p-5">
      {/* Header */}
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-primary-100 flex items-center justify-center flex-shrink-0">
            <BookHeart className="w-4 h-4 text-primary-600" />
          </div>
          <p className="text-xs font-semibold uppercase tracking-wider text-ink-500">
            Erfolgsgeschichte
          </p>
        </div>
        <button
          onClick={handleRefresh}
          title="Andere Geschichte"
          className="p-1.5 rounded-lg hover:bg-stone-100 text-stone-400 hover:text-stone-600 transition-colors"
        >
          <RefreshCw className={`w-3.5 h-3.5 transition-transform duration-500 ${rotating ? 'rotate-180' : ''}`} />
        </button>
      </div>

      {/* Story */}
      <p className="text-sm font-semibold text-ink-800 leading-tight mb-1.5">
        {story.title}
      </p>
      <p className="text-xs text-ink-600 leading-relaxed">
        „{excerpt}"
      </p>

      {/* Attribution */}
      {story.author_name && (
        <p className="mt-3 text-[10px] text-ink-400">
          — {story.author_name}{story.author_location ? `, ${story.author_location}` : ''}
        </p>
      )}
    </div>
  )
}
