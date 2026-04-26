'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { Search, Plus, X, LayoutDashboard } from 'lucide-react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import type { User } from '@supabase/supabase-js'
import { createClient } from '@/lib/supabase/client'
import NotificationBell from '@/components/navigation/NotificationBell'
import { cn } from '@/lib/utils'

interface SearchResult {
  id: string
  kind: 'post' | 'user' | 'channel'
  title: string
  subtitle?: string
  url: string
  emoji?: string
}

interface DashboardTopbarProps {
  user: User
  onOpenWidgetSettings?: () => void
}

export default function DashboardTopbar({ user, onOpenWidgetSettings }: DashboardTopbarProps) {
  const router = useRouter()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [searching, setSearching] = useState(false)
  const [showResults, setShowResults] = useState(false)
  const searchRef = useRef<HTMLDivElement>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const displayName = user.user_metadata?.full_name || user.email?.split('@')[0] || 'Nutzer'
  const initials = displayName
    .split(' ')
    .map((n: string) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)

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
      id: p.id,
      kind: 'post',
      title: p.title,
      subtitle: p.location_text || p.type,
      url: `/dashboard/posts/${p.id}`,
      emoji: '📄',
    }))
    const userResults: SearchResult[] = (usersRes.data ?? []).map((u) => ({
      id: u.id,
      kind: 'user',
      title: u.name || u.nickname || 'Nutzer',
      subtitle: u.location || undefined,
      url: `/dashboard/profile`,
      emoji: '👤',
    }))
    const channelResults: SearchResult[] = (channelsRes.data ?? []).map((c) => ({
      id: c.id,
      kind: 'channel',
      title: c.name,
      subtitle: c.description || undefined,
      url: `/dashboard/chat`,
      emoji: c.emoji || '#',
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

  // Close on outside click
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
    <header className="hidden lg:flex items-center justify-between h-16 px-8 bg-white border-b border-warm-200 sticky top-0 z-20 shadow-soft">
      {/* Global Search */}
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
        />
        {query && (
          <button
            onClick={() => { setQuery(''); setResults([]); setShowResults(false) }}
            className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}

        {/* Search Dropdown */}
        {showResults && (
          <div className="absolute top-full left-0 right-0 mt-1.5 bg-white rounded-2xl border border-warm-200 shadow-2xl overflow-hidden z-50">
            {searching ? (
              <div className="py-4 text-center text-sm text-gray-400">Suche…</div>
            ) : results.length === 0 ? (
              <div className="py-4 text-center text-sm text-gray-400">Keine Treffer für „{query}"</div>
            ) : (
              <>
                {['post', 'user', 'channel'].map((kind) => {
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

      {/* Right Actions */}
      <div className="flex items-center gap-3">
        {/* Widget settings */}
        {onOpenWidgetSettings && (
          <button
            onClick={onOpenWidgetSettings}
            className="flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 hover:bg-stone-100 rounded-xl transition-colors border border-warm-200"
            title="Widgets anpassen"
          >
            <LayoutDashboard className="w-4 h-4" />
            <span className="hidden xl:inline">Widgets</span>
          </button>
        )}

        {/* Quick Create */}
        <Link
          href="/dashboard/create"
          className="flex items-center gap-2 px-4 py-2 text-white text-sm font-medium rounded-xl transition-all duration-200 hover:shadow-md hover:-translate-y-0.5 active:scale-95"
          style={{ background: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)' }}
        >
          <Plus className="w-4 h-4" />
          Beitrag erstellen
        </Link>

        {/* Notification Bell */}
        <NotificationBell userId={user.id} />

        {/* User Avatar */}
        <Link href="/dashboard/profile" className="flex items-center gap-2.5 pl-2 border-l border-warm-200">
          <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shadow-sm"
            style={{ background: 'linear-gradient(135deg, #38c4c0 0%, #38a169 100%)' }}>
            {initials}
          </div>
          <div className="hidden xl:block">
            <p className="text-sm font-medium text-gray-900 leading-none">{displayName}</p>
            <p className="text-xs text-gray-500 mt-0.5">{user.email}</p>
          </div>
        </Link>
      </div>
    </header>
  )
}
