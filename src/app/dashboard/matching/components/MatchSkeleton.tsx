'use client'

export default function MatchSkeleton() {
  return (
    <div className="space-y-4">
      {/* Stats skeleton */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="bg-white rounded-xl border border-gray-100 p-4 animate-pulse">
            <div className="h-3 w-16 bg-gray-200 rounded mb-2" />
            <div className="h-7 w-10 bg-gray-200 rounded" />
          </div>
        ))}
      </div>

      {/* Filter tabs skeleton */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {[1, 2, 3, 4, 5].map((i) => (
          <div key={i} className="h-8 w-24 bg-gray-200 rounded-full animate-pulse flex-shrink-0" />
        ))}
      </div>

      {/* Card skeletons */}
      {[1, 2, 3].map((i) => (
        <div
          key={i}
          className="bg-white rounded-xl border border-gray-100 p-4 animate-pulse"
        >
          <div className="flex items-start gap-3">
            {/* Score circle */}
            <div className="w-14 h-14 rounded-full bg-gray-200 flex-shrink-0" />
            {/* Content */}
            <div className="flex-1 space-y-2">
              <div className="h-4 w-3/4 bg-gray-200 rounded" />
              <div className="h-3 w-1/2 bg-gray-200 rounded" />
              <div className="flex gap-2">
                <div className="h-5 w-16 bg-gray-200 rounded-full" />
                <div className="h-5 w-20 bg-gray-200 rounded-full" />
              </div>
            </div>
          </div>
          {/* Bottom actions */}
          <div className="flex items-center gap-2 mt-4 pt-3 border-t border-gray-50">
            <div className="flex gap-2 ml-auto">
              <div className="h-8 w-20 bg-gray-200 rounded-lg" />
              <div className="h-8 w-20 bg-gray-200 rounded-lg" />
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}

export function MatchCardSkeleton() {
  return (
    <div className="bg-white rounded-xl border border-gray-100 p-4 animate-pulse">
      <div className="flex items-start gap-3">
        <div className="w-14 h-14 rounded-full bg-gray-200 flex-shrink-0" />
        <div className="flex-1 space-y-2">
          <div className="h-4 w-3/4 bg-gray-200 rounded" />
          <div className="h-3 w-1/2 bg-gray-200 rounded" />
        </div>
      </div>
    </div>
  )
}
