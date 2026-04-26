'use client'

import { useState, useEffect } from 'react'
import { ShieldAlert, Package, Shirt, Apple, Recycle, AlertTriangle } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'

// ── Gerettete Ressourcen Widget ─────────────────────────────────
function RescuedTodayWidget() {
  const [stats, setStats] = useState({ food: 0, clothes: 0, items: 0, total: 0 })
  const [oldFoodCount, setOldFoodCount] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      const { data, error } = await supabase.from('posts')
        .select('category,status,created_at')
        .eq('type', 'rescue')
        .in('status', ['active', 'fulfilled'])
      if (cancelled) return
      if (error) console.error('rescuer stats query failed:', error.message)

      const all = data ?? []
      const active = all.filter(p => p.status === 'active')
      const threeDaysAgo = Date.now() - 3 * 24 * 60 * 60 * 1000
      const oldFood = active.filter(p =>
        p.category === 'food' && new Date(p.created_at).getTime() < threeDaysAgo
      )
      setStats({
        food:    active.filter(p => p.category === 'food').length,
        clothes: active.filter(p => p.category === 'everyday').length,
        items:   active.filter(p => p.category === 'sharing').length,
        total:   all.filter(p => p.status === 'fulfilled').length,  // total fulfilled = gerettet
      })
      setOldFoodCount(oldFood.length)
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="h-24 bg-orange-50 rounded-2xl animate-pulse border border-orange-200" />
  }

  return (
    <div className="space-y-4">
      {/* Ablaufdatum-Warnung für Lebensmittel */}
      {oldFoodCount > 0 && (
        <div className="relative flex items-start gap-3 p-4 bg-gradient-to-br from-amber-50 via-amber-50/80 to-orange-50 border-2 border-amber-200 rounded-2xl shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #F59E0B, #F59E0B33)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <AlertTriangle className="relative w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
          <div className="relative flex-1">
            <p className="text-sm font-bold text-amber-800">
              <span className="display-numeral">{oldFoodCount}</span> Lebensmittelangebot{oldFoodCount !== 1 ? 'e' : ''} möglicherweise abgelaufen
            </p>
            <p className="text-xs text-amber-700 mt-0.5">
              Älter als 3 Tage – bitte prüfen und ggf. als erledigt markieren.
            </p>
          </div>
        </div>
      )}

      {/* Ressourcen-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { icon: Apple,   label: 'Lebensmittel',     value: stats.food,    accent: '#C62828' },
          { icon: Shirt,   label: 'Kleidung',         value: stats.clothes, accent: '#3B82F6' },
          { icon: Package, label: 'Gegenstände',      value: stats.items,   accent: '#F59E0B' },
          { icon: Recycle, label: 'Gesamt gerettet',  value: stats.total,   accent: '#1EAAA6' },
        ].map(s => {
          const Icon = s.icon
          return (
            <div
              key={s.label}
              className="relative flex flex-col items-center p-3 rounded-2xl bg-white border border-stone-100 shadow-soft hover:shadow-card transition-shadow overflow-hidden"
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
              <p className="display-numeral text-xl font-bold text-ink-900 tabular-nums">{s.value}</p>
              <p className="text-xs text-ink-500 text-center leading-tight">{s.label}</p>
            </div>
          )
        })}
      </div>

      {/* Mission-Statement */}
      <div className="relative bg-gradient-to-br from-orange-50 via-orange-50/80 to-amber-50 border border-orange-200 rounded-2xl p-4 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #F97316, #F9731633)' }}
        />
        <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
        <p className="relative text-sm font-bold text-orange-800 mb-2">🧡 Warum Ressourcen retten?</p>
        <div className="relative grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs text-orange-900">
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
      mood="calm"
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
      examplePosts={[
        { emoji: '🍞', title: 'Bäckerei gibt Brot ab – wer holt ab?', description: 'Meine Stammbäckerei hat abends oft Brot übrig und gibt es gerne weiter statt wegzuwerfen. Wer kann kurzfristig abholen?', type: 'rescue', category: 'food' },
        { emoji: '👕', title: 'Kleiderspenden sortieren – Helfer gesucht', description: 'Unser Kleiderschrank quillt über. Suche 2–3 Leute, die beim Sortieren für Sozialkaufhaus helfen. Kaffee + Kuchen inklusive.', type: 'sharing', category: 'everyday' },
        { emoji: '🪴', title: 'Möbel vor Sperrmüll retten', description: 'Bei den Nachbarn stehen noch brauchbare Möbel auf der Straße. Wer braucht Regal, Stuhl oder Tisch? Bitte melden.', type: 'rescue', category: 'sharing' },
      ]}
    >
      <RescuedTodayWidget />
    </ModulePage>
  )
}
