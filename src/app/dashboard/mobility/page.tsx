'use client'

import { useEffect, useState, useCallback } from 'react'
import { Car, Clock, Calendar } from 'lucide-react'
import ModulePage from '@/components/shared/ModulePage'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import TransitWidget from '@/components/mobility/TransitWidget'
import ChargingStationsWidget from '@/components/mobility/ChargingStationsWidget'
import TrafficWidget from '@/components/traffic/TrafficWidget'
import PollenWidget from '@/components/environment/PollenWidget'
import dynamic from 'next/dynamic'

const WeatherWidget = dynamic(() => import('@/app/dashboard/components/WeatherWidget'), { ssr: false })

function ProfileWeatherWidget() {
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null)
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      supabase.from('profiles').select('latitude, longitude').eq('id', user.id).maybeSingle()
        .then(({ data }) => {
          if (data?.latitude && data?.longitude)
            setCoords({ lat: data.latitude, lng: data.longitude })
        })
    })
  }, [])
  if (!coords) return null
  return <WeatherWidget lat={coords.lat} lng={coords.lng} />
}

// Widget: nächste Fahrten (mit Datum)
function UpcomingRidesWidget() {
  const [rides, setRides]   = useState<PostCardPost[]>([])
  const [loading, setLoading]   = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Posts with event_date in the future
      const today = new Date().toISOString().slice(0, 10)
      const { data, error } = await supabase
        .from('posts')
        .select('*, profiles(name,avatar_url)')
        .eq('status', 'active')
        .eq('type', 'mobility')
        .gte('event_date', today)
        .order('event_date', { ascending: true })
        .limit(20)
      if (cancelled) return
      if (error) console.error('upcoming rides query failed:', error.message)
      setRides(data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading || rides.length === 0) return null

  // Gruppiere Fahrten nach Datum
  const groups = new Map<string, PostCardPost[]>()
  rides.forEach(r => {
    const d = (r as unknown as Record<string, unknown>).event_date as string | undefined
    if (!d) return
    const list = groups.get(d) ?? []
    list.push(r)
    groups.set(d, list)
  })

  const formatGroupLabel = (dateStr: string) => {
    const d = new Date(dateStr)
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)
    const dNormalized = new Date(d); dNormalized.setHours(0, 0, 0, 0)
    if (dNormalized.getTime() === today.getTime()) return 'Heute'
    if (dNormalized.getTime() === tomorrow.getTime()) return 'Morgen'
    return d.toLocaleDateString('de-AT', { weekday: 'long', day: '2-digit', month: 'long' })
  }

  return (
    <div className="relative bg-gradient-to-br from-indigo-50 via-indigo-50/80 to-mn-teal-soft border border-white/5 rounded-2xl p-5 shadow-cinema-card overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #6366F1, #6366F133)' }}
      />
      <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
      <div className="relative flex items-center gap-2 mb-4">
        <Calendar className="w-5 h-5 text-mn-teal-soft float-idle" />
        <h3 className="font-bold text-mn-teal-soft">Kommende Fahrten</h3>
        <span className="display-numeral ml-auto text-xs bg-mn-elevated text-mn-teal-soft px-2 py-0.5 rounded-full font-medium tabular-nums">
          {rides.length} geplant
        </span>
      </div>
      <div className="relative space-y-4">
        {[...groups.entries()].map(([date, items]) => (
          <div key={date}>
            <div className="flex items-center gap-2 mb-2">
              <p className="text-xs font-bold uppercase tracking-wide text-mn-teal-soft">
                {formatGroupLabel(date)}
              </p>
              <div className="flex-1 h-px bg-indigo-200" />
              <span className="display-numeral text-xs text-mn-teal-soft font-medium">
                {items.length} {items.length === 1 ? 'Fahrt' : 'Fahrten'}
              </span>
            </div>
            <div className="space-y-2">
              {items.map(r => {
                const timeStr = (r as unknown as Record<string, unknown>).event_time as string | undefined
                return (
                  <div key={r.id} className="bg-mn-elevated rounded-xl p-3 border border-white/5 flex items-center gap-3 shadow-cinema-card hover:shadow-cinema-card transition-shadow">
                    <div className="text-center w-12 flex-shrink-0">
                      {timeStr ? (
                        <p className="display-numeral text-sm font-bold text-mn-teal-soft">{timeStr.slice(0, 5)}</p>
                      ) : (
                        <Clock className="w-5 h-5 text-mn-ghost mx-auto" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-mn-ink truncate">{r.title}</p>
                      {r.location_text && <p className="text-xs text-mn-mute truncate">📍 {r.location_text}</p>}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

export default function MobilityPage() {
  return (
    <ModulePage
      moduleKey="mobility"
      sectionLabel="§ 23 / Mobilität"
      mood="sky"
      iconBgClass="bg-mn-surface border-white/5"
      iconColorClass="text-mn-teal-soft"
      title="Mobilität"
      description="Mitfahrgelegenheiten, Transporthilfe, Fahrten mit Datum & Uhrzeit"
      icon={<Car className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-indigo-500 to-mn-teal-soft"
      postTypes={['mobility', 'rescue']}
      moduleFilter={[
        { type: 'mobility' },                                                              // ALLE mobility-Posts
        { type: 'rescue', categories: ['mobility', 'moving', 'everyday', 'general'] },     // rescue + alle Mobilitäts-Kategorien
      ]}
      createTypes={[
        { value: 'mobility', label: '🚗 Fahrt anbieten' },
        { value: 'rescue',   label: '🔴 Fahrt suchen'   },
      ]}
      categories={[
        { value: 'mobility',  label: '🚌 Mitfahrt'   },
        { value: 'moving',    label: '📦 Transport'  },
        { value: 'everyday',  label: '🛒 Besorgungen'},
        { value: 'general',   label: '🌿 Sonstiges'  },
      ]}
      emptyText="Noch keine Mobilitäts-Angebote"
      examplePosts={[
        { emoji: '🚗', title: 'Fahre am Freitag nach Wien – Mitfahrer?', description: 'Ich fahre freitags regelmäßig von Linz nach Wien und biete Mitfahrplätze an. Kosten teilen wir uns.', type: 'mobility', category: 'mobility' },
        { emoji: '🛒', title: 'Suche Mitfahrt zum Einkaufszentrum', description: 'Brauche einmal pro Woche eine Mitfahrgelegenheit ins Einkaufszentrum. Bin auch gerne bereit, die Spritkosten zu teilen.', type: 'rescue', category: 'mobility' },
        { emoji: '📦', title: 'Biete Transportfahrt für Umzüge', description: 'Habe einen Transporter und helfe gerne bei kleinen Umzügen oder wenn große Möbelstücke transportiert werden müssen.', type: 'mobility', category: 'moving' },
      ]}
    >
      <ProfileWeatherWidget />
      <TransitWidget />
      <TrafficWidget />
      <ChargingStationsWidget />
      <PollenWidget compact />
      <UpcomingRidesWidget />
    </ModulePage>
  )
}
