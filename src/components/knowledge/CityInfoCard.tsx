'use client'

import { useEffect, useState } from 'react'
import { Landmark, Users, MapPin, Globe, ExternalLink, Building2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import {
  fetchCityInfo,
  getCityFromCoords,
  type CityInfo,
} from '@/lib/api/wikidata'

// ── Skeleton ──────────────────────────────────────────────────────────────────

function CityInfoSkeleton() {
  return (
    <div className="rounded-2xl border border-stone-200 bg-white overflow-hidden animate-pulse shadow-soft">
      <div className="h-32 bg-stone-100" />
      <div className="p-4 space-y-3">
        <div className="h-5 bg-stone-100 rounded-lg w-1/2" />
        <div className="grid grid-cols-2 gap-2">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-14 bg-stone-100 rounded-xl" />
          ))}
        </div>
      </div>
    </div>
  )
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

function StatTile({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode
  label: string
  value: string
}) {
  return (
    <div className="bg-stone-50 border border-stone-100 rounded-xl p-3 flex items-start gap-2.5">
      <span className="text-primary-500 flex-shrink-0 mt-0.5">{icon}</span>
      <div className="min-w-0">
        <p className="text-[10px] uppercase tracking-wider text-gray-400 font-semibold leading-none mb-1">
          {label}
        </p>
        <p className="text-sm font-bold text-gray-900 leading-tight break-words">{value}</p>
      </div>
    </div>
  )
}

// ── Main Component ────────────────────────────────────────────────────────────

interface Props {
  /** Override auto-detected city – useful for testing */
  cityName?: string
  className?: string
  compact?: boolean
}

export default function CityInfoCard({ cityName: cityNameProp, className, compact }: Props) {
  const [cityName, setCityName] = useState<string | null>(cityNameProp ?? null)
  const [info, setInfo]         = useState<CityInfo | null>(null)
  const [loading, setLoading]   = useState(true)
  const [imgError, setImgError] = useState(false)

  // Resolve city name from profile if not provided
  useEffect(() => {
    if (cityNameProp) { setCityName(cityNameProp); return }

    let cancelled = false
    ;(async () => {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        if (!user || cancelled) return

        const { data: profile } = await supabase
          .from('profiles')
          .select('latitude, longitude, address, location')
          .eq('id', user.id)
          .maybeSingle()

        if (cancelled) return

        // 1. Try reverse geocoding from coordinates (most reliable)
        if (profile?.latitude != null && profile?.longitude != null) {
          const detected = await getCityFromCoords(
            profile.latitude as number,
            profile.longitude as number,
          )
          if (!cancelled && detected) { setCityName(detected); return }
        }

        // 2. Parse city from address field (e.g. "Musterstraße 1, 12345 Berlin")
        const addressField = (profile?.address ?? profile?.location ?? '') as string
        if (addressField) {
          const parts   = addressField.split(',').map(p => p.trim())
          // Last segment often is "PLZ Stadt" – extract city
          const lastPart = parts[parts.length - 1] ?? ''
          const cityMatch = lastPart.replace(/^\d{4,5}\s*/, '').trim()
          if (cityMatch.length > 2 && !cancelled) { setCityName(cityMatch); return }
        }
      } catch { /* silent */ }
      if (!cancelled) setLoading(false)
    })()

    return () => { cancelled = true }
  }, [cityNameProp])

  // Fetch Wikidata info once city name is known
  useEffect(() => {
    if (!cityName) return
    let cancelled = false
    setLoading(true)
    fetchCityInfo(cityName)
      .then(result => { if (!cancelled) { setInfo(result); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [cityName])

  if (loading) return <CityInfoSkeleton />

  if (!info) {
    // No Wikidata result – silent null to avoid empty card
    return null
  }

  const stats: { icon: React.ReactNode; label: string; value: string }[] = []

  if (info.population != null) {
    stats.push({
      icon:  <Users className="w-4 h-4" />,
      label: 'Einwohner',
      value: info.population.toLocaleString('de-DE'),
    })
  }
  if (info.areaSqKm != null) {
    stats.push({
      icon:  <MapPin className="w-4 h-4" />,
      label: 'Fläche',
      value: `${Math.round(info.areaSqKm).toLocaleString('de-DE')} km²`,
    })
  }
  if (info.foundedYear != null) {
    stats.push({
      icon:  <Landmark className="w-4 h-4" />,
      label: 'Gegründet',
      value: String(info.foundedYear),
    })
  }
  if (info.elevation != null) {
    stats.push({
      icon:  <Building2 className="w-4 h-4" />,
      label: 'Höhe ü. NN',
      value: `${Math.round(info.elevation).toLocaleString('de-DE')} m`,
    })
  }

  return (
    <div className={`relative bg-white border border-stone-200 rounded-2xl overflow-hidden shadow-soft ${className ?? ''}`}>
      {/* City image or coat-of-arms header */}
      {!compact && !imgError && (info.imageUrl || info.coatOfArmsUrl) && (
        <div className="relative h-36 bg-gradient-to-br from-primary-50 to-stone-100 overflow-hidden">
          {info.imageUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={info.imageUrl}
              alt={info.name}
              className="w-full h-full object-cover"
              onError={() => setImgError(true)}
            />
          )}
          {/* Coat of arms overlay */}
          {info.coatOfArmsUrl && (
            <div className="absolute bottom-3 right-3 w-14 h-14 bg-white/90 rounded-xl shadow-md p-1 backdrop-blur-sm">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={info.coatOfArmsUrl}
                alt={`Wappen ${info.name}`}
                className="w-full h-full object-contain"
                onError={() => {/* ignore coat of arms errors */}}
              />
            </div>
          )}
          {/* Gradient overlay for readability */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent" />
        </div>
      )}

      <div className="p-4 space-y-3">
        {/* Title row */}
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2.5">
            {(compact || (!info.imageUrl && info.coatOfArmsUrl)) && (
              <div className="w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center flex-shrink-0">
                {info.coatOfArmsUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={info.coatOfArmsUrl}
                    alt=""
                    className="w-8 h-8 object-contain"
                    onError={() => {/* ignore */}}
                  />
                ) : (
                  <Landmark className="w-5 h-5 text-primary-500" />
                )}
              </div>
            )}
            <div>
              <h3 className="font-bold text-gray-900 leading-tight">{info.name}</h3>
              {info.mayorName && (
                <p className="text-xs text-gray-500 mt-0.5">
                  Bürgermeister:in: <span className="font-medium text-gray-700">{info.mayorName}</span>
                </p>
              )}
            </div>
          </div>

          {info.website && (
            <a
              href={info.website}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-shrink-0 p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
              title="Offizielle Website"
            >
              <Globe className="w-4 h-4" />
            </a>
          )}
        </div>

        {/* Stats grid */}
        {stats.length > 0 && (
          <div className={`grid gap-2 ${stats.length >= 3 ? 'grid-cols-2' : 'grid-cols-2'}`}>
            {stats.slice(0, compact ? 2 : 4).map(s => (
              <StatTile key={s.label} icon={s.icon} label={s.label} value={s.value} />
            ))}
          </div>
        )}

        {/* Wikidata attribution */}
        <div className="flex items-center justify-between pt-1">
          <p className="text-[10px] text-gray-400">Quelle: Wikidata</p>
          {info.wikidataUrl && (
            <a
              href={info.wikidataUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-[10px] text-gray-400 hover:text-primary-600 transition-colors"
            >
              <ExternalLink className="w-3 h-3" /> Mehr auf Wikidata
            </a>
          )}
        </div>
      </div>
    </div>
  )
}
