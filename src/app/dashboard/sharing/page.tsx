'use client'

import { useState, useEffect } from 'react'
import { Shuffle, Smartphone, BookOpen, Shirt, Package2, TrendingUp } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Teilen & Tauschen Widget ─────────────────────────────────────
function SharingStatsWidget() {
  const [catStats, setCatStats] = useState<{ label: string; count: number; icon: React.ReactNode; color: string }[]>([])
  const [recentItems, setRecentItems] = useState<{ id: string; title: string; category: string }[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      // Nur Teilen/Tauschen-relevante Posts (sharing-Typ mit passenden Kategorien)
      const [allRes, recentRes] = await Promise.all([
        supabase.from('posts').select('category')
          .eq('type', 'sharing')
          .in('category', ['sharing', 'everyday', 'knowledge', 'general'])
          .eq('status', 'active'),
        supabase.from('posts').select('id,title,category')
          .eq('type', 'sharing')
          .in('category', ['sharing', 'everyday', 'knowledge', 'general'])
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(4),
      ])
      const all = allRes.data ?? []
      setTotal(all.length)
      setCatStats([
        { label: 'Geräte & Elektronik', count: all.filter(p => p.category === 'sharing').length,   icon: <Smartphone className="w-4 h-4" />, color: 'bg-blue-50 border-blue-200 text-blue-700' },
        { label: 'Kleidung',            count: all.filter(p => p.category === 'everyday').length,  icon: <Shirt className="w-4 h-4" />,       color: 'bg-pink-50 border-pink-200 text-pink-700'  },
        { label: 'Bücher & Medien',     count: all.filter(p => p.category === 'knowledge').length, icon: <BookOpen className="w-4 h-4" />,    color: 'bg-amber-50 border-amber-200 text-amber-700'},
        { label: 'Sonstiges',           count: all.filter(p => p.category === 'general').length,   icon: <Package2 className="w-4 h-4" />,    color: 'bg-green-50 border-green-200 text-green-700'},
      ])
      setRecentItems(recentRes.data ?? [])
      setLoading(false)
    }
    load()
  }, [])

  if (loading) {
    return <div className="h-24 bg-teal-50 rounded-2xl animate-pulse border border-teal-200" />
  }

  const catEmoji: Record<string, string> = {
    sharing: '📱', everyday: '👕', knowledge: '📚', general: '🌿', moving: '📦'
  }

  return (
    <div className="space-y-4">
      {/* Kategorie-Übersicht */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {catStats.map(c => (
          <div key={c.label} className={`flex flex-col items-center p-3 rounded-2xl border ${c.color}`}>
            <div className="mb-1">{c.icon}</div>
            <p className="text-xl font-bold">{c.count}</p>
            <p className="text-xs text-center opacity-80 mt-0.5">{c.label}</p>
          </div>
        ))}
      </div>

      {/* Aktuelle Angebote */}
      {recentItems.length > 0 && (
        <div className="bg-teal-50 border border-teal-200 rounded-2xl p-4">
          <div className="flex items-center gap-2 mb-2">
            <TrendingUp className="w-4 h-4 text-teal-600" />
            <p className="text-sm font-bold text-teal-800">Aktuelle Tausch-Angebote</p>
            <span className="ml-auto text-xs bg-teal-100 text-teal-700 px-2 py-0.5 rounded-full">{total} gesamt</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {recentItems.map(item => (
              <Link key={item.id} href={`/dashboard/posts/${item.id}`}
                className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white border border-teal-100 rounded-full text-xs font-medium text-teal-700 hover:bg-teal-50 transition-all">
                {catEmoji[item.category] ?? '🔄'} {item.title.length > 25 ? item.title.slice(0, 25) + '…' : item.title}
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Prinzip */}
      <div className="bg-white border border-warm-200 rounded-2xl p-4">
        <p className="text-xs text-gray-600">
          🔄 <strong>Gemeinsam statt neu kaufen:</strong> Teile Geräte, die du selten nutzt.
          Tausche Bücher, Kleidung und Gegenstände. Ressourcen schonen und Nachbarn kennenlernen!
        </p>
      </div>
    </div>
  )
}

export default function SharingPage() {
  return (
    <ModulePage
      title="Teilen & Tauschen"
      description="Geräte teilen, Kleidung & Bücher tauschen – gemeinsam statt neu kaufen"
      icon={<Shuffle className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-teal-500 to-emerald-600"
      postTypes={['sharing', 'rescue']}
      moduleFilter={[
        { type: 'sharing', categories: ['sharing', 'everyday', 'knowledge', 'general'] },  // Teilen & Tauschen
        { type: 'rescue',  categories: ['sharing', 'everyday'] },                          // Suche nach Gegenständen
      ]}
      createTypes={[
        { value: 'sharing', label: '🔄 Gegenstand anbieten' },
        { value: 'rescue',  label: '🔴 Gegenstand suchen'   },
      ]}
      categories={[
        { value: 'sharing',   label: '📱 Geräte'           },
        { value: 'everyday',  label: '👕 Kleidung'         },
        { value: 'knowledge', label: '📚 Bücher'           },
        { value: 'general',   label: '🌿 Sonstiges'        },
      ]}
      emptyText="Noch keine Tausch-Angebote"
    >
      <SharingStatsWidget />
    </ModulePage>
  )
}
