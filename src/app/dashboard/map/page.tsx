'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
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

  useEffect(() => {
    const supabase = createClient()

    async function load() {
      // Try to get user profile location for geo-sorted results
      const { data: { user } } = await supabase.auth.getUser()
      let lat: number | null = null
      let lng: number | null = null
      let radiusKm = 100

      if (user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude, radius_km')
          .eq('id', user.id)
          .single()
        if (profile?.latitude && profile?.longitude) {
          lat = profile.latitude
          lng = profile.longitude
          radiusKm = profile.radius_km ?? 100
        }
      }

      if (lat && lng) {
        // Use get_nearby_posts RPC for geo-sorted results
        const { data: rpcData, error } = await supabase.rpc('get_nearby_posts', {
          p_lat: lat,
          p_lng: lng,
          p_radius_km: radiusKm,
          p_limit: 200,
        } as any)

        if (!error && rpcData) {
          setPosts(rpcData as Record<string, unknown>[])
          return
        }
      }

      // Fallback: direct query
      const data = await fallbackMapQuery(supabase)
      setPosts(data)
    }

    load()
  }, [])

  return <MapView posts={posts} />
}
