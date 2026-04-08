/* ═══════════════════════════════════════════════════════════════════════
   MENSAENA – Push Notification Handler (imported by sw.js)
   ═══════════════════════════════════════════════════════════════════════ */

// ── Push Event ──────────────────────────────────────────────────────

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}

  const title = data.title || 'Mensaena'
  const options = {
    body: data.body || '',
    icon: data.icon || '/icons/icon-192x192.png',
    badge: data.badge || '/icons/icon-72x72.png',
    tag: data.tag || 'mensaena-default',
    data: { url: data.url || '/dashboard' },
    vibrate: [100, 50, 100],
    actions: data.actions || [],
    renotify: !!data.tag,
    requireInteraction: false,
    silent: false,
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

// ── Notification Click ──────────────────────────────────────────────

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const url = event.notification.data?.url || '/dashboard'

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Try to focus an existing window
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus()
          if ('navigate' in client) {
            client.navigate(url)
          }
          return
        }
      }
      // Open a new window
      return self.clients.openWindow(url)
    })
  )
})

// ── Notification Close (placeholder for analytics) ──────────────────

self.addEventListener('notificationclose', (_event) => {
  // Future: track notification dismissals
})
