'use client'

import { useEffect, useState, useCallback, useRef, Suspense } from 'react'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import { Filter, Search, Plus, MapPin, X, ChevronDown, Tag, SlidersHorizontal, Navigation } from 'lucide-react'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { cn } from '@/lib/utils'

// Only valid DB types
const TYPE_FILTERS = [
  { value: 'all',       label: 'Alle'              },
  { value: 'rescue',    label: '🧡 Hilfe/Retten'  },
  { value: 'animal',    label: '🐾 Tiere'          },
  { value: 'housing',   label: '🏡 Wohnen'         },
  { value: 'supply',    label: '🌾 Versorgung'     },
  { value: 'crisis',    label: '🚨 Notfall'        },
  { value: 'mobility',  label: '🚗 Mobilität'      },
  { value: 'sharing',   label: '🔄 Teilen/Skills'  },
  { value: 'community', label: '🗳️ Community'     },
]

const POPULAR_TAGS = ['#hilfe', '#notfall', '#tauschen', '#wien', '#graz', '#österreich', '#lebensmittel', '#wohnen', '#transport']
const RADIUS_OPTIONS = [5, 10, 25, 50, 100]
const PAGE_SIZE = 20

function PostsContent() {
  const searchParams = useSearchParams()
  const initialQuery = searchParams.get('q') ?? ''

  const [posts, setPosts]         = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds]   = useState<string[]>([])
  const [userId, setUserId]       = useState<string>()
  const [loading, setLoading]     = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [hasMore, setHasMore]     = useState(true)
  const [filter, setFilter]       = useState('all')
  const [search, setSearch]       = useState(initialQuery)
  const [searchInput, setSearchInput] = useState(initialQuery)
  const [location, setLocation]   = useState('')
  const [locationInput, setLocationInput] = useState('')
  const [page, setPage]           = useState(0)
  const [activeTag, setActiveTag] = useState('')
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [radiusKm, setRadiusKm]   = useState<number | null>(null)
  const [userLat, setUserLat]     = useState<number | null>(null)
  const [userLng, setUserLng]     = useState<number | null>(null)
  const [gettingLocation, setGettingLocation] = useState(false)
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
      .select('*, profiles(name,avatar_url), tags')
      .eq('status', 'active')
      .order('urgency', { ascending: false })
      .order('created_at', { ascending: false })
      .range(currentPage * PAGE_SIZE, (currentPage + 1) * PAGE_SIZE - 1)

    if (filter !== 'all') q = q.eq('type', filter)
    if (search.trim()) q = q.or(`title.ilike.%${search}%,description.ilike.%${search}%`)
    if (location.trim()) q = q.ilike('location_text', `%${location}%`)
    if (activeTag) q = q.contains('tags', [activeTag.replace('#', '')])

    const { data } = await q

    let filteredData = data ?? []

    // Radius filter (client-side using distance_km - if posts have lat/lng)
    if (radiusKm && userLat !== null && userLng !== null) {
      filteredData = filteredData.filter((p: PostCardPost & { lat?: number; lng?: number }) => {
        if (!p.lat || !p.lng) return true // keep posts without geo
        const R = 6371
        const dLat = ((p.lat - userLat) * Math.PI) / 180
        const dLon = ((p.lng - userLng) * Math.PI) / 180
        const a = Math.sin(dLat / 2) ** 2 +
          Math.cos((userLat * Math.PI) / 180) * Math.cos((p.lat * Math.PI) / 180) * Math.sin(dLon / 2) ** 2
        const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return dist <= radiusKm
      })
    }

    if (reset) {
      setPosts(filteredData)
    } else {
      setPosts(prev => [...prev, ...filteredData])
      setPage(currentPage)
    }
    setHasMore((data ?? []).length === PAGE_SIZE)
    setLoading(false)
    setLoadingMore(false)
  }, [filter, search, location, page, activeTag, radiusKm, userLat, userLng])

  useEffect(() => { load(true) }, [filter, search, location, activeTag, radiusKm, userLat, userLng])

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

  const handleGetLocation = () => {
    if (!navigator.geolocation) return
    setGettingLocation(true)
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLat(pos.coords.latitude)
        setUserLng(pos.coords.longitude)
        setGettingLocation(false)
        if (!radiusKm) setRadiusKm(25)
      },
      () => {
        setGettingLocation(false)
      }
    )
  }

  const clearRadius = () => { setRadiusKm(null); setUserLat(null); setUserLng(null) }

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
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowAdvanced(s => !s)}
            className={cn('flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm border transition-all',
              showAdvanced ? 'bg-primary-50 text-primary-700 border-primary-300' : 'bg-white text-gray-600 border-warm-200 hover:border-primary-200'
            )}
          >
            <SlidersHorizontal className="w-4 h-4" />
            Filter
          </button>
          <Link href="/dashboard/create" className="btn-primary">
            <Plus className="w-4 h-4" />
            Neuer Beitrag
          </Link>
        </div>
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

      {/* Advanced Filters */}
      {showAdvanced && (
        <div className="bg-white rounded-2xl border border-warm-200 p-4 space-y-4">
          {/* Radius filter */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-sm font-semibold text-gray-700 flex items-center gap-1.5">
                <Navigation className="w-4 h-4 text-primary-500" /> Radius-Filter
              </label>
              {(userLat || radiusKm) && (
                <button onClick={clearRadius} className="text-xs text-red-500 hover:underline">Zurücksetzen</button>
              )}
            </div>
            <div className="flex flex-wrap gap-2 items-center">
              {!userLat ? (
                <button
                  onClick={handleGetLocation}
                  disabled={gettingLocation}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm border border-primary-300 bg-primary-50 text-primary-700 hover:bg-primary-100 transition-all"
                >
                  {gettingLocation
                    ? <span className="w-4 h-4 border-2 border-primary-300 border-t-primary-600 rounded-full animate-spin" />
                    : <Navigation className="w-4 h-4" />}
                  Meinen Standort verwenden
                </button>
              ) : (
                <>
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <Navigation className="w-3 h-3" /> Standort erkannt
                  </span>
                  {RADIUS_OPTIONS.map(km => (
                    <button
                      key={km}
                      onClick={() => setRadiusKm(radiusKm === km ? null : km)}
                      className={cn('px-3 py-1.5 rounded-xl text-xs font-medium border transition-all',
                        radiusKm === km
                          ? 'bg-primary-600 text-white border-primary-600'
                          : 'bg-white text-gray-600 border-warm-200 hover:border-primary-300'
                      )}
                    >
                      {km} km
                    </button>
                  ))}
                </>
              )}
            </div>
          </div>

          {/* Tag filter */}
          <div>
            <label className="text-sm font-semibold text-gray-700 flex items-center gap-1.5 mb-2">
              <Tag className="w-4 h-4 text-primary-500" /> Nach Tags filtern
            </label>
            <div className="flex flex-wrap gap-2">
              {POPULAR_TAGS.map(tag => (
                <button
                  key={tag}
                  onClick={() => setActiveTag(activeTag === tag ? '' : tag)}
                  className={cn('px-3 py-1.5 rounded-xl text-xs font-medium border transition-all',
                    activeTag === tag
                      ? 'bg-violet-600 text-white border-violet-600'
                      : 'bg-white text-gray-600 border-warm-200 hover:border-violet-300 hover:text-violet-700'
                  )}
                >
                  {tag}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Aktive Filter-Chips */}
      {(search || location || activeTag || radiusKm) && (
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
          {activeTag && (
            <span className="flex items-center gap-1 bg-violet-100 text-violet-700 px-2 py-1 rounded-full text-xs font-medium">
              🏷️ {activeTag} <button onClick={() => setActiveTag('')}><X className="w-3 h-3" /></button>
            </span>
          )}
          {radiusKm && (
            <span className="flex items-center gap-1 bg-green-100 text-green-700 px-2 py-1 rounded-full text-xs font-medium">
              📡 {radiusKm} km <button onClick={clearRadius}><X className="w-3 h-3" /></button>
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
            {(search || location || filter !== 'all' || activeTag || radiusKm) && (
              <button onClick={() => { clearSearch(); clearLocation(); setFilter('all'); setActiveTag(''); clearRadius() }} className="btn-secondary text-sm">
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

export default function PostsPage() {
  return (
    <Suspense fallback={<div className="flex justify-center py-16"><div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" /></div>}>
      <PostsContent />
    </Suspense>
  )
}
