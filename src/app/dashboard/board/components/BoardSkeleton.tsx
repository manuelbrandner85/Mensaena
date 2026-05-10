'use client'

import { cn } from '@/lib/utils'

export default function BoardSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="columns-1 sm:columns-2 lg:columns-3 gap-4 space-y-4">
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          className={cn(
            'break-inside-avoid rounded-xl border p-4 animate-pulse',
            i % 3 === 0 ? 'bg-mn-surface border-white/8' : '',
            i % 3 === 1 ? 'bg-mn-surface border-white/5' : '',
            i % 3 === 2 ? 'bg-mn-surface border-white/5' : '',
          )}
        >
          {/* Category badge */}
          <div className="flex items-center gap-2 mb-3">
            <div className="h-5 w-20 rounded-full bg-mn-raised" />
            <div className="h-5 w-16 rounded-full bg-mn-raised" />
          </div>
          {/* Content */}
          <div className="space-y-2 mb-3">
            <div className="h-4 w-full rounded bg-mn-raised" />
            <div className="h-4 w-4/5 rounded bg-mn-raised" />
            <div className="h-4 w-3/5 rounded bg-mn-raised" />
          </div>
          {/* Image placeholder (sometimes) */}
          {i % 2 === 0 && (
            <div className="h-32 w-full rounded-lg bg-mn-raised mb-3" />
          )}
          {/* Footer */}
          <div className="flex items-center justify-between mt-3 pt-3 border-t border-white/5">
            <div className="flex items-center gap-2">
              <div className="h-6 w-6 rounded-full bg-mn-raised" />
              <div className="h-3 w-16 rounded bg-mn-raised" />
            </div>
            <div className="flex items-center gap-3">
              <div className="h-4 w-8 rounded bg-mn-raised" />
              <div className="h-4 w-8 rounded bg-mn-raised" />
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
