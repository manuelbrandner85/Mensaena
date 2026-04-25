'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { MapPin } from 'lucide-react'
import { cn } from '@/lib/utils'
import { haversineKm, formatDistance } from '@/lib/api/routing'
import { createClient } from '@/lib/supabase/client'

interface PostDistanceBadgeProps {
  postLat: number
  postLon: number
  /** Optional: pass user location to skip the profile fetch */
  userLat?: number | null
  userLon?: number | null
  className?: string
}

// Module-level cache so we don't refetch on every badge mount
let _cachedUserLoc: { lat: number; lon: number } | null | 'loading' = null

function getDistanceColor(km: number): string {
  if (km < 2) return 'text-primary-700 bg-primary-50 border-primary-200'
  if (km < 5) return 'text-amber-700 bg-amber-50 border-amber-200'
  return 'text-stone-600 bg-stone-50 border-stone-200'
}

export default function PostDistanceBadge({
  postLat,
  postLon,
  userLat: propUserLat,
  userLon: propUserLon,
  className,
}: PostDistanceBadgeProps) {
  const router = useRouter()
  const [userLoc, setUserLoc] = useState<{ lat: number; lon: number } | null>(
    propUserLat != null && propUserLon != null
      ? { lat: propUserLat, lon: propUserLon }
      : (_cachedUserLoc !== 'loading' ? _cachedUserLoc : null),
  )

  useEffect(() => {
    // Props provided — no need to fetch
    if (propUserLat != null && propUserLon != null) {
      setUserLoc({ lat: propUserLat, lon: propUserLon })
      return
    }
    // Already cached
    if (_cachedUserLoc && _cachedUserLoc !== 'loading') {
      setUserLoc(_cachedUserLoc)
      return
    }
    // Already in-flight
    if (_cachedUserLoc === 'loading') return

    _cachedUserLoc = 'loading'
    let cancelled = false

    ;(async () => {
      try {
        // 1. Try browser geolocation first (most accurate + instant)
        if (navigator.geolocation) {
          await new Promise<void>((resolve) => {
            navigator.geolocation.getCurrentPosition(
              (pos) => {
                const loc = { lat: pos.coords.latitude, lon: pos.coords.longitude }
                _cachedUserLoc = loc
                if (!cancelled) setUserLoc(loc)
                resolve()
              },
              () => resolve(), // fallback to profile
              { timeout: 3000, maximumAge: 120000 },
            )
          })
          if (_cachedUserLoc && _cachedUserLoc !== 'loading') return
        }
        // 2. Fallback: Supabase profile
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) return
        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', user.id)
          .maybeSingle()
        if (!profile?.latitude || !profile?.longitude || cancelled) {
          _cachedUserLoc = null
          return
        }
        const loc = { lat: profile.latitude as number, lon: profile.longitude as number }
        _cachedUserLoc = loc
        if (!cancelled) setUserLoc(loc)
      } catch {
        _cachedUserLoc = null
      }
    })()

    return () => { cancelled = true }
  }, [propUserLat, propUserLon])

  if (!userLoc) return null

  const distKm = haversineKm(userLoc.lat, userLoc.lon, postLat, postLon)
  const label = formatDistance(distKm * 1000)
  const colorClass = getDistanceColor(distKm)

  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation()
    e.preventDefault()
    const params = new URLSearchParams({
      route: '1',
      toLat: String(postLat),
      toLon: String(postLon),
    })
    router.push(`/dashboard/map?${params}`)
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      title="Route auf der Karte anzeigen"
      className={cn(
        'inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[11px] font-medium border transition-colors hover:opacity-80 active:scale-95',
        colorClass,
        className,
      )}
    >
      <MapPin className="w-2.5 h-2.5 flex-shrink-0" aria-hidden="true" />
      {label} entfernt
    </button>
  )
}
