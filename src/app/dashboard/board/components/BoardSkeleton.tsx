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
            i % 3 === 0 ? 'bg-yellow-50 border-yellow-200' : '',
            i % 3 === 1 ? 'bg-green-50 border-green-200' : '',
            i % 3 === 2 ? 'bg-blue-50 border-blue-200' : '',
          )}
        >
          {/* Category badge */}
          <div className="flex items-center gap-2 mb-3">
            <div className="h-5 w-20 rounded-full bg-gray-200" />
            <div className="h-5 w-16 rounded-full bg-gray-200" />
          </div>
          {/* Content */}
          <div className="space-y-2 mb-3">
            <div className="h-4 w-full rounded bg-gray-200" />
            <div className="h-4 w-4/5 rounded bg-gray-200" />
            <div className="h-4 w-3/5 rounded bg-gray-200" />
          </div>
          {/* Image placeholder (sometimes) */}
          {i % 2 === 0 && (
            <div className="h-32 w-full rounded-lg bg-gray-200 mb-3" />
          )}
          {/* Footer */}
          <div className="flex items-center justify-between mt-3 pt-3 border-t border-gray-200">
            <div className="flex items-center gap-2">
              <div className="h-6 w-6 rounded-full bg-gray-200" />
              <div className="h-3 w-16 rounded bg-gray-200" />
            </div>
            <div className="flex items-center gap-3">
              <div className="h-4 w-8 rounded bg-gray-200" />
              <div className="h-4 w-8 rounded bg-gray-200" />
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
