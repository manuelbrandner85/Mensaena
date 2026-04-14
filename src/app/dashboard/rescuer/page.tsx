'use client'

import { useState, useEffect } from 'react'
import { ShieldAlert, Package, Shirt, Apple, Recycle } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'

// ── Gerettete Ressourcen Widget ─────────────────────────────────
function RescuedTodayWidget() {
  const [stats, setStats] = useState({ food: 0, clothes: 0, items: 0, total: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const { data } = await supabase.from('posts')
        .select('category,status')
        .eq('type', 'rescue')
        .in('status', ['active', 'fulfilled'])

      const all = data ?? []
      const active = all.filter(p => p.status === 'active')
      setStats({
        food:    active.filter(p => p.category === 'food').length,
        clothes: active.filter(p => p.category === 'everyday').length,
        items:   active.filter(p => p.category === 'sharing').length,
        total:   all.filter(p => p.status === 'fulfilled').length,  // total fulfilled = gerettet
      })
      setLoading(false)
    }
    load()
  }, [])

  if (loading) {
    return <div className="h-24 bg-orange-50 rounded-2xl animate-pulse border border-orange-200" />
  }

  return (
    <div className="space-y-4">
      {/* Ressourcen-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { icon: Apple,   label: 'Lebensmittel', value: stats.food,    color: 'bg-red-50 border-red-200',      iconColor: 'text-red-500'    },
          { icon: Shirt,   label: 'Kleidung',     value: stats.clothes, color: 'bg-blue-50 border-blue-200',    iconColor: 'text-blue-500'   },
          { icon: Package, label: 'Gegenstände',  value: stats.items,   color: 'bg-yellow-50 border-yellow-200',iconColor: 'text-yellow-600' },
          { icon: Recycle, label: 'Gesamt gerettet', value: stats.total, color: 'bg-green-50 border-green-200', iconColor: 'text-green-600'  },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-4 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-5 h-5 mb-1 ${s.iconColor}`} />
            <p className="text-2xl font-bold text-gray-800">{s.value}</p>
            <p className="text-xs text-gray-500 text-center mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Mission-Statement */}
      <div className="bg-orange-50 border border-orange-200 rounded-2xl p-4">
        <p className="text-sm font-bold text-orange-800 mb-2">🧡 Warum Ressourcen retten?</p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs text-orange-900">
          <div className="flex items-start gap-2">
            <Apple className="w-4 h-4 text-orange-500 flex-shrink-0 mt-0.5" />
            <span><strong>Lebensmittel</strong> vor dem Wegwerfen retten – Foodsaver-Prinzip</span>
          </div>
          <div className="flex items-start gap-2">
            <Shirt className="w-4 h-4 text-orange-500 flex-shrink-0 mt-0.5" />
            <span><strong>Kleidung & Möbel</strong> weitergeben statt entsorgen</span>
          </div>
          <div className="flex items-start gap-2">
            <Recycle className="w-4 h-4 text-orange-500 flex-shrink-0 mt-0.5" />
            <span><strong>Dinge retten</strong> verlängert Lebenszyklen und schützt die Umwelt</span>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function RescuerPage() {
  return (
    <ModulePage
      sectionLabel="§ 26 / Retter-System"
      iconBgClass="bg-orange-50 border-orange-100"
      iconColorClass="text-orange-700"
      title="Retter-System"
      description="Rette Ressourcen – Lebensmittel, Kleidung, Gegenstände sinnvoll weitergeben"
      icon={<ShieldAlert className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-orange-500 to-orange-700"
      postTypes={['rescue', 'sharing']}
      moduleFilter={[
        { type: 'rescue',  categories: ['food', 'everyday', 'sharing', 'general'] }, // Ressourcen retten
        { type: 'sharing', categories: ['food', 'everyday', 'sharing', 'general'] }, // Teilen im Retter-Kontext
      ]}
      createTypes={[
        { value: 'rescue',  label: '🧡 Ressourcen retten' },
        { value: 'sharing', label: '🟢 Hilfe anbieten'    },
      ]}
      categories={[
        { value: 'food',      label: '🍎 Lebensmittel'  },
        { value: 'everyday',  label: '👕 Kleidung'      },
        { value: 'sharing',   label: '📦 Gegenstände'   },
        { value: 'general',   label: '🌿 Sonstiges'     },
      ]}
      emptyText="Noch keine Retter-Angebote"
    >
      <RescuedTodayWidget />
    </ModulePage>
  )
}
