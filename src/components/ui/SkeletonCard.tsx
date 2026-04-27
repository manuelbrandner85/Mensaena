'use client'

/**
 * Content-aware skeleton cards — each mirrors the visual structure of its
 * corresponding real card so the layout doesn't jump when data arrives.
 */

function S({ className }: { className: string }) {
  return <div className={`skeleton ${className}`} aria-hidden="true" />
}

/** Mirrors FarmCard (supply page grid) */
export function SupplyCardSkeleton() {
  return (
    <div className="bg-white rounded-2xl border border-stone-100 overflow-hidden flex flex-col" aria-hidden="true">
      {/* Header gradient area */}
      <div className="bg-gradient-to-br from-stone-50 to-stone-100 px-5 pt-5 pb-4">
        <div className="flex items-start justify-between gap-3">
          <div className="flex-1 space-y-2">
            <div className="flex gap-2">
              <S className="h-5 w-20 rounded-full" />
              <S className="h-5 w-12 rounded-full" />
            </div>
            <S className="skeleton-title w-3/4" />
            <S className="skeleton-text w-1/2" />
          </div>
          <S className="w-8 h-8 rounded-xl flex-shrink-0" />
        </div>
      </div>
      {/* Body */}
      <div className="px-5 py-3 flex-1 space-y-3">
        <S className="skeleton-text w-full" />
        <S className="skeleton-text w-5/6" />
        <div className="flex gap-1.5">
          <S className="h-5 w-16 rounded-full" />
          <S className="h-5 w-16 rounded-full" />
          <S className="h-5 w-16 rounded-full" />
        </div>
      </div>
      {/* Footer */}
      <div className="px-5 py-3 border-t border-stone-100 flex justify-between">
        <div className="flex gap-3">
          <S className="w-4 h-4 rounded-full" />
          <S className="w-4 h-4 rounded-full" />
          <S className="h-4 w-10" />
        </div>
        <S className="h-4 w-16" />
      </div>
    </div>
  )
}

/** Mirrors marketplace item card */
export function MarketplaceCardSkeleton() {
  return (
    <div className="bg-white rounded-2xl border border-stone-100 shadow-soft overflow-hidden flex flex-col" aria-hidden="true">
      {/* Image area */}
      <S className="h-40 w-full rounded-none" />
      {/* Content */}
      <div className="p-4 space-y-2 flex-1">
        <S className="skeleton-title w-3/4" />
        <S className="skeleton-text w-1/2" />
        <S className="skeleton-text w-2/3" />
      </div>
      {/* Footer */}
      <div className="px-4 pb-4 flex justify-between items-center">
        <S className="h-6 w-16 rounded-full" />
        <S className="h-6 w-20 rounded-xl" />
      </div>
    </div>
  )
}

/** Mirrors a list row (timebank entries, notifications, etc.) */
export function ListItemSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="divide-y divide-stone-100" role="status" aria-label="Laden...">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 py-4 px-5" aria-hidden="true">
          <S className="w-9 h-9 rounded-full flex-shrink-0" />
          <div className="flex-1 space-y-2">
            <S className="skeleton-text w-1/3" />
            <S className="skeleton-sm w-1/2" />
          </div>
          <S className="h-5 w-16 rounded-full flex-shrink-0" />
        </div>
      ))}
      <span className="sr-only">Laden...</span>
    </div>
  )
}

/** 2-column stat card skeleton (for dashboard widgets) */
export function StatCardSkeleton() {
  return (
    <div className="bg-white rounded-2xl border border-stone-100 p-5 space-y-3" aria-hidden="true">
      <div className="flex justify-between items-start">
        <S className="w-9 h-9 rounded-xl" />
        <S className="h-5 w-12 rounded-full" />
      </div>
      <S className="skeleton-title w-1/3" />
      <S className="skeleton-text w-2/3" />
    </div>
  )
}
