/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Service Worker
   Caching strategies: Network-First (navigation), Cache-First (assets),
   Network-Only (API), Stale-While-Revalidate (JS/CSS)
   ═══════════════════════════════════════════════════════════════════════ */

importScripts('/sw-push.js')

// ── Constants ───────────────────────────────────────────────────────

const CACHE_VERSION = 'v1'
const STATIC_CACHE_NAME = 'mensaena-static-' + CACHE_VERSION
const DYNAMIC_CACHE_NAME = 'mensaena-dynamic-' + CACHE_VERSION
const OFFLINE_URL = '/offline.html'
const MAX_DYNAMIC_CACHE_ITEMS = 100

const STATIC_ASSETS = [
  '/',
  '/offline.html',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png',
  '/favicon.ico',
]

// ── Helpers ─────────────────────────────────────────────────────────

async function limitCacheSize(cacheName, maxItems) {
  const cache = await caches.open(cacheName)
  const keys = await cache.keys()
  if (keys.length > maxItems) {
    await cache.delete(keys[0])
    return limitCacheSize(cacheName, maxItems)
  }
}

function isStaticAsset(url) {
  return /\.(png|jpe?g|gif|svg|ico|webp|woff2?|ttf|eot)(\?.*)?$/i.test(url)
}

function isApiRequest(url) {
  return url.includes('/api/') || url.includes('supabase.co')
}

// ── Install ─────────────────────────────────────────────────────────

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS)
    })
  )
  self.skipWaiting()
})

// ── Activate ────────────────────────────────────────────────────────

self.addEventListener('activate', (event) => {
  const allowedCaches = [STATIC_CACHE_NAME, DYNAMIC_CACHE_NAME]

  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => !allowedCaches.includes(name))
          .map((name) => caches.delete(name))
      )
    })
  )
  self.clients.claim()
})

// ── Fetch ───────────────────────────────────────────────────────────

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = request.url

  // Skip non-GET requests
  if (request.method !== 'GET') return

  // Skip chrome-extension and other non-http(s) requests
  if (!url.startsWith('http')) return

  // ── Navigation: Network-First ──
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          // Cache successful navigation responses
          const clone = response.clone()
          caches.open(DYNAMIC_CACHE_NAME).then((cache) => {
            cache.put(request, clone)
          })
          return response
        })
        .catch(async () => {
          const cached = await caches.match(request)
          if (cached) return cached
          return caches.match(OFFLINE_URL)
        })
    )
    return
  }

  // ── API: Network-Only ──
  if (isApiRequest(url)) {
    event.respondWith(
      fetch(request).catch(() => {
        return new Response(JSON.stringify({ error: 'offline' }), {
          status: 503,
          headers: { 'Content-Type': 'application/json' },
        })
      })
    )
    return
  }

  // ── Static assets: Cache-First ──
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached
        return fetch(request).then((response) => {
          const clone = response.clone()
          caches.open(DYNAMIC_CACHE_NAME).then((cache) => {
            cache.put(request, clone)
            limitCacheSize(DYNAMIC_CACHE_NAME, MAX_DYNAMIC_CACHE_ITEMS)
          })
          return response
        })
      })
    )
    return
  }

  // ── Everything else: Stale-While-Revalidate ──
  event.respondWith(
    caches.match(request).then((cached) => {
      const networkFetch = fetch(request)
        .then((response) => {
          const clone = response.clone()
          caches.open(DYNAMIC_CACHE_NAME).then((cache) => {
            cache.put(request, clone)
            limitCacheSize(DYNAMIC_CACHE_NAME, MAX_DYNAMIC_CACHE_ITEMS)
          })
          return response
        })
        .catch(() => cached)

      return cached || networkFetch
    })
  )
})

// ── Message Handler ─────────────────────────────────────────────────

self.addEventListener('message', (event) => {
  const { type, urls } = event.data || {}

  if (type === 'SKIP_WAITING') {
    self.skipWaiting()
  }

  if (type === 'CACHE_URLS' && Array.isArray(urls)) {
    event.waitUntil(
      caches.open(DYNAMIC_CACHE_NAME).then((cache) => {
        return cache.addAll(urls).catch(() => {})
      })
    )
  }

  if (type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys().then((names) => {
        return Promise.all(names.map((n) => caches.delete(n)))
      }).then(() => {
        return caches.open(STATIC_CACHE_NAME).then((cache) => {
          return cache.addAll(STATIC_ASSETS)
        })
      })
    )
  }
})
