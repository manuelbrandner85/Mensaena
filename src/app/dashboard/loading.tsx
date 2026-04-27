/**
 * Dashboard-weites Loading-Skeleton
 *
 * Wird automatisch von Next.js angezeigt während eine Dashboard-Route lädt
 * (Server-Component-Fetch, Data-Loading, etc.). Verhindert den weißen
 * "Frozen-Screen"-Eindruck bei langsamen Verbindungen.
 *
 * Modul-spezifische Routes können eigenes loading.tsx anlegen, das dieses
 * dann übersteuert.
 */
export default function DashboardLoading() {
  return (
    <div className="px-4 sm:px-6 py-6 max-w-7xl mx-auto" aria-busy="true" aria-label="Wird geladen">
      {/* Header-Skeleton */}
      <div className="mb-6 animate-pulse">
        <div className="h-7 w-48 bg-stone-200 rounded-lg mb-2" />
        <div className="h-4 w-72 bg-stone-100 rounded" />
      </div>

      {/* Card-Grid-Skeleton */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div
            key={i}
            className="card p-5 animate-pulse"
            style={{ animationDelay: `${i * 80}ms` }}
          >
            <div className="flex items-start gap-3 mb-3">
              <div className="w-10 h-10 rounded-full bg-stone-200 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="h-4 w-3/4 bg-stone-200 rounded mb-2" />
                <div className="h-3 w-1/2 bg-stone-100 rounded" />
              </div>
            </div>
            <div className="space-y-2">
              <div className="h-3 w-full bg-stone-100 rounded" />
              <div className="h-3 w-5/6 bg-stone-100 rounded" />
              <div className="h-3 w-4/6 bg-stone-100 rounded" />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
