'use client'

import { useEffect, useState, useCallback } from 'react'
import { Car, Clock, Calendar } from 'lucide-react'
import ModulePage from '@/components/shared/ModulePage'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'

// Widget: nächste Fahrten (mit Datum)
function UpcomingRidesWidget() {
  const [rides, setRides]   = useState<PostCardPost[]>([])
  const [userId, setUserId] = useState<string>()
  const [savedIds, setSavedIds] = useState<string[]>([])
  const [loading, setLoading]   = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (user) { setUserId(user.id) }
      // Posts with event_date in the future
      const today = new Date().toISOString().slice(0, 10)
      const { data } = await supabase
        .from('posts')
        .select('*, profiles(name,avatar_url)')
        .eq('status', 'active')
        .eq('type', 'mobility')
        .gte('event_date', today)
        .order('event_date', { ascending: true })
        .limit(6)
      setRides(data ?? [])
      setLoading(false)
    }
    load()
  }, [])

  if (loading || rides.length === 0) return null

  return (
    <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-3">
        <Calendar className="w-5 h-5 text-indigo-600" />
        <h3 className="font-bold text-indigo-900">Nächste Fahrten</h3>
        <span className="ml-auto text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full font-medium">
          {rides.length} geplant
        </span>
      </div>
      <div className="space-y-2">
        {rides.map(r => {
          const dateStr = (r as Record<string, unknown>).event_date as string | undefined
          const timeStr = (r as Record<string, unknown>).event_time as string | undefined
          return (
            <div key={r.id} className="bg-white rounded-xl p-3 border border-indigo-100 flex items-center gap-3">
              <div className="text-center w-14 flex-shrink-0">
                {dateStr ? (
                  <>
                    <p className="text-xs text-indigo-600 font-bold">
                      {new Date(dateStr).toLocaleDateString('de-AT', { day: '2-digit', month: 'short' })}
                    </p>
                    {timeStr && <p className="text-xs text-gray-500">{timeStr}</p>}
                  </>
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
  )
}

export default function MobilityPage() {
  return (
    <ModulePage
      title="Mobilität"
      description="Mitfahrgelegenheiten, Transporthilfe, Fahrten mit Datum & Uhrzeit"
      icon={<Car className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-indigo-500 to-blue-600"
      postTypes={['mobility', 'rescue']}
      createTypes={[
        { value: 'mobility',     label: '🚗 Fahrt anbieten' },
        { value: 'rescue',   label: '🔴 Fahrt suchen'   },
        { value: 'sharing',  label: '🟢 Transporthilfe' },
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
