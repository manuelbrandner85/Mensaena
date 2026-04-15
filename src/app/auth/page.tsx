'use client'

import { Suspense, useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter, useSearchParams } from 'next/navigation'
import {
  Mail, Lock, Eye, EyeOff, AlertCircle, CheckCircle2, User,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

/* ── Password strength checks ────────────────────────────────────────── */
const passwordChecks = (pw: string) => [
  { label: 'Mindestens 8 Zeichen', ok: pw.length >= 8 },
  { label: 'Groß- und Kleinbuchstaben', ok: /[a-z]/.test(pw) && /[A-Z]/.test(pw) },
  { label: 'Mindestens eine Zahl', ok: /\d/.test(pw) },
]

/* ── Suspense wrapper (required for useSearchParams in Next 15) ───── */
export default function AuthPageWrapper() {
  return (
    <Suspense
      fallback={
        <div className="min-h-dvh bg-paper aurora-bg flex items-center justify-center" role="status">
          <div className="flex flex-col items-center gap-3">
            <div className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-500 rounded-full animate-spin" aria-hidden="true" />
            <span className="sr-only">Wird geladen</span>
          </div>
        </div>
      }
    >
      <AuthPage />
    </Suspense>
  )
}

type AuthMode = 'login' | 'register' | 'forgot' | 'reset'

function AuthPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const rawMode = searchParams.get('mode')
  const mode: AuthMode =
    rawMode === 'register' ? 'register'
    : rawMode === 'forgot' ? 'forgot'
    : rawMode === 'reset'  ? 'reset'
    : 'login'

  const [name, setName]                 = useState('')
  const [email, setEmail]               = useState('')
  const [password, setPassword]         = useState('')
  const [passwordConfirm, setPasswordConfirm] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading]           = useState(false)
  const [checking, setChecking]         = useState(true)
  const [error, setError]               = useState('')
  const [info, setInfo]                 = useState('')
  const [agreed, setAgreed]             = useState(false)
  const [resetSent, setResetSent]       = useState(false)
  const [recoverySession, setRecoverySession] = useState(false)
  const [failCount, setFailCount]       = useState(0)
  const [lockUntil, setLockUntil]       = useState<number | null>(null)
  const [secondsLeft, setSecondsLeft]   = useState(0)

  // ── Rate-limit countdown ────────────────────────────────────────────
  useEffect(() => {
    if (!lockUntil) return
    const interval = setInterval(() => {
      const remaining = Math.ceil((lockUntil - Date.now()) / 1000)
      if (remaining <= 0) {
        setLockUntil(null)
        setSecondsLeft(0)
        setFailCount(0)
        clearInterval(interval)
      } else {
        setSecondsLeft(remaining)
      }
    }, 1000)
    return () => clearInterval(interval)
  }, [lockUntil])

  // ── Password strength score (0–4) ──────────────────────────────────
  const pwScore = useMemo(() => {
    if (!password) return 0
    return (password.length >= 8 ? 1 : 0)
      + (/[A-Z]/.test(password) ? 1 : 0)
      + (/[a-z]/.test(password) ? 1 : 0)
      + (/\d/.test(password) ? 1 : 0)
  }, [password])

  const checks = useMemo(() => passwordChecks(password), [password])

  /* ── Session check → redirect if logged in ─────────────────────────── */
  useEffect(() => {
    const supabase = createClient()

    // In reset-Mode Supabase die Recovery-Session aus dem URL-Hash her;
    // wir dürfen hier NICHT ins Dashboard redirecten.
    const { data: authListener } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        setRecoverySession(true)
        setChecking(false)
      }
    })

    supabase.auth.getSession().then(({ data: { session } }) => {
      if (mode === 'reset') {
        // Warte auf Recovery-Session, aber zeige das Formular schon an.
        if (session?.user) setRecoverySession(true)
        setChecking(false)
        return
      }
      if (session?.user) {
        router.replace('/dashboard')
      } else {
        setChecking(false)
      }
    })

    return () => {
      authListener.subscription.unsubscribe()
    }
  }, [router, mode])

  /* ── Clear error/info when switching modes ─────────────────────────── */
  useEffect(() => {
    setError('')
    setInfo('')
    setPassword('')
    setPasswordConfirm('')
    setResetSent(false)
    setLoading(false)
  }, [mode])

  /* ── Login handler ─────────────────────────────────────────────────── */
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (lockUntil && Date.now() < lockUntil) {
      setError(`Zu viele Versuche. Bitte warte ${secondsLeft} Sekunden.`)
      return
    }

    setLoading(true)

    const supabase = createClient()

    // D1.6 Security: Use a generic error message to prevent user enumeration.
    // Do NOT reveal whether the email exists or the password was wrong.
    const { data, error: loginError } = await supabase.auth.signInWithPassword({
      email: email.toLowerCase().trim(),
      password,
    })

    if (loginError) {
      const newFail = failCount + 1
      setFailCount(newFail)
      if (newFail >= 5) {
        setLockUntil(Date.now() + 30000)
        setSecondsLeft(30)
        setError('Zu viele Fehlversuche. Bitte warte 30 Sekunden.')
      } else {
        setError('E-Mail oder Passwort ist falsch. Bitte erneut versuchen.')
      }
      setLoading(false)
      return
    }

    if (data?.session) {
      toast.success('Willkommen zurück! 🌿')
      router.replace('/dashboard')
    }
  }

  /* ── Register handler ──────────────────────────────────────────────── */
  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!agreed) {
      setError('Bitte stimme den Nutzungsbedingungen zu.')
      return
    }
    if (!checks.every((c) => c.ok)) {
      setError('Passwort erfüllt nicht alle Anforderungen.')
      return
    }

    setLoading(true)
    const supabase = createClient()

    const { data: existingProfile } = await supabase
      .from('profiles')
      .select('id')
      .eq('email', email.toLowerCase().trim())
      .maybeSingle()

    if (existingProfile) {
      setError('Diese E-Mail-Adresse ist bereits registriert. Bitte melde dich an.')
      setLoading(false)
      return
    }

    const { data, error: signUpError } = await supabase.auth.signUp({
      email: email.toLowerCase().trim(),
      password,
      options: {
        data: { full_name: name },
        emailRedirectTo: `${window.location.origin}/auth?mode=login`,
      },
    })

    if (signUpError) {
      if (signUpError.message.includes('already registered')) {
        setError('Diese E-Mail-Adresse ist bereits registriert. Bitte melde dich an.')
      } else {
        setError(signUpError.message)
      }
      setLoading(false)
      return
    }

    if (data?.session) {
      toast.success('Willkommen bei Mensaena! 🌿')
      router.replace('/dashboard')
      return
    }

    setError(
      'Fast geschafft! Bitte prüfe dein E-Mail-Postfach für die Bestätigung.'
    )
    setLoading(false)
  }

  /* ── Forgot-Password handler ───────────────────────────────────────── */
  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setInfo('')
    setLoading(true)

    const supabase = createClient()
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.toLowerCase().trim(),
      {
        redirectTo: `${window.location.origin}/auth?mode=reset`,
      },
    )

    setLoading(false)

    // Sicherheit: Immer Erfolg anzeigen, damit keine E-Mail-Enumeration möglich ist.
    if (resetError) {
      console.error('[auth] resetPasswordForEmail:', resetError)
    }
    setResetSent(true)
    setInfo(
      'Falls ein Konto mit dieser E-Mail existiert, haben wir dir einen Link zum Zurücksetzen geschickt. Bitte prüfe dein Postfach (auch den Spam-Ordner).'
    )
  }

  /* ── Reset-Password handler ────────────────────────────────────────── */
  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setInfo('')

    if (!checks.every((c) => c.ok)) {
      setError('Passwort erfüllt nicht alle Anforderungen.')
      return
    }
    if (password !== passwordConfirm) {
      setError('Die Passwörter stimmen nicht überein.')
      return
    }

    setLoading(true)
    const supabase = createClient()
    const { error: updateError } = await supabase.auth.updateUser({ password })

    if (updateError) {
      setError(
        updateError.message.includes('session')
          ? 'Der Link ist ungültig oder abgelaufen. Bitte fordere einen neuen Link an.'
          : updateError.message,
      )
      setLoading(false)
      return
    }

    toast.success('Passwort erfolgreich aktualisiert. 🌿')
    // Nach erfolgreichem Reset ausloggen und zum Login schicken.
    await supabase.auth.signOut()
    setLoading(false)
    router.replace('/auth?mode=login')
  }

  /* ── Loading spinner ───────────────────────────────────────────────── */
  if (checking) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center" role="status">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-600 rounded-full animate-spin" aria-hidden="true" />
          <span className="sr-only">Wird geladen</span>
        </div>
      </div>
    )
  }

  /* ── UI ─────────────────────────────────────────────────────────────── */
  const modeIndex =
    mode === 'login' ? '01' : mode === 'register' ? '02' : mode === 'forgot' ? '03' : '04'
  const modeLabel =
    mode === 'login' ? 'Willkommen zurück' :
    mode === 'register' ? 'Neues Konto' :
    mode === 'forgot' ? 'Passwort vergessen' :
    'Passwort zurücksetzen'

  return (
    <div className="min-h-dvh bg-paper aurora-bg relative flex items-center justify-center px-4 py-12 md:py-16 safe-area-top safe-area-bottom overflow-hidden">
      {/* Editorial mesh backdrop */}
      <div className="mesh-gradient" aria-hidden="true" />
      <div className="mesh-grain absolute inset-0 pointer-events-none" aria-hidden="true" />

      <div className="relative w-full max-w-md">
        {/* Logo + wordmark lockup */}
        <Link
          href="/"
          className="group flex items-center justify-center gap-3 mb-10 reveal is-visible"
          aria-label="Zurück zur Startseite"
        >
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={90}
            height={60}
            className="h-14 w-auto object-contain transition-transform duration-500 group-hover:rotate-[-4deg]"
            priority
          />
          <span className="font-display text-3xl font-medium text-ink-800 tracking-tight">
            Mensaena<span className="text-primary-500">.</span>
          </span>
        </Link>

        <div className="editorial-card p-6 md:p-10 spotlight">
          {/* Editorial meta + header */}
          <div className="mb-8">
            <div className="meta-label meta-label--subtle mb-5">{modeIndex} / {modeLabel}</div>
            <h1 className="font-display text-3xl md:text-[2.1rem] font-medium text-ink-800 leading-[1.08] tracking-tight mb-3">
              {mode === 'login'    && <>Willkommen <span className="text-accent">zurück</span>.</>}
              {mode === 'register' && <>Werde Teil der <span className="text-accent">Gemeinschaft</span>.</>}
              {mode === 'forgot'   && <>Passwort <span className="text-accent">vergessen</span>?</>}
              {mode === 'reset'    && <>Neues <span className="text-accent">Passwort</span>.</>}
            </h1>
            <p className="text-sm text-ink-500 leading-relaxed">
              {mode === 'login'    && 'Melde dich mit deiner E-Mail und deinem Passwort an.'}
              {mode === 'register' && 'Kostenlos registrieren und Teil der Gemeinschaft werden.'}
              {mode === 'forgot'   && 'Gib deine E-Mail-Adresse ein. Wir senden dir einen Link zum Zurücksetzen.'}
              {mode === 'reset'    && 'Wähle ein neues, sicheres Passwort für dein Konto.'}
            </p>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 p-3 bg-red-50 border border-red-200 rounded-xl mb-5 text-sm text-red-700" role="alert">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" aria-hidden="true" />
              <span>{error}</span>
            </div>
          )}

          {/* Info */}
          {info && (
            <div className="flex items-start gap-3 p-3 bg-primary-50 border border-primary-200 rounded-xl mb-5 text-sm text-primary-800" role="status">
              <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" aria-hidden="true" />
              <span>{info}</span>
            </div>
          )}

          <form
            onSubmit={
              mode === 'login'    ? handleLogin
              : mode === 'register' ? handleRegister
              : mode === 'forgot'   ? handleForgotPassword
              : handleResetPassword
            }
            className="space-y-5"
          >
            {/* Name (register only) */}
            {mode === 'register' && (
              <div>
                <label htmlFor="auth-name" className="block text-[10px] font-semibold tracking-[0.14em] uppercase text-ink-400 mb-2">
                  Vollständiger Name
                </label>
                <div className="relative group">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 group-focus-within:text-primary-600 transition-colors" aria-hidden="true" />
                  <input
                    id="auth-name"
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Dein Name"
                    required
                    autoComplete="name"
                    className="w-full h-12 pl-11 pr-4 bg-paper border border-stone-200 rounded-xl text-ink-800 placeholder:text-ink-400/70 focus:outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100 transition-all"
                  />
                </div>
              </div>
            )}

            {/* Email */}
            {mode !== 'reset' && (
              <div>
                <label htmlFor="auth-email" className="block text-[10px] font-semibold tracking-[0.14em] uppercase text-ink-400 mb-2">
                  E-Mail-Adresse
                </label>
                <div className="relative group">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 group-focus-within:text-primary-600 transition-colors" aria-hidden="true" />
                  <input
                    id="auth-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="deine@email.de"
                    required
                    autoComplete="email"
                    disabled={mode === 'forgot' && resetSent}
                    className="w-full h-12 pl-11 pr-4 bg-paper border border-stone-200 rounded-xl text-ink-800 placeholder:text-ink-400/70 focus:outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100 transition-all disabled:bg-stone-50 disabled:text-ink-400"
                  />
                </div>
              </div>
            )}

            {/* Password */}
            {mode !== 'forgot' && (
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label htmlFor="auth-password" className="block text-[10px] font-semibold tracking-[0.14em] uppercase text-ink-400">
                    {mode === 'reset' ? 'Neues Passwort' : 'Passwort'}
                  </label>
                  {mode === 'login' && (
                    <Link
                      href="/auth?mode=forgot"
                      className="link-sweep text-[10px] font-semibold tracking-[0.12em] uppercase text-primary-700 hover:text-primary-800"
                    >
                      Vergessen?
                    </Link>
                  )}
                </div>
                <div className="relative group">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 group-focus-within:text-primary-600 transition-colors" aria-hidden="true" />
                  <input
                    id="auth-password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={mode === 'login' ? 'Dein Passwort' : 'Sicheres Passwort wählen'}
                    required
                    autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                    className="w-full h-12 pl-11 pr-12 bg-paper border border-stone-200 rounded-xl text-ink-800 placeholder:text-ink-400/70 focus:outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 text-ink-400 hover:text-ink-700 transition-colors min-w-[44px] min-h-[44px] flex items-center justify-center rounded-full hover:bg-stone-100"
                    aria-label={showPassword ? 'Passwort verbergen' : 'Passwort anzeigen'}
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
                {/* Password strength bar + checks (register + reset) */}
                {(mode === 'register' || mode === 'reset') && password.length > 0 && (
                  <div className="mt-3">
                    {/* Strength bar */}
                    <div className="flex items-center gap-2 mb-2">
                      <div className="flex-1 h-1 rounded-full bg-stone-200 overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all duration-500 ease-out"
                          style={{
                            width: `${(pwScore / 4) * 100}%`,
                            backgroundColor: pwScore <= 1 ? '#C62828' : pwScore <= 2 ? '#F59E0B' : pwScore <= 3 ? '#1EAAA6' : '#059669',
                          }}
                        />
                      </div>
                      <span className="text-[9px] font-semibold tracking-[0.12em] uppercase text-ink-400 w-14 text-right">
                        {pwScore <= 1 ? 'Schwach' : pwScore <= 2 ? 'Mittel' : pwScore <= 3 ? 'Gut' : 'Stark'}
                      </span>
                    </div>
                    <div className="space-y-1">
                      {checks.map((check, i) => (
                        <div key={i} className={`flex items-center gap-2 text-[11px] transition-colors ${check.ok ? 'text-primary-700' : 'text-ink-400'}`}>
                          <CheckCircle2 className={`w-3.5 h-3.5 transition-colors ${check.ok ? 'text-primary-500' : 'text-stone-300'}`} aria-hidden="true" />
                          {check.label}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Passwort bestätigen (reset only) */}
            {mode === 'reset' && (
              <div>
                <label htmlFor="auth-password-confirm" className="block text-[10px] font-semibold tracking-[0.14em] uppercase text-ink-400 mb-2">
                  Passwort bestätigen
                </label>
                <div className="relative group">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400 group-focus-within:text-primary-600 transition-colors" aria-hidden="true" />
                  <input
                    id="auth-password-confirm"
                    type={showPassword ? 'text' : 'password'}
                    value={passwordConfirm}
                    onChange={(e) => setPasswordConfirm(e.target.value)}
                    placeholder="Passwort wiederholen"
                    required
                    autoComplete="new-password"
                    className="w-full h-12 pl-11 pr-4 bg-paper border border-stone-200 rounded-xl text-ink-800 placeholder:text-ink-400/70 focus:outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100 transition-all"
                  />
                </div>
              </div>
            )}

            {/* Agreement (register only) */}
            {mode === 'register' && (
              <label className="flex items-start gap-3 cursor-pointer group">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => setAgreed(e.target.checked)}
                  className="mt-0.5 w-4 h-4 rounded border-stone-300 text-primary-600 focus:ring-primary-500"
                />
                <span className="text-[11px] text-ink-500 leading-relaxed">
                  Ich stimme den{' '}
                  <Link href="/nutzungsbedingungen" className="link-sweep text-primary-700 hover:text-primary-800">
                    Nutzungsbedingungen
                  </Link>{' '}
                  und der{' '}
                  <Link href="/datenschutz" className="link-sweep text-primary-700 hover:text-primary-800">
                    Datenschutzerklärung
                  </Link>{' '}
                  zu.
                </span>
              </label>
            )}

            {/* Rate-limit warning */}
            {lockUntil && secondsLeft > 0 && (
              <p className="text-xs tracking-[0.14em] uppercase text-emergency-600 text-center font-semibold">
                Zu viele Versuche – warte {secondsLeft}s
              </p>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading || (mode === 'forgot' && resetSent) || (!!lockUntil && Date.now() < lockUntil)}
              className="magnetic shine group w-full flex items-center justify-center gap-2 h-12 bg-ink-800 hover:bg-ink-700 text-paper text-sm font-medium tracking-wide rounded-full transition-all touch-target disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 border-2 border-paper/30 border-t-paper rounded-full animate-spin" aria-hidden="true" />
                  {mode === 'login'    && 'Prüfe…'}
                  {mode === 'register' && 'Registrieren…'}
                  {mode === 'forgot'   && 'Sende Link…'}
                  {mode === 'reset'    && 'Speichere…'}
                </>
              ) : (
                <>
                  {mode === 'login'    && (lockUntil ? `Warte ${secondsLeft}s…` : 'Anmelden')}
                  {mode === 'register' && 'Kostenlos registrieren'}
                  {mode === 'forgot'   && (resetSent ? 'Link gesendet' : 'Link zum Zurücksetzen senden')}
                  {mode === 'reset'    && 'Passwort speichern'}
                  <span className="transition-transform group-hover:translate-x-0.5">→</span>
                </>
              )}
            </button>
          </form>

          {/* Toggle mode */}
          <div className="mt-8 pt-6 border-t border-stone-200 text-center">
            <p className="text-[11px] tracking-[0.12em] uppercase text-ink-400">
              {mode === 'login' && (
                <>
                  Noch kein Konto?{' '}
                  <Link href="/auth?mode=register" className="link-sweep font-semibold text-primary-700 hover:text-primary-800">
                    Jetzt registrieren
                  </Link>
                </>
              )}
              {mode === 'register' && (
                <>
                  Bereits registriert?{' '}
                  <Link href="/auth?mode=login" className="link-sweep font-semibold text-primary-700 hover:text-primary-800">
                    Anmelden
                  </Link>
                </>
              )}
              {mode === 'forgot' && (
                <>
                  Passwort wieder eingefallen?{' '}
                  <Link href="/auth?mode=login" className="link-sweep font-semibold text-primary-700 hover:text-primary-800">
                    Zurück zum Login
                  </Link>
                </>
              )}
              {mode === 'reset' && !recoverySession && (
                <span className="normal-case tracking-normal text-amber-700">
                  Hinweis: Diese Seite muss über den Link aus deiner E-Mail geöffnet werden.
                </span>
              )}
              {mode === 'reset' && recoverySession && (
                <Link href="/auth?mode=login" className="link-sweep font-semibold text-primary-700 hover:text-primary-800">
                  Abbrechen
                </Link>
              )}
            </p>
          </div>
        </div>

        <div className="text-center mt-8">
          <Link href="/" className="link-sweep text-[10px] font-semibold tracking-[0.14em] uppercase text-ink-400 hover:text-ink-700 transition-colors">
            Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
