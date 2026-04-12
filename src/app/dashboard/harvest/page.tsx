'use client'

import { useState, useEffect } from 'react'
import { Sprout, Wheat, MapPin } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Monatsgenaue Erntedaten ────────────────────────────────────
const MONTHLY_HARVEST: Record<number, { emoji: string; label: string; crops: string[] }> = {
  0:  { emoji: '❄️', label: 'Januar',    crops: ['Feldsalat', 'Grünkohl', 'Rosenkohl', 'Pastinaken', 'Lauch'] },
  1:  { emoji: '❄️', label: 'Februar',   crops: ['Feldsalat', 'Grünkohl', 'Chicorée', 'Rüben', 'Pastinaken'] },
  2:  { emoji: '🌱', label: 'März',      crops: ['Bärlauch', 'Spinat', 'Radieschen', 'Frühlingszwiebeln'] },
  3:  { emoji: '🌱', label: 'April',     crops: ['Spinat', 'Radieschen', 'Salat', 'Rhabarber', 'Kohlrabi'] },
  4:  { emoji: '🌸', label: 'Mai',       crops: ['Spargel', 'Salat', 'Erdbeeren', 'Erbsen', 'Radieschen'] },
  5:  { emoji: '☀️', label: 'Juni',      crops: ['Erdbeeren', 'Kirschen', 'Erbsen', 'Zucchini', 'Salat'] },
  6:  { emoji: '☀️', label: 'Juli',      crops: ['Tomaten', 'Gurken', 'Zucchini', 'Himbeeren', 'Bohnen'] },
  7:  { emoji: '🌻', label: 'August',    crops: ['Tomaten', 'Paprika', 'Melonen', 'Mais', 'Pflaumen'] },
  8:  { emoji: '🍂', label: 'September', crops: ['Äpfel', 'Birnen', 'Kürbis', 'Kartoffeln', 'Trauben'] },
  9:  { emoji: '🍂', label: 'Oktober',   crops: ['Kürbis', 'Äpfel', 'Zwiebeln', 'Rote Bete', 'Nüsse'] },
  10: { emoji: '🍂', label: 'November',  crops: ['Grünkohl', 'Rosenkohl', 'Pastinaken', 'Rüben', 'Lauch'] },
  11: { emoji: '❄️', label: 'Dezember',  crops: ['Grünkohl', 'Rosenkohl', 'Feldsalat', 'Chicorée', 'Lauch'] },
}

function SeasonWidget() {
  const m = new Date().getMonth()
  const curr = MONTHLY_HARVEST[m]
  const next = MONTHLY_HARVEST[(m + 1) % 12]

  return (
    <div className="bg-gradient-to-br from-green-50 to-lime-50 border border-green-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-3">
        <Sprout className="w-5 h-5 text-green-700" />
        <h3 className="font-bold text-green-900">Was jetzt reif ist</h3>
        <span className="ml-auto text-2xl">{curr.emoji}</span>
      </div>
      <p className="text-sm font-semibold text-green-800 mb-2">{curr.label} – aktuell erntbar:</p>
      <div className="flex flex-wrap gap-1.5 mb-4">
        {curr.crops.map(crop => (
          <span key={crop} className="bg-white border border-green-200 text-green-800 text-xs font-medium px-2.5 py-1 rounded-full">
            🌿 {crop}
          </span>
        ))}
      </div>
      <div className="border-t border-green-200 pt-3">
        <p className="text-xs text-green-700 font-semibold mb-1">Nächsten Monat ({next.label}):</p>
        <div className="flex flex-wrap gap-1">
          {next.crops.slice(0, 3).map(crop => (
            <span key={crop} className="bg-green-100 text-green-600 text-xs px-2 py-0.5 rounded-full">{crop}</span>
          ))}
          {next.crops.length > 3 && <span className="text-xs text-green-500">+{next.crops.length - 3} mehr</span>}
        </div>
      </div>
    </div>
  )
}

// ── Betriebe in der Nähe (aus farm_listings) ──────────────────
function NearbyFarmsWidget() {
  const [farms, setFarms]   = useState<{ id: string; name: string; city: string; category: string; slug: string }[]>([])
  const [totalCount, setTotalCount] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    Promise.all([
      supabase.from('farm_listings')
        .select('id,name,city,category,slug')
        .eq('is_public', true)
        .in('category', ['Bauernhof', 'Hofladen', 'Direktvermarktung', 'Selbsternte', 'Biohof'])
        .order('is_verified', { ascending: false })
        .limit(4),
      supabase.from('farm_listings')
        .select('id', { count: 'exact', head: true })
        .eq('is_public', true),
    ]).then(([{ data }, { count }]) => {
      setFarms(data ?? [])
      setTotalCount(count ?? 0)
      setLoading(false)
    })
  }, [])

  return (
    <div className="bg-white border border-warm-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-3">
        <Wheat className="w-5 h-5 text-yellow-600" />
        <h3 className="font-bold text-gray-900">Betriebe in der Nähe</h3>
        <Link href="/dashboard/supply" className="ml-auto text-xs text-primary-600 hover:underline">Alle →</Link>
      </div>
      {loading ? (
        <div className="space-y-2">
          {[0,1,2].map(i => <div key={i} className="h-10 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : farms.length === 0 ? (
        <p className="text-sm text-gray-400 text-center py-4">Keine Betriebe gefunden</p>
      ) : (
        <div className="space-y-2">
          {farms.map(f => (
            <Link key={f.id} href={`/dashboard/supply/farm/${f.slug}`}
              className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-warm-50 transition-all group">
              <div className="w-8 h-8 bg-amber-100 rounded-lg flex items-center justify-center flex-shrink-0 text-sm">
                {f.category === 'Biohof' ? '🌿' : f.category === 'Selbsternte' ? '🫑' : '🏡'}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate group-hover:text-primary-700">{f.name}</p>
                <p className="text-xs text-gray-500 flex items-center gap-1">
                  <MapPin className="w-2.5 h-2.5" /> {f.city}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
      <Link href="/dashboard/supply"
        className="mt-3 flex items-center justify-center gap-2 p-2 bg-amber-50 hover:bg-amber-100 rounded-xl text-xs font-medium text-amber-700 transition-all">
        {totalCount > 0 ? `🗺️ Alle ${totalCount} Betriebe auf der Karte` : '🗺️ Alle Betriebe auf der Karte'}
      </Link>
    </div>
  )
}

// ── Erntehilfe-Regeln ─────────────────────────────────────────
function HarvestRulesWidget() {
  return (
    <div className="bg-white border border-warm-200 rounded-2xl p-5">
      <h3 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
        <Wheat className="w-5 h-5 text-yellow-600" />
        Wie funktioniert Erntehilfe?
      </h3>
      <div className="space-y-3">
        {[
          { step: '1', title: 'Betrieb inseriert einen Einsatz', desc: 'Landwirte bieten Datum, Ort & was geerntet wird', color: 'bg-green-100 text-green-700' },
          { step: '2', title: 'Du meldest dein Interesse', desc: 'Klick auf "Interesse" oder direkt per Kontakt', color: 'bg-blue-100 text-blue-700' },
          { step: '3', title: 'Gemeinsam ernten', desc: 'Du hilfst und bekommst Ernteanteile als Dankeschön', color: 'bg-amber-100 text-amber-700' },
        ].map(item => (
          <div key={item.step} className="flex gap-3">
            <span className={`w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 ${item.color}`}>
              {item.step}
            </span>
            <div>
              <p className="text-sm font-semibold text-gray-800">{item.title}</p>
              <p className="text-xs text-gray-500 mt-0.5">{item.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ── Haupt-Export ──────────────────────────────────────────────
export default function HarvestPage() {
  return (
    <ModulePage
      title="Erntehilfe & Selbsternte"
      description="Helfe beim Ernten – erhalte frisches Gemüse & Obst, knüpfe Kontakte zu lokalen Betrieben"
      icon={<Sprout className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-lime-600 to-green-700"
      postTypes={['supply', 'rescue']}
      moduleFilter={[
        { type: 'supply' },                                           // ALLE supply-Posts
        { type: 'rescue', categories: ['food'] },                     // Helfer für Ernte gesucht
      ]}
      createTypes={[
        { value: 'supply',  label: '🌾 Ernte/Versorgung anbieten' },
        { value: 'rescue',  label: '🔴 Helfer gesucht'            },
      ]}
      categories={[
        { value: 'food',      label: '🍎 Obst & Gemüse'      },
        { value: 'general',   label: '🌿 Kräuter & Wildpfl.'  },
        { value: 'sharing',   label: '🐝 Imkerei & Honig'    },
        { value: 'everyday',  label: '🥚 Tiere & Erzeugnisse' },
        { value: 'community', label: '👥 Gemeinschaftsgarten' },
      ]}
      emptyText="Noch keine Erntehilfe-Angebote"
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SeasonWidget />
        <NearbyFarmsWidget />
      </div>
      <HarvestRulesWidget />
    </ModulePage>
  )
}
