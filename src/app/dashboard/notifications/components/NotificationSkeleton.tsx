'use client'

import Skeleton from '@/components/ui/Skeleton'

export default function NotificationSkeleton() {
  return (
    <div className="space-y-4">
      {/* Filter skeleton */}
      <div className="flex gap-2 overflow-hidden">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} variant="rect" className="!h-9 !w-24 !rounded-full flex-shrink-0" />
        ))}
      </div>

      {/* List skeleton */}
      <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="flex gap-3 px-4 py-3 border-b border-gray-50 last:border-0">
            <Skeleton variant="round" className="!w-10 !h-10 flex-shrink-0" />
            <div className="flex-1 space-y-2">
              <Skeleton variant="rect" className="!h-4 !w-48" />
              <Skeleton variant="rect" className="!h-3 !w-full" />
              <Skeleton variant="rect" className="!h-3 !w-16" />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
