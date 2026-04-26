'use client'

import { useState, useEffect, lazy, Suspense } from 'react'
import { Sprout, Wheat, MapPin, ScanBarcode } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import type { FoodProduct } from '@/lib/api/foodfacts'
import FoodProductCard from '@/components/food/FoodProductCard'

const BarcodeScanner = lazy(() => import('@/components/food/BarcodeScanner'))

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
    <div className="relative bg-gradient-to-br from-primary-50 via-primary-50/80 to-lime-50 border border-primary-200 rounded-2xl p-5 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
      />
      <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
      <div className="relative flex items-center gap-2 mb-3">
        <Sprout className="w-5 h-5 text-primary-700 float-idle" />
        <h3 className="font-bold text-primary-900">Was jetzt reif ist</h3>
        <span className="ml-auto text-2xl float-idle">{curr.emoji}</span>
      </div>
      <p className="relative text-sm font-semibold text-primary-800 mb-2">{curr.label} – aktuell erntbar:</p>
      <div className="relative flex flex-wrap gap-1.5 mb-4">
        {curr.crops.map(crop => (
          <span key={crop} className="bg-white border border-primary-200 text-primary-800 text-xs font-medium px-2.5 py-1 rounded-full shadow-soft">
            🌿 {crop}
          </span>
        ))}
      </div>
      <div className="relative border-t border-primary-200 pt-3">
        <p className="text-xs text-primary-700 font-semibold mb-1">Nächsten Monat ({next.label}):</p>
        <div className="flex flex-wrap gap-1">
          {next.crops.slice(0, 3).map(crop => (
            <span key={crop} className="bg-primary-100 text-primary-600 text-xs px-2 py-0.5 rounded-full">{crop}</span>
          ))}
          {next.crops.length > 3 && <span className="text-xs text-primary-500">+{next.crops.length - 3} mehr</span>}
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
    let cancelled = false
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
    ]).then(([farmsRes, countRes]) => {
      if (cancelled) return
      if (farmsRes.error) console.error('harvest nearby farms query failed:', farmsRes.error.message)
      if (countRes.error) console.error('harvest farms count query failed:', countRes.error.message)
      setFarms(farmsRes.data ?? [])
      setTotalCount(countRes.count ?? 0)
      setLoading(false)
    }).catch(err => {
      if (cancelled) return
      console.error('harvest nearby farms load failed:', err)
      setLoading(false)
    })
    return () => { cancelled = true }
  }, [])

  return (
    <div className="relative bg-white border border-warm-200 rounded-2xl p-5 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #CA8A04, #CA8A0433)' }}
      />
      <div className="relative flex items-center gap-2 mb-3">
        <Wheat className="w-5 h-5 text-yellow-600 float-idle" />
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
              className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-warm-50 transition-all group shadow-soft border border-warm-100">
              <div className="w-8 h-8 bg-amber-100 rounded-lg flex items-center justify-center flex-shrink-0 text-sm group-hover:scale-110 transition-transform">
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
        className="relative mt-3 flex items-center justify-center gap-2 p-2 bg-gradient-to-r from-amber-50 to-yellow-50 hover:from-amber-100 hover:to-yellow-100 rounded-xl text-xs font-medium text-amber-700 transition-all shadow-soft">
        {totalCount > 0 ? `🗺️ Alle ${totalCount} Betriebe auf der Karte` : '🗺️ Alle Betriebe auf der Karte'}
      </Link>
    </div>
  )
}

// ── Erntehilfe-Regeln ─────────────────────────────────────────
function HarvestRulesWidget() {
  return (
    <div className="relative bg-white border border-warm-200 rounded-2xl p-5 pt-6 shadow-soft overflow-hidden">
      <div
        className="absolute top-0 left-0 right-0 h-[3px]"
        style={{ background: 'linear-gradient(90deg, #CA8A04, #CA8A0433)' }}
      />
      <h3 className="relative font-bold text-gray-900 mb-3 flex items-center gap-2">
        <Wheat className="w-5 h-5 text-yellow-600 float-idle" />
        Wie funktioniert Erntehilfe?
      </h3>
      <div className="relative space-y-3">
        {[
          { step: '1', title: 'Betrieb inseriert einen Einsatz', desc: 'Landwirte bieten Datum, Ort & was geerntet wird', color: 'bg-primary-100 text-primary-700' },
          { step: '2', title: 'Du meldest dein Interesse', desc: 'Klick auf "Interesse" oder direkt per Kontakt', color: 'bg-blue-100 text-blue-700' },
          { step: '3', title: 'Gemeinsam ernten', desc: 'Du hilfst und bekommst Ernteanteile als Dankeschön', color: 'bg-amber-100 text-amber-700' },
        ].map(item => (
          <div key={item.step} className="flex gap-3">
            <span className={`display-numeral w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 shadow-soft ${item.color}`}>
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

// ── Barcode-Scanner Widget ────────────────────────────────────
function FoodScannerWidget() {
  const router = useRouter()
  const [scannerOpen, setScannerOpen]   = useState(false)
  const [scannedProduct, setScannedProduct] = useState<FoodProduct | null>(null)

  const handleProduct = (p: FoodProduct) => {
    setScannedProduct(p)
    setScannerOpen(false)
  }

  const handleShare = () => {
    if (!scannedProduct) return
    const parts: string[] = []
    if (scannedProduct.brand) parts.push(`Marke: ${scannedProduct.brand}`)
    if (scannedProduct.calories != null) parts.push(`${scannedProduct.calories} kcal/100g`)
    if (scannedProduct.isVegan) parts.push('Vegan')
    else if (scannedProduct.isVegetarian) parts.push('Vegetarisch')
    const description = parts.join(' · ')
    const params = new URLSearchParams({
      title: scannedProduct.name,
      description,
      type: 'supply',
      category: 'food',
    })
    router.push(`/dashboard/create?${params}`)
  }

  return (
    <>
      <div className="relative bg-white border border-primary-100 rounded-2xl p-5 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
        />
        <div className="relative flex items-center gap-2 mb-3">
          <ScanBarcode className="w-5 h-5 text-primary-600 float-idle" />
          <h3 className="font-bold text-gray-900">Lebensmittel scannen</h3>
        </div>

        {scannedProduct ? (
          <div className="space-y-3">
            <FoodProductCard
              product={scannedProduct}
              onClose={() => setScannedProduct(null)}
              onUse={handleShare}
              shareLabel="Zum Teilen anbieten"
            />
          </div>
        ) : (
          <>
            <p className="text-sm text-gray-500 mb-3">
              Barcode scannen und Produktinfos sofort abrufen – dann direkt als Foodsharing-Post anbieten.
            </p>
            <button
              onClick={() => setScannerOpen(true)}
              className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-xl font-semibold text-sm transition-all active:scale-[0.98] shadow-soft"
            >
              <ScanBarcode className="w-4 h-4" />
              Barcode / Produkt scannen
            </button>
          </>
        )}
      </div>

      {scannerOpen && (
        <Suspense fallback={null}>
          <BarcodeScanner
            onProduct={handleProduct}
            onClose={() => setScannerOpen(false)}
          />
        </Suspense>
      )}
    </>
  )
}

// ── Haupt-Export ──────────────────────────────────────────────
export default function HarvestPage() {
  return (
    <ModulePage
      sectionLabel="§ 21 / Ernte"
      mood="fresh"
      iconBgClass="bg-lime-50 border-lime-100"
      iconColorClass="text-lime-700"
      title="Erntehilfe & Selbsternte"
      description="Helfe beim Ernten – erhalte frisches Gemüse & Obst, knüpfe Kontakte zu lokalen Betrieben"
      icon={<Sprout className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-lime-600 to-green-700"
      postTypes={['supply', 'rescue']}
      moduleFilter={[
        { type: 'supply' },                                                                          // ALLE supply-Posts
        { type: 'rescue', categories: ['food', 'general', 'sharing', 'everyday', 'community'] },    // Helfer für alle Ernte-Kategorien
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
      examplePosts={[
        { emoji: '🍅', title: 'Tomaten vom Garten zu verschenken', description: 'Habe dieses Jahr eine reiche Ernte – gebe gerne Tomaten, Zucchini und Kräuter ab. Abholung bei mir im Garten.', type: 'supply', category: 'food' },
        { emoji: '🌾', title: 'Suche Helfer für Apfelernte', description: 'Unser alter Apfelbaum trägt dieses Jahr besonders viel. Wer hilft beim Ernten, bekommt einen Teil der Äpfel.', type: 'rescue', category: 'food' },
        { emoji: '🥬', title: 'Gemüsekiste teilen – wer macht mit?', description: 'Ich bestelle regelmäßig eine Bio-Gemüsekiste. Hat jemand Interesse, die Kosten und Menge zu teilen?', type: 'supply', category: 'food' },
      ]}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SeasonWidget />
        <NearbyFarmsWidget />
        <div className="md:col-span-2">
          <FoodScannerWidget />
        </div>
      </div>
      <HarvestRulesWidget />
    </ModulePage>
  )
}
