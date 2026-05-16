'use client'

import { useState } from 'react'
import { Send, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react'

type Status = 'idle' | 'sending' | 'success' | 'error'

const SUBJECTS = [
  'Technisches Problem',
  'Feedback & Ideen',
  'Inhalt melden',
  'Datenschutz-Anfrage (DSGVO)',
  'Presse & Kooperationen',
  'Sonstiges',
]

export default function ContactForm() {
  const [name, setName]       = useState('')
  const [email, setEmail]     = useState('')
  const [subject, setSubject] = useState(SUBJECTS[0])
  const [message, setMessage] = useState('')
  const [status, setStatus]   = useState<Status>('idle')
  const [errorMsg, setErrorMsg] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setStatus('sending')
    setErrorMsg('')

    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, subject, message }),
      })
      const data = await res.json()
      if (!res.ok) {
        setErrorMsg(data.error ?? 'Unbekannter Fehler.')
        setStatus('error')
        return
      }
      setStatus('success')
    } catch {
      setErrorMsg('Netzwerkfehler. Bitte versuche es erneut.')
      setStatus('error')
    }
  }

  if (status === 'success') {
    return (
      <div className="flex items-start gap-4 rounded-2xl border border-mn-bronze/20 bg-mn-bronze/5/60 p-6">
        <CheckCircle2 className="mt-0.5 h-5 w-5 flex-shrink-0 text-mn-bronze" aria-hidden="true" />
        <div>
          <p className="font-semibold text-mn-ink">Nachricht erhalten!</p>
          <p className="mt-1 text-sm text-mn-mute leading-relaxed">
            Danke, {name}. Wir melden uns in der Regel innerhalb von 1–2 Werktagen
            an <span className="font-medium text-mn-ink-soft">{email}</span>.
          </p>
        </div>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 not-prose">
      <div className="grid gap-5 sm:grid-cols-2">
        {/* Name */}
        <div>
          <label htmlFor="cf-name" className="block text-xs font-semibold tracking-[0.14em] uppercase text-mn-mute mb-2">
            Name
          </label>
          <input
            id="cf-name"
            type="text"
            autoComplete="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Dein Name"
            required
            maxLength={100}
            className="w-full h-12 px-4 bg-mn-void border border-white/5 rounded-xl text-mn-ink placeholder:text-mn-mute/70 focus:outline-none focus:border-mn-bronze/30 focus:ring-2 focus:ring-mn-bronze/10 transition-all text-sm"
          />
        </div>

        {/* Email */}
        <div>
          <label htmlFor="cf-email" className="block text-xs font-semibold tracking-[0.14em] uppercase text-mn-mute mb-2">
            E-Mail
          </label>
          <input
            id="cf-email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="deine@email.de"
            required
            className="w-full h-12 px-4 bg-mn-void border border-white/5 rounded-xl text-mn-ink placeholder:text-mn-mute/70 focus:outline-none focus:border-mn-bronze/30 focus:ring-2 focus:ring-mn-bronze/10 transition-all text-sm"
          />
        </div>
      </div>

      {/* Subject */}
      <div>
        <label htmlFor="cf-subject" className="block text-xs font-semibold tracking-[0.14em] uppercase text-mn-mute mb-2">
          Betreff
        </label>
        <select
          id="cf-subject"
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          className="w-full h-12 px-4 bg-mn-void border border-white/5 rounded-xl text-mn-ink focus:outline-none focus:border-mn-bronze/30 focus:ring-2 focus:ring-mn-bronze/10 transition-all text-sm appearance-none cursor-pointer"
        >
          {SUBJECTS.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </div>

      {/* Message */}
      <div>
        <label htmlFor="cf-message" className="block text-xs font-semibold tracking-[0.14em] uppercase text-mn-mute mb-2">
          Nachricht
        </label>
        <textarea
          id="cf-message"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Wie können wir helfen?"
          required
          minLength={10}
          maxLength={5000}
          rows={5}
          className="w-full px-4 py-3 bg-mn-void border border-white/5 rounded-xl text-mn-ink placeholder:text-mn-mute/70 focus:outline-none focus:border-mn-bronze/30 focus:ring-2 focus:ring-mn-bronze/10 transition-all text-sm resize-none"
        />
        <div className="mt-1 text-right text-xs text-mn-mute">
          {message.length}/5000
        </div>
      </div>

      {status === 'error' && (
        <div className="flex items-start gap-3 rounded-xl border border-mn-herzrot/20 bg-mn-surface p-3 text-sm text-mn-herzrot" role="alert">
          <AlertCircle className="mt-0.5 h-4 w-4 flex-shrink-0" aria-hidden="true" />
          <span>{errorMsg}</span>
        </div>
      )}

      <button
        type="submit"
        disabled={status === 'sending'}
        className="cta-cinema-ink inline-flex h-11 items-center gap-2.5 rounded-full px-7 text-sm font-medium tracking-wide text-paper disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {status === 'sending' ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
            Wird gesendet…
          </>
        ) : (
          <>
            <Send className="h-4 w-4" aria-hidden="true" />
            Nachricht senden
          </>
        )}
      </button>
    </form>
  )
}
