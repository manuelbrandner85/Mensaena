'use client'

import { useEffect, useState, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { Filter, Search, Plus, MapPin, X, ChevronDown } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'

const TYPE_FILTERS = [
  { value: 'all',          label: 'Alle'               },
  { value: 'help_request', label: '🔴 Hilfe gesucht'   },
  { value: 'help_offer',   label: '🟢 Hilfe angeboten' },
  { value: 'rescue',       label: '🧡 Retter'          },
  { value: 'animal',       label: '🐾 Tiere'           },
  { value: 'housing',      label: '🏡 Wohnen'          },
  { value: 'supply',       label: '🌾 Versorgung'      },
  { value: 'crisis',       label: '🚨 Notfall'         },
  { value: 'mobility',     label: '🚗 Mobilität'       },
  { value: 'sharing',      label: '🔄 Teilen'          },
  { value: 'skill',        label: '⭐ Skills'          },
  { value: 'community',    label: '🗳️ Community'      },
  { value: 'knowledge',    label: '📚 Wissen'          },
]

const PAGE_SIZE = 20

export default function PostsPage() {
  const [posts, setPosts]         = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds]   = useState<string[]>([])
  const [userId, setUserId]       = useState<string>()
  const [loading, setLoading]     = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore, setHasMore]     = useState(true)
  const [filter, setFilter]       = useState('all')
  const [search, setSearch]       = useState('')
  const [searchInput, setSearchInput] = useState('')
  const [location, setLocation]   = useState('')
  const [locationInput, setLocationInput] = useState('')
  const [page, setPage]           = useState(0)
  const searchTimer = useRef<ReturnType<typeof setTimeout>>()

  const load = useCallback(async (reset = true) => {
    if (reset) {
      setLoading(true)
      setPage(0)
    } else {
      setLoadingMore(true)
    }

    const supabase = createClient()
    if (reset) {
      const { data: { user } } = await supabase.auth.getUser()
      if (user) {
        setUserId(user.id)
        const { data: saved } = await supabase.from('saved_posts').select('post_id').eq('user_id', user.id)
        setSavedIds((saved ?? []).map((s: { post_id: string }) => s.post_id))
      }
    }

    const currentPage = reset ? 0 : page + 1
    let q = supabase
      .from('posts')
      .select('*, profiles(name,avatar_url)')
      .eq('status', 'active')
      .order('urgency', { ascending: false })
      .order('created_at', { ascending: false })
      .range(currentPage * PAGE_SIZE, (currentPage + 1) * PAGE_SIZE - 1)

    if (filter !== 'all') q = q.eq('type', filter)
    if (search.trim()) q = q.or(`title.ilike.%${search}%,description.ilike.%${search}%`)
    if (location.trim()) q = q.ilike('location_text', `%${location}%`)

    const { data } = await q

    if (reset) {
      setPosts(data ?? [])
    } else {
      setPosts(prev => [...prev, ...(data ?? [])])
      setPage(currentPage)
    }
    setHasMore((data ?? []).length === PAGE_SIZE)
    setLoading(false)
    setLoadingMore(false)
  }, [filter, search, location, page])

  useEffect(() => { load(true) }, [filter, search, location])

  // Debounce search input
  const handleSearchChange = (val: string) => {
    setSearchInput(val)
    clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(() => setSearch(val), 400)
  }

  const handleLocationChange = (val: string) => {
    setLocationInput(val)
    clearTimeout(searchTimer.current)
    searchTimer.current = setTimeout(() => setLocation(val), 500)
  }

  const clearSearch = () => { setSearch(''); setSearchInput('') }
  const clearLocation = () => { setLocation(''); setLocationInput('') }

  return (
    <div className="max-w-5xl space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Alle Beiträge</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {!loading && `${posts.length}${hasMore ? '+' : ''} aktive Beiträge`}
          </p>
        </div>
        <Link href="/dashboard/create" className="btn-primary">
          <Plus className="w-4 h-4" />
          Neuer Beitrag
        </Link>
      </div>

      {/* Suche + Ort */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div className="relative">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            value={searchInput}
            onChange={e => handleSearchChange(e.target.value)}
            placeholder="Beiträge durchsuchen…"
            className="input pl-10 pr-9 w-full"
          />
          {searchInput && (
            <button onClick={clearSearch} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
        <div className="relative">
          <MapPin className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            value={locationInput}
            onChange={e => handleLocationChange(e.target.value)}
            placeholder="Ort / PLZ filtern…"
            className="input pl-10 pr-9 w-full"
          />
          {locationInput && (
            <button onClick={clearLocation} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {/* Aktive Filter-Chips */}
      {(search || location) && (
        <div className="flex flex-wrap gap-2 items-center">
          <span className="text-xs text-gray-500">Aktive Filter:</span>
          {search && (
            <span className="flex items-center gap-1 bg-primary-100 text-primary-700 px-2 py-1 rounded-full text-xs font-medium">
              🔍 {search} <button onClick={clearSearch}><X className="w-3 h-3" /></button>
            </span>
          )}
          {location && (
            <span className="flex items-center gap-1 bg-blue-100 text-blue-700 px-2 py-1 rounded-full text-xs font-medium">
              📍 {location} <button onClick={clearLocation}><X className="w-3 h-3" /></button>
            </span>
          )}
        </div>
      )}

      {/* Typ-Filter */}
      <div className="flex flex-wrap gap-2">
        {TYPE_FILTERS.map(f => (
          <button
            key={f.value}
            onClick={() => setFilter(f.value)}
            className={cn('px-3 py-1.5 rounded-xl text-xs font-medium border transition-all',
              filter === f.value
                ? 'bg-primary-600 text-white border-primary-600'
                : 'bg-white text-gray-600 border-warm-200 hover:border-primary-300'
            )}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Feed */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="bg-white rounded-2xl border border-warm-200 p-5 animate-pulse">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-xl bg-gray-100" />
                <div className="flex-1 space-y-1.5">
                  <div className="h-3.5 bg-gray-100 rounded w-3/4" />
                  <div className="h-3 bg-gray-100 rounded w-1/2" />
                </div>
              </div>
              <div className="space-y-2">
                <div className="h-3 bg-gray-100 rounded" />
                <div className="h-3 bg-gray-100 rounded w-5/6" />
              </div>
            </div>
          ))}
        </div>
      ) : posts.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-2xl border border-warm-200">
          <div className="text-4xl mb-3">🌿</div>
          <p className="font-semibold text-gray-700">Keine Beiträge gefunden</p>
          <p className="text-sm text-gray-500 mt-1 mb-4">Passe die Filter an oder erstelle einen neuen Beitrag</p>
          <div className="flex justify-center gap-3">
            {(search || location || filter !== 'all') && (
              <button onClick={() => { clearSearch(); clearLocation(); setFilter('all') }} className="btn-secondary text-sm">
                Filter zurücksetzen
              </button>
            )}
            <Link href="/dashboard/create" className="btn-primary text-sm">
              <Plus className="w-4 h-4" /> Beitrag erstellen
            </Link>
          </div>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {posts.map(p => (
              <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds}
                onSaveToggle={(id, s) => setSavedIds(prev => s ? [...prev, id] : prev.filter(x => x !== id))} />
            ))}
          </div>

          {/* Mehr laden */}
          {hasMore && (
            <div className="flex justify-center pt-2">
              <button
                onClick={() => load(false)}
                disabled={loadingMore}
                className="flex items-center gap-2 px-6 py-2.5 bg-white border border-warm-200 rounded-xl text-sm font-medium text-gray-700 hover:border-primary-300 hover:text-primary-700 transition-all disabled:opacity-50"
              >
                {loadingMore ? (
                  <><span className="w-4 h-4 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin" /> Laden…</>
                ) : (
                  <><ChevronDown className="w-4 h-4" /> Mehr laden</>
                )}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}
