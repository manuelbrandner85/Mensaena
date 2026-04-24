'use client'

import { useState, useEffect } from 'react'
import { PawPrint, AlertCircle, Heart, MapPin } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Tier-Status Widget ──────────────────────────────────────────
function AnimalStatusWidget() {
  const [stats, setStats] = useState({ lost: 0, found: 0, shelter: 0, emergency: 0 })
  const [recentLost, setRecentLost] = useState<{ id: string; title: string; location_text?: string; created_at: string }[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Nur Tier-relevante Posts laden
      const [allRes, lostRes] = await Promise.all([
        supabase.from('posts').select('type,category,urgency')
          .eq('status', 'active')
          .or('type.eq.animal,and(type.in.(rescue,crisis),category.eq.animals)'),
        supabase.from('posts').select('id,title,location_text,created_at')
          .eq('status', 'active')
          .or('type.eq.animal,and(type.eq.crisis,category.eq.animals)')
          .order('created_at', { ascending: false })
          .limit(3),
      ])
      if (cancelled) return
      if (allRes.error) console.error('animals stats query failed:', allRes.error.message)
      if (lostRes.error) console.error('animals recent lost query failed:', lostRes.error.message)
      const posts = allRes.data ?? []
      setStats({
        lost:      posts.filter(p => p.type === 'crisis').length,
        found:     posts.filter(p => p.type === 'animal').length,
        shelter:   posts.filter(p => p.type === 'rescue').length,
        emergency: posts.filter(p => p.urgency === 'high' || p.urgency === 'critical').length,
      })
      setRecentLost(lostRes.data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[0,1,2,3].map(i => <div key={i} className="h-20 bg-gray-100 rounded-2xl animate-pulse" />)}
      </div>
    )
  }

  const cards = [
    { icon: AlertCircle, label: 'Tier vermisst',    value: stats.lost,      accent: '#C62828' },
    { icon: PawPrint,    label: 'Tier gefunden',    value: stats.found,     accent: '#1EAAA6' },
    { icon: Heart,       label: 'Helfer angeboten', value: stats.shelter,   accent: '#EC4899' },
    { icon: AlertCircle, label: '🚨 Notfälle',     value: stats.emergency, accent: '#F97316' },
  ]

  return (
    <div className="space-y-4">
      {/* Statistik-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map(s => {
          const Icon = s.icon
          return (
            <div
              key={s.label}
              className="relative flex flex-col items-center p-3 rounded-2xl bg-white border border-gray-100 shadow-soft hover:shadow-card transition-shadow overflow-hidden"
            >
              <div
                className="absolute top-0 left-0 right-0 h-px opacity-60"
                style={{ background: `linear-gradient(90deg, ${s.accent}66, transparent)` }}
              />
              <div
                className="w-8 h-8 rounded-lg flex items-center justify-center mb-1.5"
                style={{ background: `${s.accent}18` }}
              >
                <Icon className="w-4 h-4" style={{ color: s.accent }} />
              </div>
              <p className="display-numeral text-xl font-bold text-gray-900 tabular-nums">{s.value}</p>
              <p className="text-xs text-gray-500 text-center leading-tight">{s.label}</p>
            </div>
          )
        })}
      </div>

      {/* Letzte Notfälle */}
      {recentLost.length > 0 && (
        <div className="relative bg-gradient-to-br from-red-50 via-red-50/80 to-orange-50 border border-red-200 rounded-2xl p-4 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #C62828, #C6282833)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <p className="relative text-sm font-bold text-red-800 mb-2 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" /> Dringende Tier-Notfälle
          </p>
          <div className="relative space-y-1.5">
            {recentLost.map(p => (
              <Link key={p.id} href={`/dashboard/posts/${p.id}`}
                className="flex items-center gap-2 p-2.5 bg-white rounded-xl hover:bg-red-50 transition-all border border-red-100 group shadow-soft">
                <PawPrint className="w-4 h-4 text-red-400 flex-shrink-0 group-hover:scale-110 transition-transform" />
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-semibold text-gray-800 truncate group-hover:text-red-700">{p.title}</p>
                  {p.location_text && (
                    <p className="text-xs text-gray-500 flex items-center gap-1">
                      <MapPin className="w-2.5 h-2.5" />{p.location_text}
                    </p>
                  )}
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export default function AnimalsPage() {
  return (
    <ModulePage
      sectionLabel="§ 18 / Tierhilfe"
      mood="warm"
      iconBgClass="bg-pink-50 border-pink-100"
      iconColorClass="text-pink-600"
      title="Tierhilfe"
      description="Tierheime, Vermittlung, Gassi-Geher, vermisste Tiere – alles an einem Ort"
      icon={<PawPrint className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-pink-500 to-rose-600"
      postTypes={['animal', 'rescue', 'crisis']}
      moduleFilter={[
        { type: 'animal' },                                  // ALLE animal-Posts
        { type: 'rescue', categories: ['animals'] },         // rescue nur mit Tier-Kategorie
        { type: 'crisis', categories: ['animals'] },         // crisis nur Tier-Notfälle
      ]}
      createTypes={[
        { value: 'animal',  label: '🐾 Tier gefunden/vermisst' },
        { value: 'rescue',  label: '🟡 Hilfe anbieten'         },
        { value: 'crisis',  label: '🚨 Tier-Notfall'           },
      ]}
      categories={[
        { value: 'animals',   label: '🐶 Vermittlung'        },
        { value: 'everyday',  label: '🐱 Pflege / Gassi'     },
        { value: 'emergency', label: '🚨 Notfall Tier'       },
        { value: 'general',   label: '🌿 Sonstiges'          },
      ]}
      emptyText="Noch keine Tierhilfe-Beiträge"
      examplePosts={[
        { emoji: '🐈', title: 'Katze entlaufen – bitte melden', description: 'Unsere schwarze Katze "Luna" ist seit gestern Abend verschwunden. Bitte meldet euch, wenn ihr sie gesehen habt.', type: 'animal', category: 'animals' },
        { emoji: '🐕', title: 'Biete Hundebetreuung am Wochenende', description: 'Ich betreue gerne Hunde, wenn ihr im Urlaub seid oder einen Termin habt. Erfahrung mit großen Hunden.', type: 'rescue', category: 'animals' },
        { emoji: '🐾', title: 'Tier-Notfall: Igel verletzt gefunden', description: 'Verletzten Igel im Garten gefunden – wer kennt eine Tierauffangstation in der Nähe?', type: 'crisis', category: 'animals' },
      ]}
    >
      <AnimalStatusWidget />
    </ModulePage>
  )
}
