'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { Target } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

// Leaflet benötigt ssr: false wegen window-Zugriff
const MapView = dynamic(() => import('@/components/map/MapView'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-[520px] bg-stone-50 rounded-xl">
      <div className="text-center">
        <div className="w-10 h-10 border-4 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
        <p className="text-ink-500 text-sm">Karte wird geladen…</p>
      </div>
    </div>
  ),
})

// Fallback: direct query when RPC unavailable
async function fallbackMapQuery(supabase: ReturnType<typeof createClient>) {
  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles(name, avatar_url)')
    .eq('status', 'active')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .order('created_at', { ascending: false })
    .limit(200)
  if (error) {
    console.error('map fallback query failed:', error.message)
    return []
  }
  return data || []
}

export default function MapPage() {
  const [posts, setPosts] = useState<Record<string, unknown>[]>([])
  const [userLoc, setUserLoc] = useState<{ lat: number; lng: number } | null>(null)
  const [radiusKm, setRadiusKm] = useState(100)
  const [loading, setLoading] = useState(false)
  const [initReady, setInitReady] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  // Initial: get user location + preferred radius
  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    const init = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (cancelled) return
        if (user) {
          const { data: profile, error: profileErr } = await supabase
            .from('profiles')
            .select('latitude, longitude, radius_km')
            .eq('id', user.id)
            .maybeSingle()
          if (cancelled) return
          if (profileErr) console.error('load map profile failed:', profileErr.message)
          if (profile?.latitude && profile?.longitude) {
            setUserLoc({ lat: profile.latitude, lng: profile.longitude })
            setRadiusKm(profile.radius_km ?? 100)
          }
        }
      } finally {
        if (!cancelled) setInitReady(true)
      }
    }
    init()
    return () => { cancelled = true }
  }, [])

  // Re-fetch whenever radius, location, or a realtime event bumps refreshKey
  const loadPosts = useCallback(async () => {
    const supabase = createClient()
    setLoading(true)
    if (userLoc) {
      const { data: rpcData, error } = await supabase.rpc('get_nearby_posts', {
        p_lat: userLoc.lat,
        p_lng: userLoc.lng,
        p_radius_km: radiusKm,
        p_limit: 200,
      } as Record<string, unknown>)

      if (!error && rpcData) {
        setPosts(rpcData as Record<string, unknown>[])
        setLoading(false)
        return
      }
    }
    const data = await fallbackMapQuery(supabase)
    setPosts(data)
    setLoading(false)
  }, [userLoc, radiusKm])

  useEffect(() => {
    if (!initReady) return
    loadPosts()
  }, [loadPosts, initReady, refreshKey])

  // ── Realtime: new/updated/deleted posts re-fetch the visible set ──
  // Debounced so a burst of DB events only triggers one refetch.
  useEffect(() => {
    const supabase = createClient()
    let debounce: ReturnType<typeof setTimeout> | null = null
    const bump = () => {
      if (debounce) clearTimeout(debounce)
      debounce = setTimeout(() => setRefreshKey(k => k + 1), 400)
    }
    const channel = supabase
      .channel('map:posts:realtime')
      .on(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        'postgres_changes' as any,
        { event: '*', schema: 'public', table: 'posts' },
        bump,
      )
      .subscribe()
    return () => {
      if (debounce) clearTimeout(debounce)
      supabase.removeChannel(channel)
    }
  }, [])

  // Mobile: 100dvh minus top-header (60px) minus bottom-nav (80px) = 140px
  // Desktop: auto height (scrollable dashboard layout)
  return (
    <div className="flex flex-col gap-2 h-[calc(100dvh-140px)] md:h-auto">
      {userLoc && (
        <div className="relative flex items-center gap-3 p-3 pt-4 rounded-2xl bg-white/90 border border-stone-200 shadow-soft backdrop-blur overflow-hidden flex-shrink-0">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <Target className="relative w-4 h-4 text-primary-600 flex-shrink-0 float-idle" />
          <label htmlFor="radius-slider" className="relative text-xs font-medium text-ink-700 whitespace-nowrap">
            Umkreis
          </label>
          <input
            id="radius-slider"
            type="range"
            min={5}
            max={200}
            step={5}
            value={radiusKm}
            onChange={e => setRadiusKm(Number(e.target.value))}
            className="relative flex-1 accent-primary-600"
            aria-label="Radius in Kilometern"
          />
          <span className="relative display-numeral text-sm font-bold text-primary-700 tabular-nums min-w-[60px] text-right">
            {radiusKm} km
          </span>
          {loading && (
            <div className="relative w-4 h-4 border-2 border-primary-400 border-t-transparent rounded-full animate-spin" />
          )}
          <span className="relative display-numeral text-[11px] text-ink-400 whitespace-nowrap hidden sm:inline tabular-nums">
            · {posts.length} Beiträge
          </span>
        </div>
      )}
      {!initReady ? (
        <div className="flex-1 flex items-center justify-center bg-warm-50 rounded-2xl">
          <div className="text-center">
            <div className="w-10 h-10 border-4 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-ink-500 text-sm">Standort wird geladen…</p>
          </div>
        </div>
      ) : (
        <MapView
          posts={posts}
          initialCenter={userLoc ? [userLoc.lat, userLoc.lng] : null}
        />
      )}
    </div>
  )
}
