'use client'

export function InteractionListSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      {/* Stats row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="bg-white rounded-xl p-4 border border-gray-100">
            <div className="h-4 w-16 bg-gray-200 rounded mb-2" />
            <div className="h-7 w-10 bg-gray-200 rounded" />
          </div>
        ))}
      </div>
      {/* Filter bar */}
      <div className="flex gap-2">
        <div className="h-9 w-20 bg-gray-200 rounded-lg" />
        <div className="h-9 w-24 bg-gray-200 rounded-lg" />
        <div className="h-9 w-24 bg-gray-200 rounded-lg" />
        <div className="h-9 flex-1 bg-gray-200 rounded-lg max-w-xs" />
      </div>
      {/* Cards */}
      {[1, 2, 3, 4].map(i => (
        <div key={i} className="bg-white rounded-xl p-4 border-l-4 border-gray-200">
          <div className="flex justify-between mb-3">
            <div className="h-5 w-24 bg-gray-200 rounded-full" />
            <div className="h-4 w-16 bg-gray-200 rounded" />
          </div>
          <div className="h-5 w-3/4 bg-gray-200 rounded mb-2" />
          <div className="flex items-center gap-2 mb-2">
            <div className="w-8 h-8 bg-gray-200 rounded-full" />
            <div className="h-4 w-32 bg-gray-200 rounded" />
          </div>
          <div className="h-4 w-full bg-gray-200 rounded" />
        </div>
      ))}
    </div>
  )
}

export function InteractionDetailSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      {/* Banner */}
      <div className="h-16 bg-gray-200 rounded-xl" />
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Left */}
        <div className="lg:col-span-3 space-y-4">
          <div className="bg-white rounded-xl p-5 border">
            <div className="h-5 w-1/2 bg-gray-200 rounded mb-3" />
            <div className="h-4 w-full bg-gray-200 rounded mb-2" />
            <div className="h-4 w-3/4 bg-gray-200 rounded" />
          </div>
          <div className="bg-white rounded-xl p-5 border">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-16 h-16 bg-gray-200 rounded-full" />
              <div>
                <div className="h-5 w-32 bg-gray-200 rounded mb-1" />
                <div className="h-4 w-20 bg-gray-200 rounded" />
              </div>
            </div>
          </div>
        </div>
        {/* Right */}
        <div className="lg:col-span-2 space-y-4">
          <div className="bg-white rounded-xl p-5 border">
            <div className="h-10 w-full bg-gray-200 rounded-lg mb-3" />
            <div className="h-10 w-full bg-gray-200 rounded-lg" />
          </div>
          {/* Timeline */}
          <div className="bg-white rounded-xl p-5 border space-y-4">
            {[1, 2, 3].map(i => (
              <div key={i} className="flex gap-3">
                <div className="w-6 h-6 bg-gray-200 rounded-full flex-shrink-0" />
                <div className="flex-1">
                  <div className="h-4 w-3/4 bg-gray-200 rounded mb-1" />
                  <div className="h-3 w-1/2 bg-gray-200 rounded" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
