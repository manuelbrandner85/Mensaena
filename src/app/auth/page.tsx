'use client'

import { Suspense, useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import {
  Mail, Lock, Eye, EyeOff, AlertCircle, CheckCircle2, User, Home,
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
        <div className="min-h-screen bg-background flex items-center justify-center" role="status">
          <div className="flex flex-col items-center gap-3">
            <div className="w-10 h-10 border-[3px] border-emerald-200 border-t-emerald-600 rounded-full animate-spin" aria-hidden="true" />
            <span className="sr-only">Wird geladen</span>
          </div>
        </div>
      }
    >
      <AuthPage />
    </Suspense>
  )
}

function AuthPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const mode = searchParams.get('mode') === 'register' ? 'register' : 'login'

  const [name, setName]                 = useState('')
  const [email, setEmail]               = useState('')
  const [password, setPassword]         = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading]           = useState(false)
  const [checking, setChecking]         = useState(true)
  const [error, setError]               = useState('')
  const [agreed, setAgreed]             = useState(false)

  const checks = useMemo(() => passwordChecks(password), [password])

  /* ── Session check → redirect if logged in ─────────────────────────── */
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        router.replace('/dashboard')
      } else {
        setChecking(false)
      }
    })
  }, [router])

  /* ── Clear error when switching modes ──────────────────────────────── */
  useEffect(() => {
    setError('')
  }, [mode])

  /* ── Login handler ─────────────────────────────────────────────────── */
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    const supabase = createClient()

    // D1.6 Security: Use a generic error message to prevent user enumeration.
    // Do NOT reveal whether the email exists or the password was wrong.
    const { data, error: loginError } = await supabase.auth.signInWithPassword({
      email: email.toLowerCase().trim(),
      password,
    })

    if (loginError) {
      setError('E-Mail oder Passwort ist falsch. Bitte erneut versuchen.')
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

  /* ── Loading spinner ───────────────────────────────────────────────── */
  if (checking) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center" role="status">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-[3px] border-emerald-200 border-t-emerald-600 rounded-full animate-spin" aria-hidden="true" />
          <span className="sr-only">Wird geladen</span>
        </div>
      </div>
    )
  }

  /* ── UI ─────────────────────────────────────────────────────────────── */
  return (
    <div className="min-h-dvh hero-gradient flex items-center justify-center px-4 py-8 md:py-12 safe-area-top safe-area-bottom">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 bg-primary-200/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-trust-100/30 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <Link href="/" className="flex items-center justify-center gap-2.5 mb-8" aria-label="Zurück zur Startseite">
          <Home className="w-7 h-7 text-emerald-600" aria-hidden="true" />
          <span className="text-2xl font-bold text-gray-900">
            Mensa<span className="text-emerald-600">ena</span>
          </span>
        </Link>

        <div className="card p-5 md:p-8 shadow-hover">
          {/* Header */}
          <div className="mb-7">
            <h1 className="text-2xl font-bold text-gray-900 mb-2">
              {mode === 'login' ? 'Willkommen zurück' : 'Konto erstellen'}
            </h1>
            <p className="text-sm text-gray-600">
              {mode === 'login'
                ? 'Melde dich mit deiner E-Mail und deinem Passwort an.'
                : 'Kostenlos registrieren und Teil der Gemeinschaft werden.'}
            </p>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 p-3 bg-red-50 border border-red-200 rounded-xl mb-5 text-sm text-red-700" role="alert">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" aria-hidden="true" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={mode === 'login' ? handleLogin : handleRegister} className="space-y-5">
            {/* Name (register only) */}
            {mode === 'register' && (
              <div>
                <label htmlFor="auth-name" className="label">Vollständiger Name</label>
                <div className="relative">
                  <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" aria-hidden="true" />
                  <input
                    id="auth-name"
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Dein Name"
                    required
                    autoComplete="name"
                    className="input pl-10"
                  />
                </div>
              </div>
            )}

            {/* Email */}
            <div>
              <label htmlFor="auth-email" className="label">E-Mail-Adresse</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" aria-hidden="true" />
                <input
                  id="auth-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="deine@email.de"
                  required
                  autoComplete="email"
                  className="input pl-10"
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <label htmlFor="auth-password" className="label">Passwort</label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" aria-hidden="true" />
                <input
                  id="auth-password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder={mode === 'login' ? 'Dein Passwort' : 'Sicheres Passwort wählen'}
                  required
                  autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                  className="input pl-10 pr-12"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors min-w-[44px] min-h-[44px] flex items-center justify-center -mr-2"
                  aria-label={showPassword ? 'Passwort verbergen' : 'Passwort anzeigen'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {/* Password checks (register only) */}
              {mode === 'register' && password.length > 0 && (
                <div className="mt-2.5 space-y-1">
                  {checks.map((check, i) => (
                    <div key={i} className={`flex items-center gap-2 text-xs ${check.ok ? 'text-emerald-600' : 'text-gray-400'}`}>
                      <CheckCircle2 className={`w-3.5 h-3.5 ${check.ok ? 'text-emerald-500' : 'text-gray-300'}`} aria-hidden="true" />
                      {check.label}
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Agreement (register only) */}
            {mode === 'register' && (
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => setAgreed(e.target.checked)}
                  className="mt-0.5 w-4 h-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
                />
                <span className="text-xs text-gray-600 leading-relaxed">
                  Ich stimme den{' '}
                  <Link href="/nutzungsbedingungen" className="text-emerald-600 underline hover:text-emerald-700">
                    Nutzungsbedingungen
                  </Link>{' '}
                  und der{' '}
                  <Link href="/datenschutz" className="text-emerald-600 underline hover:text-emerald-700">
                    Datenschutzerklärung
                  </Link>{' '}
                  zu.
                </span>
              </label>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="bg-emerald-600 hover:bg-emerald-700 text-white w-full flex items-center justify-center gap-2 py-4 text-base md:text-lg font-semibold rounded-xl transition-colors touch-target disabled:opacity-60"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" aria-hidden="true" />
                  {mode === 'login' ? 'Prüfe…' : 'Registrieren…'}
                </>
              ) : (
                mode === 'login' ? 'Anmelden' : 'Kostenlos registrieren'
              )}
            </button>
          </form>

          {/* Toggle mode */}
          <p className="text-center text-sm text-gray-600 mt-6">
            {mode === 'login' ? (
              <>
                Noch kein Konto?{' '}
                <Link href="/auth?mode=register" className="font-semibold text-emerald-600 hover:text-emerald-700">
                  Jetzt registrieren →
                </Link>
              </>
            ) : (
              <>
                Bereits registriert?{' '}
                <Link href="/auth?mode=login" className="font-semibold text-emerald-600 hover:text-emerald-700">
                  Anmelden →
                </Link>
              </>
            )}
          </p>
        </div>

        <div className="text-center mt-6">
          <Link href="/" className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            ← Zurück zur Startseite
          </Link>
        </div>
      </div>
    </div>
  )
}
