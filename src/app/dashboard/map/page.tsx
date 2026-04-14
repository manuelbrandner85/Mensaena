'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { Target } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

// Leaflet benötigt ssr: false wegen window-Zugriff
const MapView = dynamic(() => import('@/components/map/MapView'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-[520px] bg-gray-50 rounded-xl">
      <div className="text-center">
        <div className="w-10 h-10 border-4 border-primary-400 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
        <p className="text-gray-500 text-sm">Karte wird geladen…</p>
      </div>
    </div>
  ),
})

// Fallback: direct query when RPC unavailable
async function fallbackMapQuery(supabase: ReturnType<typeof createClient>) {
  const { data } = await supabase
    .from('posts')
    .select('*, profiles(name, avatar_url)')
    .eq('status', 'active')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .order('created_at', { ascending: false })
    .limit(200)
  return data || []
}

export default function MapPage() {
  const [posts, setPosts] = useState<Record<string, unknown>[]>([])
  const [userLoc, setUserLoc] = useState<{ lat: number; lng: number } | null>(null)
  const [radiusKm, setRadiusKm] = useState(100)
  const [loading, setLoading] = useState(false)

  // Initial: get user location + preferred radius
  useEffect(() => {
    const supabase = createClient()
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude, radius_km')
          .eq('id', user.id)
          .single()
        if (profile?.latitude && profile?.longitude) {
          setUserLoc({ lat: profile.latitude, lng: profile.longitude })
          setRadiusKm(profile.radius_km ?? 100)
          return
        }
      }
      // No location → load fallback
      const data = await fallbackMapQuery(supabase)
      setPosts(data)
    }
    init()
  }, [])

  // Re-fetch whenever radius or location changes
  const loadPosts = useCallback(async () => {
    if (!userLoc) return
    setLoading(true)
    const supabase = createClient()
    const { data: rpcData, error } = await supabase.rpc('get_nearby_posts', {
      p_lat: userLoc.lat,
      p_lng: userLoc.lng,
      p_radius_km: radiusKm,
      p_limit: 200,
    } as Record<string, unknown>)

    if (!error && rpcData) {
      setPosts(rpcData as Record<string, unknown>[])
    } else {
      const data = await fallbackMapQuery(supabase)
      setPosts(data)
    }
    setLoading(false)
  }, [userLoc, radiusKm])

  useEffect(() => { loadPosts() }, [loadPosts])

  return (
    <div className="space-y-3">
      {userLoc && (
        <div className="flex items-center gap-3 p-3 rounded-xl bg-white/90 border border-stone-200 shadow-sm backdrop-blur">
          <Target className="w-4 h-4 text-primary-600 flex-shrink-0" />
          <label htmlFor="radius-slider" className="text-xs font-medium text-ink-700 whitespace-nowrap">
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
            className="flex-1 accent-primary-600"
            aria-label="Radius in Kilometern"
          />
          <span className="text-sm font-bold text-primary-700 tabular-nums min-w-[60px] text-right">
            {radiusKm} km
          </span>
          {loading && (
            <div className="w-4 h-4 border-2 border-primary-400 border-t-transparent rounded-full animate-spin" />
          )}
          <span className="text-[11px] text-ink-400 whitespace-nowrap hidden sm:inline">
            · {posts.length} Beiträge
          </span>
        </div>
      )}
      <MapView posts={posts} />
    </div>
  )
}
