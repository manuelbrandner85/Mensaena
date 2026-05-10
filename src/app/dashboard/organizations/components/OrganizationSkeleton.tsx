'use client'

export default function OrganizationSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 gap-3" role="status" aria-label="Organisationen werden geladen">
      {[...Array(count)].map((_, i) => (
        <div key={i} className="bg-mn-elevated rounded-2xl border border-white/5 p-4 animate-pulse">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 bg-mn-elevated rounded-xl flex-shrink-0" />
            <div className="flex-1">
              <div className="h-4 bg-mn-elevated rounded w-3/4 mb-2" />
              <div className="flex gap-2">
                <div className="h-3 bg-mn-surface rounded w-20" />
                <div className="h-3 bg-mn-surface rounded w-24" />
              </div>
              <div className="h-3 bg-mn-surface rounded w-full mt-3" />
              <div className="h-3 bg-mn-surface rounded w-2/3 mt-1" />
              <div className="flex gap-2 mt-3">
                <div className="h-6 bg-mn-surface rounded-full w-24" />
                <div className="h-6 bg-mn-surface rounded-full w-16" />
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
