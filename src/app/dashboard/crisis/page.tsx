'use client'

import { useState, useEffect } from 'react'
import { Siren, Clock, TrendingUp, Phone } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Aktive Notfälle Widget ───────────────────────────────────────
function ActiveCrisisWidget() {
  const [crises, setCrises] = useState<{ id: string; title: string; urgency: string; created_at: string; location_text?: string }[]>([])
  const [stats, setStats]   = useState({ critical: 0, high: 0, resolved_today: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const today = new Date()
      today.setHours(0, 0, 0, 0)

      const [activeRes, resolvedRes] = await Promise.all([
        supabase.from('posts').select('id,title,urgency,created_at,location_text')
          .eq('type', 'crisis').eq('status', 'active')
          .order('urgency', { ascending: false })
          .order('created_at', { ascending: false })
          .limit(5),
        supabase.from('posts').select('*', { count: 'exact', head: true })
          .eq('type', 'crisis').eq('status', 'fulfilled')
          .gte('updated_at', today.toISOString()),
      ])

      const list = activeRes.data ?? []
      setCrises(list)
      setStats({
        critical:       list.filter(p => p.urgency === 'critical').length,
        high:           list.filter(p => p.urgency === 'high').length,
        resolved_today: resolvedRes.count ?? 0,
      })
      setLoading(false)
    }
    load()

    // Realtime subscription for new crisis posts
    const channel = supabase
      .channel('crisis-updates')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posts', filter: 'type=eq.crisis' }, () => load())
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [])

  if (loading) {
    return <div className="h-32 bg-red-50 rounded-2xl animate-pulse border border-red-200" />
  }

  return (
    <div className="space-y-4">
      {/* Live-Zähler */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-red-100 border border-red-300 rounded-2xl p-4 text-center">
          <p className="text-3xl font-bold text-red-700">{stats.critical}</p>
          <p className="text-xs text-red-600 mt-0.5">🔴 Kritisch</p>
        </div>
        <div className="bg-orange-100 border border-orange-200 rounded-2xl p-4 text-center">
          <p className="text-3xl font-bold text-orange-700">{stats.high}</p>
          <p className="text-xs text-orange-600 mt-0.5">⚠️ Dringend</p>
        </div>
        <div className="bg-green-100 border border-green-200 rounded-2xl p-4 text-center">
          <p className="text-3xl font-bold text-green-700">{stats.resolved_today}</p>
          <p className="text-xs text-green-600 mt-0.5">✅ Heute gelöst</p>
        </div>
      </div>

      {/* Aktive Notfälle – Live-Liste */}
      {crises.length === 0 ? (
        <div className="bg-green-50 border border-green-200 rounded-2xl p-5 text-center">
          <div className="text-3xl mb-2">✅</div>
          <p className="font-semibold text-green-800">Alles ruhig – keine aktiven Notfälle!</p>
          <p className="text-xs text-green-600 mt-1">Gut so. Wenn du einen Notfall siehst, melde ihn sofort.</p>
        </div>
      ) : (
        <div className="bg-red-50 border border-red-300 rounded-2xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
            <p className="text-sm font-bold text-red-800">Live – Aktive Notfälle</p>
            <span className="ml-auto text-xs bg-red-200 text-red-700 px-2 py-0.5 rounded-full">{crises.length} aktiv</span>
          </div>
          <div className="space-y-2">
            {crises.map(c => {
              const ago = (() => {
                const diff = Date.now() - new Date(c.created_at).getTime()
                const m = Math.floor(diff / 60000)
                if (m < 1) return 'gerade'
                if (m < 60) return `${m} Min.`
                return `${Math.floor(m / 60)} Std.`
              })()
              return (
                <Link key={c.id} href={`/dashboard/posts/${c.id}`}
                  className="flex items-center gap-3 p-2.5 bg-white rounded-xl hover:bg-red-50 transition-all border border-red-100 group">
                  <div className={`w-2 h-2 rounded-full flex-shrink-0 ${c.urgency === 'critical' ? 'bg-red-600 animate-pulse' : 'bg-orange-400'}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-gray-900 truncate group-hover:text-red-700">{c.title}</p>
                    {c.location_text && <p className="text-xs text-gray-500">📍 {c.location_text}</p>}
                  </div>
                  <div className="flex items-center gap-1 flex-shrink-0">
                    <Clock className="w-3 h-3 text-gray-400" />
                    <span className="text-xs text-gray-400">{ago}</span>
                  </div>
                </Link>
              )
            })}
          </div>
        </div>
      )}

      {/* Notfall-Hotlines */}
      <div className="bg-white border border-warm-200 rounded-2xl p-4">
        <p className="text-xs font-bold text-gray-700 mb-2 flex items-center gap-1.5">
          <Phone className="w-3.5 h-3.5 text-red-500" /> Offizielle Notfallnummern
        </p>
        <div className="grid grid-cols-2 gap-2">
          {[
            { label: 'Notruf Polizei',   num: '133' },
            { label: 'Notruf Feuerwehr', num: '122' },
            { label: 'Notarzt / Rettung',num: '144' },
            { label: 'Euro-Notruf',      num: '112' },
          ].map(h => (
            <a key={h.num} href={`tel:${h.num}`}
              className="flex items-center gap-2 p-2 bg-red-50 hover:bg-red-100 rounded-xl transition-all group">
              <span className="text-sm font-bold text-red-700 group-hover:text-red-800">{h.num}</span>
              <span className="text-xs text-gray-600">{h.label}</span>
            </a>
          ))}
        </div>
      </div>
    </div>
  )
}

export default function CrisisPage() {
  return (
    <ModulePage
      title="🚨 Krisensystem"
      description="Notfall-Hilfe, schnelle Helfer-Zuweisung, Essensversorgung – sofortige Hilfe"
      icon={<Siren className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-red-600 to-rose-700"
      postTypes={['crisis', 'help_request', 'help_offer']}
      createTypes={[
        { value: 'crisis',       label: '🚨 Notfall melden'    },
        { value: 'help_request', label: '🔴 Dringend Hilfe'    },
        { value: 'help_offer',   label: '🟢 Ich helfe sofort'  },
      ]}
      categories={[
        { value: 'emergency', label: '🆘 Notfall'            },
        { value: 'food',      label: '🍎 Essensversorgung'   },
        { value: 'housing',   label: '🏠 Unterkunft'        },
        { value: 'general',   label: '🌿 Sonstige Hilfe'    },
      ]}
      emptyText="Keine aktiven Notfälle – gut so!"
    >
      <ActiveCrisisWidget />
    </ModulePage>
  )
}
