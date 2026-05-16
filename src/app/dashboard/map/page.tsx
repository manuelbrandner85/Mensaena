'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { Target } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import CinemaMapOverlay from '@/components/cinema/ui/CinemaMapOverlay'

// Leaflet benötigt ssr: false wegen window-Zugriff
const MapView = dynamic(() => import('@/components/map/MapView'), {
  ssr: false,
  loading: () => (
    <div
      className="card-depth flex items-center justify-center h-[520px] overflow-hidden relative rounded-2xl"
      style={{ background: 'linear-gradient(180deg, #0F1628 0%, #0A0F1C 100%)' }}
      role="status"
      aria-label="Karte wird geladen"
    >
      {/* Animated grid */}
      <div
        className="absolute inset-0 pointer-events-none opacity-20"
        style={{
          backgroundImage:
            'linear-gradient(rgba(245,158,11,0.15) 1px, transparent 1px), linear-gradient(90deg, rgba(245,158,11,0.15) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
          maskImage: 'radial-gradient(ellipse 60% 60% at 50% 50%, black 30%, transparent 100%)',
          WebkitMaskImage: 'radial-gradient(ellipse 60% 60% at 50% 50%, black 30%, transparent 100%)',
          animation: 'gridScan 12s ease-in-out infinite',
        }}
        aria-hidden="true"
      />
      {/* Drifting lantern particles */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden" aria-hidden="true">
        {[
          { top: '22%', left: '18%', size: 180, delay: '0s'   },
          { top: '38%', left: '72%', size: 160, delay: '2s'   },
          { top: '68%', left: '32%', size: 220, delay: '1s'   },
          { top: '52%', left: '58%', size: 200, delay: '3.5s' },
        ].map((l, i) => (
          <div
            key={i}
            className="absolute rounded-full"
            style={{
              top: l.top,
              left: l.left,
              width: l.size,
              height: l.size,
              background: 'radial-gradient(circle, rgba(245,158,11,0.10) 0%, transparent 70%)',
              animation: `lanternDrift 14s ease-in-out ${l.delay} infinite`,
              filter: 'blur(2px)',
              transform: 'translate(-50%, -50%)',
            }}
          />
        ))}
      </div>
      {/* Center primary glow */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '50%', left: '50%',
          width: '50vw', height: '50vw',
          maxWidth: '500px', maxHeight: '500px',
          transform: 'translate(-50%, -50%)',
          background: 'radial-gradient(circle, rgba(30,170,166,0.18) 0%, transparent 60%)',
          filter: 'blur(40px)',
        }}
        aria-hidden="true"
      />
      <div className="relative text-center z-10">
        <div className="relative w-14 h-14 mx-auto mb-4">
          <div className="absolute inset-0 border-[3px] border-mn-bronze/20 border-t-mn-bronze rounded-full animate-spin" />
          <div
            className="absolute inset-2 border-[2px] border-mn-teal-soft/15 border-b-mn-teal-soft rounded-full"
            style={{ animation: 'spin 1.6s linear reverse infinite' }}
          />
        </div>
        <p className="text-mn-ink-soft text-sm font-medium tracking-wide">Karte wird geladen…</p>
        <p className="text-mn-mute text-xs mt-1.5">Nachbarschaft wird vernetzt</p>
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
  // Plus iOS safe-area-inset-bottom (notch handling)
  // Desktop: auto height (scrollable dashboard layout)
  return (
    <div className="flex flex-col gap-2 h-[calc(100dvh-140px-env(safe-area-inset-bottom,0px))] md:h-auto">
      {userLoc && (
        <div className="relative flex items-center gap-3 p-3 pt-4 rounded-2xl bg-mn-elevated/90 border border-white/5 shadow-cinema-card backdrop-blur overflow-hidden flex-shrink-0">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <Target className="relative w-4 h-4 text-mn-bronze flex-shrink-0 float-idle" />
          <label htmlFor="radius-slider" className="relative text-xs font-medium text-mn-ink-soft whitespace-nowrap">
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
            className="relative flex-1 accent-mn-bronze"
            aria-label="Radius in Kilometern"
          />
          <span className="relative display-numeral text-sm font-bold text-mn-bronze tabular-nums min-w-[60px] text-right">
            {radiusKm} km
          </span>
          {loading && (
            <div className="relative w-4 h-4 border-2 border-mn-bronze/30 border-t-transparent rounded-full animate-spin" />
          )}
          <span className="relative display-numeral text-[11px] text-mn-mute whitespace-nowrap hidden sm:inline tabular-nums">
            · {posts.length} Beiträge
          </span>
        </div>
      )}
      {!initReady ? (
        <div className="flex-1 flex items-center justify-center bg-mn-surface rounded-2xl">
          <div className="text-center">
            <div className="w-10 h-10 border-4 border-mn-bronze/30 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-mn-mute text-sm">Standort wird geladen…</p>
          </div>
        </div>
      ) : (
        <div className="relative flex-1 rounded-2xl overflow-hidden border border-white/5 shadow-cinema-card">
          <MapView
            posts={posts}
            initialCenter={userLoc ? [userLoc.lat, userLoc.lng] : null}
          />
          <CinemaMapOverlay />
        </div>
      )}
    </div>
  )
}
