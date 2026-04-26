'use client'

import dynamic from 'next/dynamic'
import { ArrowLeft, ShieldAlert } from 'lucide-react'
import Link from 'next/link'

const NinaWarningBanner = dynamic(() => import('@/components/dashboard/NinaWarningBanner'), { ssr: false })
const WeatherAlertBanner = dynamic(() => import('@/components/warnings/WeatherAlertBanner'), { ssr: false })
const WaterLevelWidget = dynamic(() => import('@/components/water/WaterLevelWidget'), { ssr: false })

const FoodWarningFeed = dynamic(
  () => import('@/components/warnings/FoodWarningFeed'),
  {
    ssr: false,
    loading: () => (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <div
            key={i}
            className="rounded-2xl border border-stone-200 dark:border-stone-700 bg-white dark:bg-stone-900 overflow-hidden animate-pulse"
          >
            <div className="aspect-[16/9] bg-stone-100 dark:bg-stone-800" />
            <div className="p-4 space-y-2">
              <div className="h-4 w-3/4 bg-stone-200 dark:bg-stone-700 rounded" />
              <div className="h-3 w-1/2 bg-stone-200 dark:bg-stone-700 rounded" />
              <div className="h-3 w-full bg-stone-200 dark:bg-stone-700 rounded" />
            </div>
          </div>
        ))}
      </div>
    ),
  },
)

export default function WarnungenPage() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 py-6">
      <div className="mb-6">
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-1.5 text-sm text-stone-500 dark:text-stone-400 hover:text-stone-700 dark:hover:text-stone-200 transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" aria-hidden="true" />
          Zurück zum Dashboard
        </Link>

        <div className="flex items-start gap-3">
          <div className="flex-shrink-0 rounded-2xl bg-orange-100 dark:bg-orange-900/40 text-orange-700 dark:text-orange-200 p-3">
            <ShieldAlert className="w-6 h-6" aria-hidden="true" />
          </div>
          <div className="flex-1 min-w-0">
            <h1 className="text-2xl font-bold text-stone-900 dark:text-stone-50">
              Lebensmittel- &amp; Produktwarnungen
            </h1>
            <p className="text-sm text-stone-600 dark:text-stone-300 mt-1">
              Aktuelle Rückrufe und Warnungen aus dem offiziellen
              Verbraucherschutz-Portal der Bundesländer.
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-4 mb-6">
        <NinaWarningBanner />
        <WeatherAlertBanner />
        <WaterLevelWidget />
      </div>

      <FoodWarningFeed initialLimit={5} loadMoreStep={10} />

      <p className="mt-8 text-xs text-stone-400 dark:text-stone-500 text-center">
        Quelle: lebensmittelwarnung.de · Bayerisches Staatsministerium für Umwelt
        und Verbraucherschutz · Daten ohne Gewähr.
      </p>
    </div>
  )
}
