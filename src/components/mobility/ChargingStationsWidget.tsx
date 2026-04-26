'use client'

/**
 * Compact widget that shows nearby EV charging stations on the Mobility page.
 *
 * Helps users planning EV rideshares find charging infrastructure along their
 * route. Loads stations once on mount based on the user's profile coordinates.
 */

import { useEffect, useState } from 'react'
import { Zap, MapPin, Battery } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import {
  fetchChargingStations,
  getMaxPower,
  getPowerColor,
  type ChargingStation,
} from '@/lib/api/chargingstations'

interface Props {
  /** Optional override – if not given, uses the logged-in user's profile coords. */
  lat?: number
  lng?: number
  radiusKm?: number
  className?: string
}

export default function ChargingStationsWidget({ lat, lng, radiusKm = 15, className }: Props) {
  const [stations, setStations] = useState<ChargingStation[]>([])
  const [loading, setLoading]   = useState(true)
  const [coords, setCoords]     = useState<{ lat: number; lng: number } | null>(
    lat != null && lng != null ? { lat, lng } : null,
  )

  // Resolve coords from profile if not passed in
  useEffect(() => {
    if (coords) return
    let cancelled = false
    const supabase = createClient()
    ;(async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user || cancelled) return
      const { data } = await supabase
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', user.id)
        .maybeSingle()
      if (!cancelled && data?.latitude != null && data?.longitude != null) {
        setCoords({ lat: data.latitude as number, lng: data.longitude as number })
      } else if (!cancelled) {
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [coords])

  // Load stations once we have coords
  useEffect(() => {
    if (!coords) return
    let cancelled = false
    setLoading(true)
    fetchChargingStations(coords.lat, coords.lng, radiusKm)
      .then(s => { if (!cancelled) setStations(s) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [coords, radiusKm])

  if (loading || stations.length === 0) return null

  // Sort by max power desc so the most useful options are first
  const sorted = [...stations].sort((a, b) => getMaxPower(b) - getMaxPower(a)).slice(0, 5)
  const fastCount   = stations.filter(s => getMaxPower(s) >= 50).length
  const mediumCount = stations.filter(s => { const p = getMaxPower(s); return p >= 22 && p < 50 }).length
  const slowCount   = stations.filter(s => getMaxPower(s) < 22).length

  return (
    <div className={`relative bg-gradient-to-br from-emerald-50 via-emerald-50/80 to-green-50 border border-emerald-200 rounded-2xl p-5 shadow-soft overflow-hidden ${className ?? ''}`}>
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #16A34A, #16A34A33)' }}
      />
      <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />

      <div className="relative flex items-center gap-2 mb-4">
        <Zap className="w-5 h-5 text-emerald-600 float-idle" />
        <h3 className="font-bold text-emerald-900">E-Ladesäulen in der Nähe</h3>
        <span className="display-numeral ml-auto text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full font-medium tabular-nums">
          {stations.length}
        </span>
      </div>

      {/* Power breakdown */}
      <div className="relative grid grid-cols-3 gap-2 mb-4 text-center">
        <div className="rounded-xl bg-white/70 border border-emerald-100 py-2">
          <p className="text-[10px] uppercase tracking-wider text-emerald-700 font-semibold">Ultra</p>
          <p className="display-numeral text-lg font-bold text-emerald-700">{fastCount}</p>
          <p className="text-[10px] text-gray-500">≥ 50 kW</p>
        </div>
        <div className="rounded-xl bg-white/70 border border-amber-100 py-2">
          <p className="text-[10px] uppercase tracking-wider text-amber-700 font-semibold">Schnell</p>
          <p className="display-numeral text-lg font-bold text-amber-700">{mediumCount}</p>
          <p className="text-[10px] text-gray-500">22–50 kW</p>
        </div>
        <div className="rounded-xl bg-white/70 border border-blue-100 py-2">
          <p className="text-[10px] uppercase tracking-wider text-blue-700 font-semibold">Normal</p>
          <p className="display-numeral text-lg font-bold text-blue-700">{slowCount}</p>
          <p className="text-[10px] text-gray-500">&lt; 22 kW</p>
        </div>
      </div>

      {/* Top 5 closest/fastest stations */}
      <div className="relative space-y-2">
        {sorted.map(station => {
          const maxKW   = getMaxPower(station)
          const color   = getPowerColor(maxKW)
          const navUrl  = `https://www.google.com/maps/dir/?api=1&destination=${station.lat},${station.lon}`
          const addr    = [station.address, station.city].filter(Boolean).join(', ')
          return (
            <a
              key={station.id}
              href={navUrl}
              target="_blank"
              rel="noopener"
              className="flex items-center gap-3 bg-white rounded-xl p-3 border border-emerald-100 shadow-soft hover:shadow-card transition-shadow"
            >
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
                style={{ background: color }}
              >
                <Battery className="w-5 h-5 text-white" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 truncate">{station.name}</p>
                {addr && (
                  <p className="text-xs text-gray-500 truncate flex items-center gap-1">
                    <MapPin className="w-3 h-3" /> {addr}
                  </p>
                )}
              </div>
              <div className="text-right flex-shrink-0">
                <p
                  className="display-numeral text-sm font-bold tabular-nums"
                  style={{ color }}
                >
                  {maxKW > 0 ? `${maxKW} kW` : '?'}
                </p>
                <p className="text-[10px] text-gray-500">
                  {station.connections.length} {station.connections.length === 1 ? 'Anschluss' : 'Anschlüsse'}
                </p>
              </div>
            </a>
          )
        })}
      </div>

      <p className="relative text-[10px] text-emerald-700/70 mt-3 text-center">
        Daten: OpenChargeMap · Tippe für Navigation
      </p>
    </div>
  )
}
