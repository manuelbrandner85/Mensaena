'use client'

import { useEffect, useState } from 'react'
import { Lightbulb } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { fetchRandomFact, getCityFromCoords } from '@/lib/api/wikidata'

const FALLBACK_FACTS = [
  'Deutschland hat 16 Bundesländer und über 11.000 Gemeinden.',
  'Über 83 Millionen Menschen leben in Deutschland – dem bevölkerungsreichsten Land der EU.',
  'Deutschland besitzt mehr als 20.000 Burgen und Schlösser – mehr als jedes andere Land der Welt.',
  'Der Rhein ist mit über 865 km der längste Fluss, der vollständig durch Deutschland fließt.',
  'Deutschland ist eines der fahrradfreundlichsten Länder mit über 70.000 km Radwegen.',
  'In Deutschland gibt es rund 1.300 Brauereien – die meisten weltweit nach China.',
  'Der Schwarzwald ist das größte zusammenhängende Waldgebiet Deutschlands mit 6.009 km².',
  'Berlin ist dreimal größer als Paris und neunmal größer als München.',
  'Deutschland hat 46 UNESCO-Welterbestätten – mehr als jedes andere deutschsprachige Land.',
  'Die Autobahn hat das längste Netz an gebührenfreien Schnellstraßen weltweit.',
]

function getDailyFallback(): string {
  const dayOfYear = Math.floor(
    (Date.now() - new Date(new Date().getUTCFullYear(), 0, 0).getTime()) / 86_400_000,
  )
  return FALLBACK_FACTS[dayOfYear % FALLBACK_FACTS.length]
}

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
        if (!user || cancelled) {
          if (!cancelled) { setFact(getDailyFallback()); setLoading(false) }
          return
        }

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

        if (cityName && !cancelled) {
          setCity(cityName)
          const result = await fetchRandomFact(cityName)
          if (!cancelled) {
            setFact(result ?? getDailyFallback())
            setLoading(false)
          }
        } else if (!cancelled) {
          setFact(getDailyFallback())
          setLoading(false)
        }
      } catch {
        if (!cancelled) { setFact(getDailyFallback()); setLoading(false) }
      }
    })()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return (
      <div className="relative bg-mn-elevated border border-white/5 rounded-2xl p-4 shadow-soft animate-pulse">
        <div className="flex items-start gap-3">
          <div className="w-9 h-9 rounded-xl bg-mn-amber/5 flex-shrink-0" />
          <div className="flex-1 space-y-2 pt-1">
            <div className="h-3 bg-mn-raised rounded w-1/3" />
            <div className="h-4 bg-mn-raised rounded w-full" />
            <div className="h-4 bg-mn-raised rounded w-4/5" />
          </div>
        </div>
      </div>
    )
  }

  if (!fact) return null

  return (
    <div className="relative bg-mn-elevated border border-white/5 rounded-2xl p-4 shadow-soft overflow-hidden">
      <div className="absolute top-0 left-0 right-0 h-[3px] bg-gradient-to-r from-primary-400 to-primary-200" />
      <div className="flex items-start gap-3">
        <div className="w-9 h-9 rounded-xl bg-mn-amber/5 flex items-center justify-center flex-shrink-0">
          <Lightbulb className="w-4 h-4 text-mn-amber" />
        </div>
        <div className="min-w-0">
          <p className="text-xs uppercase tracking-wider text-mn-mute font-semibold mb-1">
            {city ? `Wusstest du? · ${city}` : 'Wusstest du?'}
          </p>
          <p className="text-sm text-mn-ink leading-snug">{fact}</p>
        </div>
      </div>
    </div>
  )
}
