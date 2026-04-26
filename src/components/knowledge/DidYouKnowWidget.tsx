'use client'

import { useEffect, useState } from 'react'
import { Lightbulb } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { fetchRandomFact, getCityFromCoords } from '@/lib/api/wikidata'

export default function DidYouKnowWidget() {
  const [fact, setFact]       = useState<string | null>(null)
  const [city, setCity]       = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
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

        let cityName: string | null = null

        if (profile?.latitude != null && profile?.longitude != null) {
          cityName = await getCityFromCoords(
            profile.latitude as number,
            profile.longitude as number,
          )
        }

        if (!cityName) {
          const addr = (profile?.address ?? profile?.location ?? '') as string
          if (addr) {
            const parts    = addr.split(',').map((p: string) => p.trim())
            const last     = parts[parts.length - 1] ?? ''
            const stripped = last.replace(/^\d{4,5}\s*/, '').trim()
            if (stripped.length > 2) cityName = stripped
          }
        }

        if (!cityName || cancelled) { setLoading(false); return }

        setCity(cityName)
        const result = await fetchRandomFact(cityName)
        if (!cancelled) { setFact(result); setLoading(false) }
      } catch {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [])

  if (loading || !fact) return null

  return (
    <div className="relative bg-white border border-stone-200 rounded-2xl p-4 shadow-soft overflow-hidden">
      <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-primary-400 to-primary-200" />
      <div className="flex items-start gap-3">
        <div className="w-9 h-9 rounded-xl bg-primary-50 flex items-center justify-center flex-shrink-0">
          <Lightbulb className="w-4 h-4 text-primary-500" />
        </div>
        <div className="min-w-0">
          <p className="text-[10px] uppercase tracking-wider text-gray-400 font-semibold mb-1">
            Wusstest du? · {city}
          </p>
          <p className="text-sm text-gray-800 leading-snug">{fact}</p>
        </div>
      </div>
    </div>
  )
}
