'use client'

// Globaler Error-Boundary fuer Next.js App Router
// Faengt Fehler im Root-Layout selbst ab (wenn auch error.tsx versagt).
// MUSS html + body Tags rendern (ersetzt das Root-Layout im Fehlerfall).

import { useEffect } from 'react'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('[global-error]', error)
  }, [error])

  return (
    <html lang="de">
      <body style={{
        margin: 0,
        minHeight: '100vh',
        background: '#EEF9F9',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1rem',
      }}>
        <div style={{
          maxWidth: '28rem',
          width: '100%',
          textAlign: 'center',
          background: 'white',
          padding: '2rem',
          borderRadius: '1rem',
          boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
        }}>
          <div style={{
            width: '4rem',
            height: '4rem',
            margin: '0 auto 1.5rem',
            background: '#FEF2F2',
            border: '1px solid #FECACA',
            borderRadius: '1rem',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#EF4444',
            fontSize: '1.5rem',
            fontWeight: 500,
          }}>!</div>

          <h1 style={{
            fontSize: '1.5rem',
            fontWeight: 600,
            color: '#1F2937',
            marginBottom: '0.75rem',
          }}>
            Etwas ist schief gelaufen
          </h1>
          <p style={{
            color: '#6B7280',
            fontSize: '0.875rem',
            marginBottom: '1.5rem',
          }}>
            Die App ist auf einen unerwarteten Fehler gestoßen. Bitte lade die Seite neu.
          </p>

          <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
            <button
              onClick={reset}
              style={{
                padding: '0.625rem 1.5rem',
                background: '#1EAAA6',
                color: 'white',
                border: 'none',
                borderRadius: '9999px',
                fontSize: '0.875rem',
                fontWeight: 500,
                cursor: 'pointer',
              }}
            >
              Erneut versuchen
            </button>
            <a
              href="/"
              style={{
                padding: '0.625rem 1.5rem',
                background: 'white',
                color: '#374151',
                border: '1px solid #E5E7EB',
                borderRadius: '9999px',
                fontSize: '0.875rem',
                fontWeight: 500,
                textDecoration: 'none',
              }}
            >
              Zur Startseite
            </a>
          </div>
        </div>
      </body>
    </html>
  )
}
