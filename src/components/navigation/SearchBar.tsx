'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { Search, X } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

interface SearchResult {
  id: string
  kind: 'post' | 'user' | 'channel'
  title: string
  subtitle?: string
  url: string
  emoji?: string
}

export default function SearchBar() {
  const router = useRouter()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [searching, setSearching] = useState(false)
  const [showResults, setShowResults] = useState(false)
  const searchRef = useRef<HTMLDivElement>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout>>()

  const doSearch = useCallback(async (q: string) => {
    if (!q.trim() || q.length < 2) { setResults([]); return }
    setSearching(true)
    const supabase = createClient()
    const term = q.trim()

    const [postsRes, usersRes, channelsRes] = await Promise.all([
      supabase.from('posts').select('id, title, type, location_text')
        .eq('status', 'active')
        .or(`title.ilike.%${term}%,description.ilike.%${term}%`)
        .limit(5),
      supabase.from('profiles').select('id, name, nickname, location')
        .or(`name.ilike.%${term}%,nickname.ilike.%${term}%`)
        .limit(4),
      supabase.from('chat_channels').select('id, name, description, emoji')
        .ilike('name', `%${term}%`)
        .limit(3),
    ])

    const postResults: SearchResult[] = (postsRes.data ?? []).map((p) => ({
      id: p.id, kind: 'post', title: p.title,
      subtitle: p.location_text || p.type, url: `/dashboard/posts/${p.id}`, emoji: '📄',
    }))
    const userResults: SearchResult[] = (usersRes.data ?? []).map((u) => ({
      id: u.id, kind: 'user', title: u.name || u.nickname || 'Nutzer',
      subtitle: u.location || undefined, url: `/dashboard/profile/${u.id}`, emoji: '👤',
    }))
    const channelResults: SearchResult[] = (channelsRes.data ?? []).map((c) => ({
      id: c.id, kind: 'channel', title: c.name,
      subtitle: c.description || undefined, url: `/dashboard/chat`, emoji: c.emoji || '#',
    }))

    setResults([...postResults, ...userResults, ...channelResults])
    setSearching(false)
    setShowResults(true)
  }, [])

  useEffect(() => {
    clearTimeout(timerRef.current)
    if (!query.trim()) { setResults([]); setShowResults(false); return }
    timerRef.current = setTimeout(() => doSearch(query), 350)
    return () => clearTimeout(timerRef.current)
  }, [query, doSearch])

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) setShowResults(false)
    }
    document.addEventListener('mousedown', h)
    return () => document.removeEventListener('mousedown', h)
  }, [])

  const handleSelect = (url: string) => {
    setShowResults(false)
    setQuery('')
    router.push(url)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && query.trim()) {
      setShowResults(false)
      router.push(`/dashboard/posts?q=${encodeURIComponent(query.trim())}`)
    }
    if (e.key === 'Escape') { setShowResults(false); setQuery('') }
  }

  return (
    <div ref={searchRef} className="relative w-72 xl:w-96">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => query.length >= 2 && setShowResults(true)}
        onKeyDown={handleKeyDown}
        placeholder="Beiträge, Nutzer, Kanäle suchen…"
        className="w-full pl-9 pr-8 py-2 text-sm bg-warm-50 border border-warm-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-400 focus:bg-white transition-all"
        aria-label="Suche"
      />
      {query && (
        <button
          onClick={() => { setQuery(''); setResults([]); setShowResults(false) }}
          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
        >
          <X className="w-3.5 h-3.5" />
        </button>
      )}

      {showResults && (
        <div className="absolute top-full left-0 right-0 mt-1.5 bg-white rounded-2xl border border-warm-200 shadow-2xl overflow-hidden z-50 animate-scale-in">
          {searching ? (
            <div className="py-4 text-center text-sm text-gray-400">Suche…</div>
          ) : results.length === 0 ? (
            <div className="py-4 text-center text-sm text-gray-400">Keine Treffer für „{query}"</div>
          ) : (
            <>
              {(['post', 'user', 'channel'] as const).map((kind) => {
                const group = results.filter((r) => r.kind === kind)
                if (!group.length) return null
                const label = kind === 'post' ? 'Beiträge' : kind === 'user' ? 'Nutzer' : 'Chat-Kanäle'
                return (
                  <div key={kind}>
                    <div className="px-4 py-1.5 bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                      {label}
                    </div>
                    {group.map((r) => (
                      <button
                        key={r.id}
                        onClick={() => handleSelect(r.url)}
                        className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-primary-50 text-left transition-colors"
                      >
                        <span className="text-lg flex-shrink-0">{r.emoji}</span>
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">{r.title}</p>
                          {r.subtitle && <p className="text-xs text-gray-500 truncate">{r.subtitle}</p>}
                        </div>
                      </button>
                    ))}
                  </div>
                )
              })}
              <div className="px-4 py-2 border-t border-warm-100">
                <button
                  onClick={() => handleSelect(`/dashboard/posts?q=${encodeURIComponent(query)}`)}
                  className="text-xs text-primary-600 hover:underline"
                >
                  Alle Ergebnisse für „{query}" anzeigen →
                </button>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}
