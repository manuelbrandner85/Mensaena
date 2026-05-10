'use client'

import { useEffect } from 'react'
import Link from 'next/link'

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('Dashboard error:', error)
  }, [error])

  return (
    <div className="min-h-dvh bg-paper relative flex items-center justify-center px-4 overflow-hidden">
      <div
        className="hero-orb-1 absolute pointer-events-none"
        style={{ top: '-20%', left: '-10%', width: '50vw', height: '50vw' }}
        aria-hidden="true"
      />
      <div
        className="hero-orb-2 absolute pointer-events-none"
        style={{ bottom: '-15%', right: '-10%', width: '45vw', height: '45vw' }}
        aria-hidden="true"
      />
      <div className="relative max-w-md w-full text-center">
        <div className="w-16 h-16 bg-red-50 border border-red-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="font-display text-2xl font-medium text-red-500" aria-hidden="true">!</span>
        </div>

        <h1 className="font-display text-2xl font-medium text-ink-800 mb-3">
          Dashboard-Fehler
        </h1>
        <p className="text-ink-500 mb-2 text-sm leading-relaxed">
          Das Dashboard konnte nicht geladen werden. Bitte versuche es erneut.
        </p>
        {error?.message && (
          <p className="text-xs text-ink-400 font-mono mb-6 bg-stone-50 border border-stone-200 rounded-xl p-3 text-left break-words">
            {error.message}
          </p>
        )}

        <div className="flex gap-3 justify-center">
          <button
            onClick={reset}
            className="cta-cinema-ink inline-flex items-center h-10 px-6 rounded-full text-paper text-sm font-medium tracking-wide"
          >
            Erneut versuchen
          </button>
          <Link
            href="/"
            className="inline-flex items-center h-10 px-6 rounded-full border border-stone-200 hover:border-stone-300 bg-white text-ink-700 text-sm font-medium tracking-wide transition-colors"
          >
            Zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
