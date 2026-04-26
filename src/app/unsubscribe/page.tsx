'use client'

import { useEffect, useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { CheckCircle2, XCircle, Loader2, Mail } from 'lucide-react'

function UnsubscribeContent() {
  const searchParams = useSearchParams()
  const token = searchParams.get('token')

  const [state, setState] = useState<'loading' | 'success' | 'error'>('loading')
  const [email, setEmail] = useState<string>('')
  const [errorMsg, setErrorMsg] = useState<string>('')

  useEffect(() => {
    if (!token) {
      setState('error')
      setErrorMsg('Kein Token in der URL gefunden')
      return
    }

    fetch(`/api/emails/unsubscribe?token=${encodeURIComponent(token)}`)
      .then(async res => {
        const data = await res.json().catch(() => ({}))
        if (!res.ok) {
          setState('error')
          setErrorMsg(data.error || 'Abmeldung fehlgeschlagen')
          return
        }
        setState('success')
        setEmail(data.email || '')
      })
      .catch(err => {
        setState('error')
        setErrorMsg(err.message || 'Netzwerkfehler')
      })
  }, [token])

  return (
    <div className="min-h-dvh bg-paper flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-3xl shadow-soft border border-stone-100 overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-br from-primary-500 to-primary-700 p-6 text-center">
          <div className="w-14 h-14 bg-white/20 rounded-2xl border border-white/30 flex items-center justify-center mx-auto mb-3">
            <Mail className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-xl font-bold text-white">Mensaena</h1>
          <p className="text-sm text-white/80 mt-1">E-Mail-Abonnement</p>
        </div>

        {/* Content */}
        <div className="p-8 text-center">
          {state === 'loading' && (
            <>
              <Loader2 className="w-10 h-10 text-primary-500 animate-spin mx-auto mb-4" />
              <p className="text-ink-600 text-sm">Wird verarbeitet…</p>
            </>
          )}

          {state === 'success' && (
            <>
              <div className="w-16 h-16 bg-green-50 border border-green-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-8 h-8 text-green-600" />
              </div>
              <h2 className="text-xl font-bold text-ink-900 mb-2">Erfolgreich abgemeldet</h2>
              <p className="text-sm text-ink-600 leading-relaxed">
                {email ? (
                  <>Die Adresse <strong className="text-ink-900">{email}</strong> erhält keine weiteren Marketing-E-Mails von Mensaena mehr.</>
                ) : (
                  <>Du erhältst keine weiteren Marketing-E-Mails von Mensaena mehr.</>
                )}
              </p>
              <p className="text-xs text-ink-400 mt-4 leading-relaxed">
                Wichtige System-Benachrichtigungen (z.B. Passwort-Reset) werden weiterhin zugestellt.
              </p>
            </>
          )}

          {state === 'error' && (
            <>
              <div className="w-16 h-16 bg-red-50 border border-red-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <XCircle className="w-8 h-8 text-red-500" />
              </div>
              <h2 className="text-xl font-bold text-ink-900 mb-2">Abmeldung fehlgeschlagen</h2>
              <p className="text-sm text-ink-600 leading-relaxed">{errorMsg}</p>
              <p className="text-xs text-ink-400 mt-4">
                Bitte kontaktiere uns unter{' '}
                <a href="mailto:info@mensaena.de" className="text-primary-600 hover:underline">
                  info@mensaena.de
                </a>
                , wenn das Problem weiter besteht.
              </p>
            </>
          )}

          <div className="mt-8 pt-6 border-t border-stone-100">
            <Link
              href="/"
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium transition-colors"
            >
              Zur Startseite
            </Link>
          </div>
        </div>

        {/* Footer */}
        <div className="bg-stone-50 px-6 py-4 text-center border-t border-stone-100">
          <p className="text-xs text-ink-400">
            © {new Date().getFullYear()} Mensaena ·{' '}
            <Link href="/impressum" className="hover:underline">Impressum</Link> ·{' '}
            <Link href="/datenschutz" className="hover:underline">Datenschutz</Link>
          </p>
        </div>
      </div>
    </div>
  )
}

export default function UnsubscribePage() {
  return (
    <Suspense fallback={
      <div className="min-h-dvh bg-paper flex items-center justify-center">
        <Loader2 className="w-10 h-10 text-primary-500 animate-spin" />
      </div>
    }>
      <UnsubscribeContent />
    </Suspense>
  )
}
