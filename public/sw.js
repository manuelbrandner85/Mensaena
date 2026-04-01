// Mensaena Service Worker – Push Notifications + Offline Cache
const CACHE_NAME = 'mensaena-v1'
const OFFLINE_URLS = ['/dashboard', '/dashboard/posts', '/dashboard/chat']

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(OFFLINE_URLS).catch(() => {})
    })
  )
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  )
  self.clients.claim()
})

// Network-first with cache fallback for API, cache-first for assets
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)

  // Skip non-GET and cross-origin requests
  if (event.request.method !== 'GET') return
  if (!url.origin.includes(self.location.origin)) return

  // Cache static assets
  if (url.pathname.startsWith('/_next/static/') || url.pathname.startsWith('/mensaena-logo')) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached
        return fetch(event.request).then((res) => {
          if (res.ok) {
            const clone = res.clone()
            caches.open(CACHE_NAME).then((c) => c.put(event.request, clone))
          }
          return res
        })
      })
    )
    return
  }

  // For dashboard pages: network first, fall back to cache
  if (url.pathname.startsWith('/dashboard')) {
    event.respondWith(
      fetch(event.request)
        .then((res) => {
          if (res.ok) {
            const clone = res.clone()
            caches.open(CACHE_NAME).then((c) => c.put(event.request, clone))
          }
          return res
        })
        .catch(() => caches.match(event.request))
    )
  }
})

// ── Push Notification Handler ──────────────────────────────────────────────
self.addEventListener('push', (event) => {
  if (!event.data) return
  let payload
  try {
    payload = event.data.json()
  } catch {
    payload = { title: 'Mensaena', body: event.data.text() }
  }

  const options = {
    body: payload.body || '',
    icon: '/mensaena-logo.png',
    badge: '/favicon.ico',
    tag: payload.tag || 'mensaena-notification',
    data: { url: payload.url || '/dashboard' },
    requireInteraction: payload.requireInteraction || false,
    vibrate: [200, 100, 200],
  }

  event.waitUntil(
    self.registration.showNotification(payload.title || 'Mensaena', options)
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = event.notification.data?.url || '/dashboard'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(url)
          return client.focus()
        }
      }
      return clients.openWindow(url)
    })
  )
})
