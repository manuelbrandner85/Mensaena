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
      className="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex justify-center p-4 md:p-6 pb-24 md:pb-[max(1.5rem,env(safe-area-inset-bottom,0px))]"
    >
      <div className="pointer-events-auto w-full max-w-2xl card-depth">
        <div className="flex items-start gap-4 p-5 md:p-6">
          <div className="min-w-0 flex-1">
            <p className="text-[13px] leading-relaxed text-mn-ink-soft">
              <span className="font-semibold text-mn-ink">Mensaena verwendet Cookies</span>{' '}
              — ausschließlich notwendige für den Betrieb (Authentifizierung, Sitzung).
              Keine Tracking- oder Werbe-Cookies.{' '}
              <Link
                href="/datenschutz"
                className="text-mn-amber underline-offset-2 hover:underline"
              >
                Datenschutzerklärung
              </Link>
            </p>

            <div className="mt-4 flex flex-wrap items-center gap-2.5">
              <button
                type="button"
                onClick={() => accept('all')}
                className="cta-cinema-ink inline-flex h-9 items-center rounded-full px-5 text-[12px] font-medium tracking-wide text-paper"
              >
                Alle akzeptieren
              </button>
              <button
                type="button"
                onClick={() => accept('necessary')}
                className="inline-flex h-9 items-center rounded-full border border-stone-300 bg-transparent px-5 text-[12px] font-medium tracking-wide text-mn-ink-soft transition-colors hover:border-stone-400 hover:bg-mn-elevated/[0.02]"
              >
                Nur notwendige
              </button>
            </div>
          </div>

          <button
            type="button"
            onClick={() => accept('necessary')}
            aria-label="Schließen – nur notwendige Cookies"
            className="flex-shrink-0 flex h-8 w-8 items-center justify-center rounded-full text-mn-mute transition-colors hover:bg-mn-elevated/5 hover:text-mn-ink-soft"
          >
            <X className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
      </div>
    </div>
  )
}
