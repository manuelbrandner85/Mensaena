'use client'
export const runtime = 'edge'

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

export default function MapPage() {
  const [posts, setPosts] = useState<Record<string, unknown>[]>([])

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('posts')
      .select('*')
      .eq('status', 'active')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .then(({ data }) => setPosts(data || []))
  }, [])

  return <MapView posts={posts} />
}
