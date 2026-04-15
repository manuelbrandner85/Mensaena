'use client'

import { useEffect, useState, useCallback } from 'react'
import { Car, Clock, Calendar } from 'lucide-react'
import ModulePage from '@/components/shared/ModulePage'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'

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
    const d = (r as Record<string, unknown>).event_date as string | undefined
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
    <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-4">
        <Calendar className="w-5 h-5 text-indigo-600" />
        <h3 className="font-bold text-indigo-900">Kommende Fahrten</h3>
        <span className="ml-auto text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full font-medium">
          {rides.length} geplant
        </span>
      </div>
      <div className="space-y-4">
        {[...groups.entries()].map(([date, items]) => (
          <div key={date}>
            <div className="flex items-center gap-2 mb-2">
              <p className="text-xs font-bold uppercase tracking-wide text-indigo-700">
                {formatGroupLabel(date)}
              </p>
              <div className="flex-1 h-px bg-indigo-200" />
              <span className="text-[10px] text-indigo-500 font-medium">
                {items.length} {items.length === 1 ? 'Fahrt' : 'Fahrten'}
              </span>
            </div>
            <div className="space-y-2">
              {items.map(r => {
                const timeStr = (r as Record<string, unknown>).event_time as string | undefined
                return (
                  <div key={r.id} className="bg-white rounded-xl p-3 border border-indigo-100 flex items-center gap-3">
                    <div className="text-center w-12 flex-shrink-0">
                      {timeStr ? (
                        <p className="text-sm font-bold text-indigo-600">{timeStr.slice(0, 5)}</p>
                      ) : (
                        <Clock className="w-5 h-5 text-gray-300 mx-auto" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-gray-900 truncate">{r.title}</p>
                      {r.location_text && <p className="text-xs text-gray-500 truncate">📍 {r.location_text}</p>}
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
      sectionLabel="§ 23 / Mobilität"
      mood="sky"
      iconBgClass="bg-indigo-50 border-indigo-100"
      iconColorClass="text-indigo-600"
      title="Mobilität"
      description="Mitfahrgelegenheiten, Transporthilfe, Fahrten mit Datum & Uhrzeit"
      icon={<Car className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-indigo-500 to-blue-600"
      postTypes={['mobility', 'rescue']}
      moduleFilter={[
        { type: 'mobility' },                                         // ALLE mobility-Posts
        { type: 'rescue', categories: ['mobility', 'moving'] },       // rescue nur Fahrten/Transport
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
    >
      <UpcomingRidesWidget />
    </ModulePage>
  )
}
