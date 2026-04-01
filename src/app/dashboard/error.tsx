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
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="text-3xl">⚠️</span>
        </div>
        <h1 className="text-2xl font-bold text-gray-900 mb-3">Dashboard-Fehler</h1>
        <p className="text-gray-600 mb-2 text-sm leading-relaxed">
          Das Dashboard konnte nicht geladen werden. Bitte lade die Seite neu.
        </p>
        {error?.message && (
          <p className="text-xs text-gray-400 font-mono mb-6 bg-gray-50 rounded-lg p-3 text-left break-words">
            {error.message}
          </p>
        )}
        <div className="flex gap-3 justify-center">
          <button
            onClick={reset}
            className="px-6 py-2.5 bg-primary-600 hover:bg-primary-700 text-white text-sm font-semibold rounded-xl transition-all"
          >
            Erneut versuchen
          </button>
          <Link
            href="/login"
            className="px-6 py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm font-semibold rounded-xl transition-all"
          >
            Zum Login
          </Link>
        </div>
      </div>
    </div>
  )
}
