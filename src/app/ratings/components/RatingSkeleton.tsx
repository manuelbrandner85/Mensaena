'use client'

export default function RatingSkeleton() {
  return (
    <div className="space-y-4 animate-pulse">
      {/* Trust score skeleton */}
      <div className="bg-white rounded-2xl shadow-sm p-6 space-y-4">
        <div className="h-5 w-40 bg-gray-200 rounded" />
        <div className="flex items-center gap-6">
          <div className="flex flex-col items-center gap-2">
            <div className="h-12 w-16 bg-gray-200 rounded" />
            <div className="flex gap-1">
              {[1, 2, 3, 4, 5].map(i => (
                <div key={i} className="w-4 h-4 bg-gray-200 rounded" />
              ))}
            </div>
            <div className="h-3 w-24 bg-gray-100 rounded" />
          </div>
          <div className="flex-1 space-y-2">
            {[5, 4, 3, 2, 1].map(i => (
              <div key={i} className="flex items-center gap-2">
                <div className="w-3 h-3 bg-gray-200 rounded" />
                <div className="flex-1 h-2 bg-gray-100 rounded-full" />
              </div>
            ))}
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="h-16 bg-gray-100 rounded-xl" />
          <div className="h-16 bg-gray-100 rounded-xl" />
        </div>
      </div>

      {/* Rating list skeleton */}
      <div className="bg-white rounded-2xl shadow-sm p-6 space-y-4">
        <div className="flex items-center justify-between">
          <div className="h-5 w-32 bg-gray-200 rounded" />
          <div className="h-8 w-48 bg-gray-100 rounded-lg" />
        </div>
        {[1, 2, 3].map(i => (
          <div key={i} className="border border-gray-100 rounded-xl p-4 space-y-3">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gray-200 rounded-full" />
              <div className="space-y-1.5">
                <div className="h-4 w-24 bg-gray-200 rounded" />
                <div className="h-3 w-32 bg-gray-100 rounded" />
              </div>
            </div>
            <div className="h-4 w-3/4 bg-gray-100 rounded" />
            <div className="flex gap-2">
              <div className="h-5 w-20 bg-gray-100 rounded-full" />
              <div className="h-5 w-16 bg-gray-100 rounded-full" />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
