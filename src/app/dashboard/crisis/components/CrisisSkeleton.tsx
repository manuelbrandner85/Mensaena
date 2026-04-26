'use client'

import { cn } from '@/lib/utils'

export default function CrisisSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="space-y-4" aria-label="Krisen werden geladen..." role="status">
      {/* Stats skeleton */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[0, 1, 2, 3].map(i => (
          <div key={i} className="h-24 rounded-2xl animate-pulse bg-stone-100 border border-stone-200" />
        ))}
      </div>

      {/* Cards skeleton */}
      <div className="space-y-3">
        {Array.from({ length: count }).map((_, i) => (
          <div
            key={i}
            className="rounded-2xl border border-stone-200 p-4 animate-pulse"
            style={{ animationDelay: `${i * 100}ms` }}
          >
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-full bg-stone-200 flex-shrink-0" />
              <div className="flex-1 space-y-2">
                <div className="flex items-center gap-2">
                  <div className="h-5 w-16 bg-stone-200 rounded-full" />
                  <div className="h-5 w-20 bg-stone-200 rounded-full" />
                </div>
                <div className="h-5 w-3/4 bg-stone-200 rounded" />
                <div className="h-4 w-full bg-stone-100 rounded" />
                <div className="h-4 w-2/3 bg-stone-100 rounded" />
                <div className="flex items-center gap-4 mt-3">
                  <div className="h-4 w-24 bg-stone-100 rounded" />
                  <div className="h-4 w-20 bg-stone-100 rounded" />
                  <div className="h-4 w-16 bg-stone-100 rounded" />
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
