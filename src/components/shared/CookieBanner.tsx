'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { X } from 'lucide-react'

const CONSENT_KEY = 'mensaena_cookie_consent'

type ConsentState = 'all' | 'necessary' | null

function getStoredConsent(): ConsentState {
  if (typeof window === 'undefined') return null
  try {
    const raw = window.localStorage.getItem(CONSENT_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { choice: ConsentState; ts: number }
    if (parsed?.choice) return parsed.choice
  } catch { /* ignore */ }
  return null
}

export default function CookieBanner() {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (getStoredConsent() === null) setVisible(true)
  }, [])

  function accept(choice: 'all' | 'necessary') {
    try {
      window.localStorage.setItem(CONSENT_KEY, JSON.stringify({ choice, ts: Date.now() }))
    } catch { /* ignore */ }
    setVisible(false)
  }

  if (!visible) return null

  return (
    <div
      role="dialog"
      aria-modal="false"
      aria-label="Cookie-Einstellungen"
      className="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex justify-center p-4 md:p-6 pb-[max(1rem,env(safe-area-inset-bottom,0px))] md:pb-[max(1.5rem,env(safe-area-inset-bottom,0px))]"
    >
      <div className="pointer-events-auto w-full max-w-2xl rounded-2xl border border-stone-200 bg-white/95 shadow-card backdrop-blur-md">
        <div className="flex items-start gap-4 p-5 md:p-6">
          <div className="min-w-0 flex-1">
            <p className="text-[13px] leading-relaxed text-ink-600">
              <span className="font-semibold text-ink-800">Mensaena verwendet Cookies</span>{' '}
              — ausschließlich notwendige für den Betrieb (Authentifizierung, Sitzung).
              Keine Tracking- oder Werbe-Cookies.{' '}
              <Link
                href="/datenschutz"
                className="text-primary-700 underline-offset-2 hover:underline"
              >
                Datenschutzerklärung
              </Link>
            </p>

            <div className="mt-4 flex flex-wrap items-center gap-2.5">
              <button
                type="button"
                onClick={() => accept('all')}
                className="inline-flex h-9 items-center rounded-full bg-ink-900 px-5 text-[12px] font-medium tracking-wide text-paper transition-colors hover:bg-ink-700"
              >
                Alle akzeptieren
              </button>
              <button
                type="button"
                onClick={() => accept('necessary')}
                className="inline-flex h-9 items-center rounded-full border border-stone-300 bg-transparent px-5 text-[12px] font-medium tracking-wide text-ink-700 transition-colors hover:border-stone-400 hover:bg-stone-50"
              >
                Nur notwendige
              </button>
            </div>
          </div>

          <button
            type="button"
            onClick={() => accept('necessary')}
            aria-label="Schließen – nur notwendige Cookies"
            className="flex-shrink-0 flex h-8 w-8 items-center justify-center rounded-full text-ink-400 transition-colors hover:bg-stone-100 hover:text-ink-700"
          >
            <X className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
      </div>
    </div>
  )
}
