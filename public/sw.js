// Mensaena Service Worker

// ── Web Push: render rich notifications ───────────────────────────────────
//
// send-push Edge Function liefert payload als JSON:
//   { title, body, icon, badge, url, tag }
// Ohne diesen Handler würde der Browser nur eine generische
// "Diese Seite hat neue Inhalte"-Meldung zeigen (oder gar nichts).

self.addEventListener('push', (event) => {
  if (!event.data) return

  let payload = {}
  try {
    payload = event.data.json()
  } catch {
    // Fallback: Plain-Text body
    payload = { title: 'Mensaena', body: event.data.text() || '' }
  }

  const title = payload.title || 'Mensaena'
  const tag = payload.tag || 'mensaena-notification'
  const url = payload.url || '/dashboard/notifications'

  const options = {
    body: payload.body || '',
    icon: payload.icon || '/icons/icon-192x192.png',
    badge: payload.badge || '/icons/icon-72x72.png',
    image: payload.image || undefined,         // großes Hero-Bild (optional)
    data: { url, tag, ...(payload.data || {}) },
    tag,                                        // gruppiert gleiche tags
    renotify: true,                             // pingt erneut bei gleichem tag
    requireInteraction: payload.requireInteraction === true,
    silent: false,
    timestamp: Date.now(),
    vibrate: [200, 100, 200],                   // kurzer Vibrationsmuster
    actions: [
      { action: 'open',    title: 'Öffnen' },
      { action: 'dismiss', title: 'Später' },
    ],
  }

  event.waitUntil(
    self.registration.showNotification(title, options)
  )
})

// Tap auf die Notification → App öffnen / fokussieren / zur URL navigieren
self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  if (event.action === 'dismiss') return

  const targetUrl = (event.notification.data && event.notification.data.url) || '/dashboard/notifications'

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        // Bestehendes Tab fokussieren wenn auf Mensaena
        for (const client of windowClients) {
          try {
            const url = new URL(client.url)
            if (url.origin === self.location.origin) {
              return client.focus().then((focused) => {
                if (focused && 'navigate' in focused) {
                  return focused.navigate(targetUrl)
                }
              })
            }
          } catch { /* ignore parse errors */ }
        }
        // Sonst neues Tab öffnen
        if (self.clients.openWindow) {
          return self.clients.openWindow(targetUrl)
        }
      })
  )
})

// Optional: Subscription wurde vom Browser invalidated → erneute Registrierung
// triggern. Wir feuern eine Message an alle Tabs damit usePushNotifications
// die Subscription erneuert.
self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(
    self.clients.matchAll({ includeUncontrolled: true }).then((clients) => {
      for (const c of clients) {
        c.postMessage({ type: 'PUSH_SUBSCRIPTION_CHANGED' })
      }
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

// ── Fetch: offline fallback for /dashboard/crisis ─────────────────────────

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)

  if (url.pathname.startsWith('/dashboard/crisis')) {
    event.respondWith(
      fetch(event.request).catch(() =>
        caches.open('mensaena-crisis-v1').then((cache) =>
          cache.match('/offline/crisis-data.json').then((cached) => {
            if (cached) {
              return cached.json().then((data) => {
                const crises = Array.isArray(data.crises) ? data.crises : []
                const contacts = Array.isArray(data.contacts) ? data.contacts : []
                const cachedAt = data.cachedAt ?? ''

                const rows = crises
                  .map(
                    (c) =>
                      `<li style="margin-bottom:8px"><strong>${escapeHtml(c.title ?? '')}</strong>${c.description ? ': ' + escapeHtml(c.description) : ''}</li>`
                  )
                  .join('')

                const contactRows = contacts
                  .map(
                    (c) =>
                      `<li>${escapeHtml(c.name ?? '')}${c.phone ? ' – ' + escapeHtml(c.phone) : ''}</li>`
                  )
                  .join('')

                const html = `<!DOCTYPE html>
<html lang="de">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Krisendaten (offline) – Mensaena</title>
<style>body{font-family:system-ui,sans-serif;max-width:600px;margin:2rem auto;padding:0 1rem;color:#1a1a1a}
h1{color:#147170}ul{padding-left:1.2rem}footer{margin-top:2rem;font-size:.75rem;color:#888}</style>
</head>
<body>
<h1>Krisendaten (offline)</h1>
<p>Du bist offline. Zuletzt gespeichert: ${escapeHtml(cachedAt)}</p>
${crises.length ? `<h2>Aktive Krisen</h2><ul>${rows}</ul>` : ''}
${contacts.length ? `<h2>Notfallkontakte</h2><ul>${contactRows}</ul>` : ''}
<footer>Mensaena – Nachbarschaftshilfe</footer>
</body></html>`

                return new Response(html, {
                  headers: { 'Content-Type': 'text/html; charset=utf-8' },
                })
              })
            }

            return caches.match('/offline.html').then(
              (offline) =>
                offline ??
                new Response('<h1>Offline</h1>', {
                  headers: { 'Content-Type': 'text/html' },
                })
            )
          })
        )
      )
    )
  }
})

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
