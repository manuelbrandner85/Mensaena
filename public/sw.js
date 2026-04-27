// Mensaena Service Worker
// v3 – adds offline.html fallback for navigations + static cache strategy

const CACHE_VERSION = 'mensaena-static-v3'
const OFFLINE_URL = '/offline.html'

// ── Lifecycle ─────────────────────────────────────────────────────────────

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) =>
      // Offline-Fallback vorab cachen, sonst ist er offline nicht verfügbar.
      cache.add(new Request(OFFLINE_URL, { cache: 'reload' })).catch(() => {})
    )
  )
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith('mensaena-static-') && k !== CACHE_VERSION)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  )
})

// ── Fetch strategy ─────────────────────────────────────────────────────────
//
// /_next/static/*  →  cache-first (hashed filenames, immutable)
// /icons/*         →  cache-first (long-lived icons)
// /images/*        →  cache-first (long-lived images)
// /sounds/*        →  cache-first
// /api/*           →  network-only (never cache)
// /dashboard/crisis→  network-first + offline HTML fallback (existing)
// everything else  →  pass through

self.addEventListener('fetch', (event) => {
  const req = event.request
  if (req.method !== 'GET') return

  let url
  try { url = new URL(req.url) } catch { return }

  // Static assets: cache-first
  if (
    url.origin === self.location.origin &&
    (url.pathname.startsWith('/_next/static/') ||
      url.pathname.startsWith('/icons/') ||
      url.pathname.startsWith('/images/') ||
      url.pathname.startsWith('/sounds/') ||
      url.pathname === '/manifest.json')
  ) {
    event.respondWith(
      caches.open(CACHE_VERSION).then((cache) =>
        cache.match(req).then((cached) => {
          if (cached) return cached
          return fetch(req).then((response) => {
            if (response.ok) cache.put(req, response.clone())
            return response
          })
        })
      )
    )
    return
  }

  // Navigations (HTML-Seiten): network-first mit offline.html als Fallback,
  // damit der User bei verlorener Verbindung statt blank screen die
  // Offline-Seite sieht. /dashboard/crisis hat eigenen, spezielleren Pfad
  // (siehe unten) und wird hier nicht abgegriffen.
  if (req.mode === 'navigate' && url.origin === self.location.origin
      && !url.pathname.startsWith('/dashboard/crisis')
      && !url.pathname.startsWith('/api/')) {
    event.respondWith(
      fetch(req).catch(() =>
        caches.match(OFFLINE_URL).then((cached) =>
          cached ?? new Response('<h1>Offline</h1>', { headers: { 'Content-Type': 'text/html' } })
        )
      )
    )
    return
  }

  // Crisis page: network-first + offline fallback (unchanged logic below)
  if (url.origin === self.location.origin && url.pathname.startsWith('/dashboard/crisis')) {
    event.respondWith(
      fetch(req).catch(() =>
        caches.open('mensaena-crisis-v1').then((cache) =>
          cache.match('/offline/crisis-data.json').then((cached) => {
            if (cached) {
              return cached.json().then((data) => {
                const crises = Array.isArray(data.crises) ? data.crises : []
                const contacts = Array.isArray(data.contacts) ? data.contacts : []
                const cachedAt = data.cachedAt ?? ''
                const rows = crises.map((c) => `<li style="margin-bottom:8px"><strong>${escapeHtml(c.title ?? '')}</strong>${c.description ? ': ' + escapeHtml(c.description) : ''}</li>`).join('')
                const contactRows = contacts.map((c) => `<li>${escapeHtml(c.name ?? '')}${c.phone ? ' – ' + escapeHtml(c.phone) : ''}</li>`).join('')
                const html = `<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Krisendaten (offline) – Mensaena</title><style>body{font-family:system-ui,sans-serif;max-width:600px;margin:2rem auto;padding:0 1rem;color:#1a1a1a}h1{color:#147170}ul{padding-left:1.2rem}footer{margin-top:2rem;font-size:.75rem;color:#888}</style></head><body><h1>Krisendaten (offline)</h1><p>Du bist offline. Zuletzt gespeichert: ${escapeHtml(cachedAt)}</p>${crises.length ? `<h2>Aktive Krisen</h2><ul>${rows}</ul>` : ''}${contacts.length ? `<h2>Notfallkontakte</h2><ul>${contactRows}</ul>` : ''}<footer>Mensaena – Nachbarschaftshilfe</footer></body></html>`
                return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } })
              })
            }
            return caches.match('/offline.html').then((offline) => offline ?? new Response('<h1>Offline</h1>', { headers: { 'Content-Type': 'text/html' } }))
          })
        )
      )
    )
  }
})

// ── Web Push: render rich notifications ───────────────────────────────────

self.addEventListener('push', (event) => {
  if (!event.data) return
  let payload = {}
  try { payload = event.data.json() } catch { payload = { title: 'Mensaena', body: event.data.text() || '' } }

  const title = payload.title || 'Mensaena'
  const tag = payload.tag || 'mensaena-notification'
  const url = payload.url || '/dashboard/notifications'

  event.waitUntil(
    self.registration.showNotification(title, {
      body: payload.body || '',
      icon: payload.icon || '/icons/icon-192x192.png',
      badge: payload.badge || '/icons/icon-72x72.png',
      image: payload.image || undefined,
      data: { url, tag, ...(payload.data || {}) },
      tag,
      renotify: true,
      requireInteraction: payload.requireInteraction === true,
      silent: false,
      timestamp: Date.now(),
      vibrate: [200, 100, 200],
      actions: [
        { action: 'open', title: 'Öffnen' },
        { action: 'dismiss', title: 'Später' },
      ],
    })
  )
})

// Notification tap → focus or open app
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  if (event.action === 'dismiss') return

  const targetUrl = (event.notification.data && event.notification.data.url) || '/dashboard/notifications'

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        try {
          const u = new URL(client.url)
          if (u.origin === self.location.origin) {
            return client.focus().then((focused) => {
              if (focused && 'navigate' in focused) return focused.navigate(targetUrl)
            })
          }
        } catch { /* ignore */ }
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl)
    })
  )
})

// Subscription invalidated → ask tabs to re-register
self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(
    self.clients.matchAll({ includeUncontrolled: true }).then((clients) => {
      for (const c of clients) c.postMessage({ type: 'PUSH_SUBSCRIPTION_CHANGED' })
    })
  )
})

// ── Crisis data caching ────────────────────────────────────────────────────

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'CACHE_CRISIS_DATA') {
    const { crises, contacts } = event.data.payload
    caches.open('mensaena-crisis-v1').then((cache) => {
      const response = new Response(
        JSON.stringify({ crises, contacts, cachedAt: new Date().toISOString() }),
        { headers: { 'Content-Type': 'application/json' } }
      )
      cache.put('/offline/crisis-data.json', response).then(() => {
        event.source?.postMessage({ type: 'CRISIS_CACHED', success: true })
      })
    })
  }

  if (event.data && event.data.type === 'CLEAR_CRISIS_CACHE') {
    caches.delete('mensaena-crisis-v1').then(() => {
      event.source?.postMessage({ type: 'CRISIS_CACHE_CLEARED', success: true })
    })
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
