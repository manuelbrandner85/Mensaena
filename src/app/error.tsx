'use client'

import { useEffect } from 'react'
import Link from 'next/link'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('App error:', error)
  }, [error])

  return (
    <div className="min-h-dvh relative flex items-center justify-center px-4 overflow-hidden" style={{ background: '#0a1420', color: '#ece5d6' }}>
      <div className="absolute pointer-events-none rounded-full" style={{ top: '-20%', left: '-10%', width: '50vw', height: '50vw', background: 'radial-gradient(circle, rgba(199,147,99,0.12) 0%, transparent 70%)', filter: 'blur(80px)' }} aria-hidden="true" />
      <div className="absolute pointer-events-none rounded-full" style={{ bottom: '-15%', right: '-10%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(43,86,99,0.14) 0%, transparent 70%)', filter: 'blur(80px)' }} aria-hidden="true" />
      <div className="relative max-w-md w-full text-center">
        <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-6" style={{ background: 'rgba(22,32,53,0.85)', border: '1px solid rgba(220,80,80,0.25)' }}>
          <span className="font-display text-2xl font-medium" style={{ color: '#e57373' }} aria-hidden="true">!</span>
        </div>

        <h1 className="text-2xl font-medium mb-3" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>
          Ein Fehler ist aufgetreten
        </h1>
        <p className="mb-2 text-sm leading-relaxed" style={{ color: '#94A3B8' }}>
          Die Seite konnte nicht geladen werden. Bitte versuche es erneut.
        </p>
        {error?.message && (
          <p className="text-xs font-mono mb-6 rounded-xl p-3 text-left break-words" style={{ color: '#94A3B8', background: 'rgba(15,22,40,0.65)', border: '1px solid rgba(255,255,255,0.06)' }}>
            {error.message}
          </p>
        )}

        <div className="flex gap-3 justify-center">
          <button
            onClick={reset}
            className="inline-flex items-center h-10 px-6 rounded-full text-sm font-medium tracking-wide transition-all hover:opacity-90"
            style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)', color: '#0a1420' }}
          >
            Erneut versuchen
          </button>
          <Link
            href="/"
            className="inline-flex items-center h-10 px-6 rounded-full text-sm font-medium tracking-wide transition-all hover:opacity-80"
            style={{ background: 'rgba(22,32,53,0.70)', border: '1px solid rgba(199,147,99,0.25)', color: '#ece5d6' }}
          >
            Zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
