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
    <div className="min-h-dvh flex items-center justify-center p-4" style={{ background: '#0a1420', color: '#ece5d6' }}>
      <div className="max-w-md w-full rounded-3xl overflow-hidden" style={{ background: 'linear-gradient(150deg, rgba(22,32,53,0.92) 0%, rgba(15,22,40,0.96) 100%)', border: '1px solid rgba(255,255,255,0.06)', boxShadow: '0 32px 80px rgba(0,0,0,0.40)' }}>
        {/* Header */}
        <div className="p-6 text-center" style={{ background: 'linear-gradient(135deg, rgba(199,147,99,0.18) 0%, rgba(43,86,99,0.20) 100%)', borderBottom: '1px solid rgba(199,147,99,0.15)' }}>
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-3" style={{ background: 'rgba(199,147,99,0.15)', border: '1px solid rgba(199,147,99,0.30)' }}>
            <Mail className="w-7 h-7" style={{ color: '#c79363' }} />
          </div>
          <h1 className="text-xl font-medium" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>Mensaena</h1>
          <p className="text-sm mt-1" style={{ color: '#94A3B8' }}>E-Mail-Abonnement</p>
        </div>

        {/* Content */}
        <div className="p-8 text-center">
          {state === 'loading' && (
            <>
              <Loader2 className="w-10 h-10 animate-spin mx-auto mb-4" style={{ color: '#c79363' }} />
              <p className="text-sm" style={{ color: '#94A3B8' }}>Wird verarbeitet…</p>
            </>
          )}

          {state === 'success' && (
            <>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style={{ background: 'rgba(22,32,53,0.85)', border: '1px solid rgba(199,147,99,0.20)' }}>
                <CheckCircle2 className="w-8 h-8" style={{ color: '#c79363' }} />
              </div>
              <h2 className="text-xl font-medium mb-2" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>Erfolgreich abgemeldet</h2>
              <p className="text-sm leading-relaxed" style={{ color: '#94A3B8' }}>
                {email ? (
                  <>Die Adresse <strong style={{ color: '#ece5d6' }}>{email}</strong> erhält keine weiteren Marketing-E-Mails von Mensaena mehr.</>
                ) : (
                  <>Du erhältst keine weiteren Marketing-E-Mails von Mensaena mehr.</>
                )}
              </p>
              <p className="text-xs mt-4 leading-relaxed" style={{ color: '#64748B' }}>
                Wichtige System-Benachrichtigungen (z.B. Passwort-Reset) werden weiterhin zugestellt.
              </p>
            </>
          )}

          {state === 'error' && (
            <>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4" style={{ background: 'rgba(22,32,53,0.85)', border: '1px solid rgba(220,80,80,0.25)' }}>
                <XCircle className="w-8 h-8" style={{ color: '#e57373' }} />
              </div>
              <h2 className="text-xl font-medium mb-2" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>Abmeldung fehlgeschlagen</h2>
              <p className="text-sm leading-relaxed" style={{ color: '#94A3B8' }}>{errorMsg}</p>
              <p className="text-xs mt-4" style={{ color: '#64748B' }}>
                Bitte kontaktiere uns unter{' '}
                <a href="mailto:info@mensaena.de" style={{ color: '#c79363' }} className="hover:underline">
                  info@mensaena.de
                </a>
                , wenn das Problem weiter besteht.
              </p>
            </>
          )}

          <div className="mt-8 pt-6" style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}>
            <Link
              href="/"
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all hover:opacity-90"
              style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)', color: '#0a1420' }}
            >
              Zur Startseite
            </Link>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 text-center" style={{ background: 'rgba(10,15,28,0.50)', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
          <p className="text-xs" style={{ color: '#64748B' }}>
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
      <div className="min-h-dvh flex items-center justify-center" style={{ background: '#0a1420' }}>
        <Loader2 className="w-10 h-10 animate-spin" style={{ color: '#c79363' }} />
      </div>
    }>
      <UnsubscribeContent />
    </Suspense>
  )
}
