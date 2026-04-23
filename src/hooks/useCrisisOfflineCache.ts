'use client'

export interface CachedCrisisData {
  crises: unknown[]
  contacts: unknown[]
  cachedAt: string
}

export function useCrisisOfflineCache() {
  function cacheCrisisData(crises: unknown[], contacts: unknown[]): void {
    try {
      if (typeof navigator === 'undefined' || !navigator.serviceWorker?.controller) return
      navigator.serviceWorker.controller.postMessage({
        type: 'CACHE_CRISIS_DATA',
        payload: { crises, contacts },
      })
    } catch {
      // silently ignore
    }
  }

  function clearCrisisCache(): void {
    try {
      if (typeof navigator === 'undefined' || !navigator.serviceWorker?.controller) return
      navigator.serviceWorker.controller.postMessage({ type: 'CLEAR_CRISIS_CACHE' })
    } catch {
      // silently ignore
    }
  }

  async function loadCachedCrisisData(): Promise<CachedCrisisData | null> {
    try {
      if (typeof caches === 'undefined') return null
      const cache = await caches.open('mensaena-crisis-v1')
      const response = await cache.match('/offline/crisis-data.json')
      if (!response) return null
      return (await response.json()) as CachedCrisisData
    } catch {
      return null
    }
  }

  return { cacheCrisisData, clearCrisisCache, loadCachedCrisisData }
}
