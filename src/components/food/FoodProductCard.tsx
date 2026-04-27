'use client'

import Image from 'next/image'
import { AlertTriangle, Leaf, Sprout, Share2, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  type FoodProduct,
  type ScoreGrade,
  NUTRISCORE_COLOR,
  ECOSCORE_COLOR,
} from '@/lib/api/foodfacts'

// ── Score Badge ────────────────────────────────────────────────

function ScoreBadge({
  label,
  grade,
  colors,
}: {
  label: string
  grade: ScoreGrade
  colors: Record<ScoreGrade, string>
}) {
  const all: ScoreGrade[] = ['a', 'b', 'c', 'd', 'e']
  const activeIdx = all.indexOf(grade)

  return (
    <div className="flex flex-col items-center gap-1">
      <span className="text-xs font-bold text-ink-400 uppercase tracking-wider">{label}</span>
      <div className="flex gap-0.5 items-end">
        {all.map((g, i) => {
          const isActive = i === activeIdx
          const height = isActive ? 'h-7' : 'h-5'
          return (
            <div
              key={g}
              className={cn(
                'w-5 rounded-sm flex items-center justify-center transition-all',
                height,
                isActive ? 'opacity-100' : 'opacity-30',
              )}
              style={{ backgroundColor: colors[g] }}
              aria-label={isActive ? `${label} ${g.toUpperCase()} (aktiv)` : undefined}
            >
              {isActive && (
                <span className="text-white text-[11px] font-black leading-none">
                  {g.toUpperCase()}
                </span>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ── Nutriment mini-bar ─────────────────────────────────────────

function NutrimentBar({
  label,
  value,
  unit = 'g',
  max,
  color,
}: {
  label: string
  value: number
  unit?: string
  max: number
  color: string
}) {
  const pct = Math.min(100, (value / max) * 100)
  return (
    <div className="flex flex-col gap-1">
      <div className="flex justify-between items-baseline">
        <span className="text-[11px] text-ink-500">{label}</span>
        <span className="text-[11px] font-semibold text-ink-700 tabular-nums">
          {value}{unit}
        </span>
      </div>
      <div className="h-1.5 bg-stone-100 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
    </div>
  )
}

// ── Props ──────────────────────────────────────────────────────

export interface FoodProductCardProps {
  product: FoodProduct
  /** Allergene des Users (aus Profil) – werden rot hervorgehoben */
  userAllergens?: string[]
  onUse?: () => void
  onClose?: () => void
  shareLabel?: string
}

// ── Main Component ─────────────────────────────────────────────

export default function FoodProductCard({
  product,
  userAllergens = [],
  onUse,
  onClose,
  shareLabel = 'Dieses Produkt teilen',
}: FoodProductCardProps) {
  const {
    name, brand, imageUrl, nutriScore, ecoScore,
    allergens, isVegan, isVegetarian,
    calories, fat, sugar, salt,
  } = product

  // Allergen-Warnung: Überschneidung User ↔ Produkt
  const userAllergenSet = new Set(
    userAllergens.map(a => a.toLowerCase()),
  )
  const warnings = allergens.filter(a => userAllergenSet.has(a.toLowerCase()))
  const hasPersonalWarning = warnings.length > 0

  return (
    <div className="bg-white dark:bg-ink-900 rounded-2xl border border-stone-100 dark:border-ink-800 shadow-soft overflow-hidden w-full">

      {/* Top: image + name */}
      <div className="relative flex gap-4 p-4 pb-3">
        {onClose && (
          <button
            onClick={onClose}
            className="absolute top-3 right-3 w-7 h-7 rounded-full bg-stone-100 dark:bg-ink-800 flex items-center justify-center text-ink-400 hover:text-ink-700 dark:hover:text-white transition-colors"
            aria-label="Schließen"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}

        {/* Produktbild */}
        <div className="w-20 h-20 rounded-xl bg-stone-50 dark:bg-ink-800 flex-shrink-0 overflow-hidden border border-stone-100 dark:border-ink-700">
          {imageUrl ? (
            <Image
              src={imageUrl}
              alt={name}
              width={80}
              height={80}
              className="w-full h-full object-contain p-1"
              unoptimized
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-3xl">🍽️</div>
          )}
        </div>

        {/* Name + Brand + Badges */}
        <div className="flex-1 min-w-0 pr-6">
          <h3 className="font-bold text-ink-900 dark:text-white text-sm leading-snug line-clamp-2">{name}</h3>
          {brand && (
            <p className="text-xs text-ink-500 dark:text-ink-400 mt-0.5">{brand}</p>
          )}
          <div className="flex flex-wrap gap-1.5 mt-2">
            {isVegan && (
              <span className="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400">
                <Leaf className="w-2.5 h-2.5" /> Vegan
              </span>
            )}
            {!isVegan && isVegetarian && (
              <span className="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full bg-lime-100 text-lime-700 dark:bg-lime-900/40 dark:text-lime-400">
                <Sprout className="w-2.5 h-2.5" /> Vegetarisch
              </span>
            )}
            <span className="text-xs text-ink-400 px-2 py-0.5 rounded-full bg-stone-100 dark:bg-ink-800 font-mono">
              {product.barcode}
            </span>
          </div>
        </div>
      </div>

      {/* Personal allergen warning */}
      {hasPersonalWarning && (
        <div className="mx-4 mb-3 flex items-start gap-2 px-3 py-2.5 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl"
          role="alert"
          aria-live="assertive"
        >
          <AlertTriangle className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
          <p className="text-xs font-semibold text-red-700 dark:text-red-400">
            Achtung: Enthält{' '}
            {warnings.join(', ')}
            {' '}– du hast diese Allergien in deinem Profil angegeben.
          </p>
        </div>
      )}

      {/* Nutri/Eco Scores */}
      {(nutriScore || ecoScore) && (
        <div className="px-4 py-3 border-t border-stone-100 dark:border-ink-800 flex items-center gap-6">
          {nutriScore && (
            <ScoreBadge label="Nutri-Score" grade={nutriScore} colors={NUTRISCORE_COLOR} />
          )}
          {ecoScore && (
            <ScoreBadge label="Eco-Score" grade={ecoScore} colors={ECOSCORE_COLOR} />
          )}
        </div>
      )}

      {/* Allergens */}
      {allergens.length > 0 && (
        <div className="px-4 py-3 border-t border-stone-100 dark:border-ink-800">
          <p className="text-[11px] font-bold text-ink-500 uppercase tracking-wider mb-2">
            Enthält:
          </p>
          <div className="flex flex-wrap gap-1.5" aria-label="Allergene">
            {allergens.map(a => {
              const isWarning = userAllergenSet.has(a.toLowerCase())
              return (
                <span
                  key={a}
                  className={cn(
                    'text-xs font-semibold px-2.5 py-1 rounded-full',
                    isWarning
                      ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400 ring-1 ring-red-300'
                      : 'bg-orange-50 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400',
                  )}
                >
                  {isWarning && '⚠️ '}
                  {a}
                </span>
              )
            })}
          </div>
        </div>
      )}

      {/* Nutriments */}
      {(calories != null || fat != null || sugar != null || salt != null) && (
        <div className="px-4 py-3 border-t border-stone-100 dark:border-ink-800">
          <p className="text-[11px] font-bold text-ink-500 uppercase tracking-wider mb-3">
            Nährwerte (pro 100g)
          </p>
          <div className="grid grid-cols-2 gap-x-6 gap-y-2.5">
            {calories != null && (
              <NutrimentBar label="Kalorien" value={calories} unit=" kcal" max={500} color="#F97316" />
            )}
            {fat != null && (
              <NutrimentBar label="Fett" value={fat} unit="g" max={30} color="#EF4444" />
            )}
            {sugar != null && (
              <NutrimentBar label="Zucker" value={sugar} unit="g" max={25} color="#A855F7" />
            )}
            {salt != null && (
              <NutrimentBar label="Salz" value={salt} unit="g" max={2.5} color="#3B82F6" />
            )}
          </div>
        </div>
      )}

      {/* Share button */}
      {onUse && (
        <div className="px-4 pb-4 pt-3 border-t border-stone-100 dark:border-ink-800">
          <button
            onClick={onUse}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-xl font-semibold text-sm transition-all active:scale-[0.98] shadow-soft"
          >
            <Share2 className="w-4 h-4" />
            {shareLabel}
          </button>
        </div>
      )}
    </div>
  )
}
