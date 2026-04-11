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
  }, [])

  if (loading) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[0,1,2,3].map(i => <div key={i} className="h-20 bg-gray-100 rounded-2xl animate-pulse" />)}
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Statistik-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { icon: AlertCircle, label: 'Tier vermisst',   value: stats.lost,      color: 'bg-red-50 border-red-200 text-red-700',       iconColor: 'text-red-500'    },
          { icon: PawPrint,    label: 'Tier gefunden',   value: stats.found,     color: 'bg-green-50 border-green-200 text-green-700',  iconColor: 'text-green-500'  },
          { icon: Heart,       label: 'Helfer angeboten',value: stats.shelter,   color: 'bg-pink-50 border-pink-200 text-pink-700',     iconColor: 'text-pink-500'   },
          { icon: AlertCircle, label: '🚨 Notfälle',    value: stats.emergency, color: 'bg-orange-50 border-orange-200 text-orange-700',iconColor: 'text-orange-500' },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-4 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-6 h-6 mb-1 ${s.iconColor}`} />
            <p className="text-2xl font-bold">{s.value}</p>
            <p className="text-xs text-center mt-0.5 opacity-80">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Letzte Notfälle */}
      {recentLost.length > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-2xl p-4">
          <p className="text-sm font-bold text-red-800 mb-2 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" /> Dringende Tier-Notfälle
          </p>
          <div className="space-y-1.5">
            {recentLost.map(p => (
              <Link key={p.id} href={`/dashboard/posts/${p.id}`}
                className="flex items-center gap-2 p-2 bg-white rounded-xl hover:bg-red-50 transition-all group">
                <PawPrint className="w-4 h-4 text-red-400 flex-shrink-0" />
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
    >
      <AnimalStatusWidget />
    </ModulePage>
  )
}
