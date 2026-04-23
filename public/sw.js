// Mensaena Service Worker

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
