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
import { useTranslations } from 'next-intl'

export default function AuthPageWrapper() {
  return (
    <Suspense
      fallback={
        <div className="min-h-dvh bg-paper relative flex items-center justify-center overflow-hidden" role="status">
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
          <div className="relative flex flex-col items-center gap-3">
            <div className="w-10 h-10 border-[3px] border-white/10 border-t-mn-amber rounded-full animate-spin" aria-hidden="true" />
            <span className="sr-only">Loading…</span>
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
  const t = useTranslations('auth')
  const router = useRouter()
  const searchParams = useSearchParams()
  const rawMode = searchParams.get('mode')
  const mode: AuthMode =
    rawMode === 'register' ? 'register'
    : rawMode === 'forgot' ? 'forgot'
    : rawMode === 'reset'  ? 'reset'
    : 'login'

  const [name, setName]                       = useState('')
  const [email, setEmail]                     = useState('')
  const [password, setPassword]               = useState('')
  const [passwordConfirm, setPasswordConfirm] = useState('')
  const [showPassword, setShowPassword]       = useState(false)
  const [loading, setLoading]                 = useState(false)
  const [checking, setChecking]               = useState(true)
  const [error, setError]                     = useState('')
  const [info, setInfo]                       = useState('')
  const [agreed, setAgreed]                   = useState(false)
  const [resetSent, setResetSent]             = useState(false)
  const [recoverySession, setRecoverySession] = useState(false)
  const [failCount, setFailCount]             = useState(0)
  const [lockUntil, setLockUntil]             = useState<number | null>(null)
  const [secondsLeft, setSecondsLeft]         = useState(0)

  const checks = useMemo(() => [
    { label: t('pwCheck1'), ok: password.length >= 8 },
    { label: t('pwCheck2'), ok: /[a-z]/.test(password) && /[A-Z]/.test(password) },
    { label: t('pwCheck3'), ok: /\d/.test(password) },
  ], [password, t])

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

  /* ── Session check → redirect if logged in ─────────────────────────── */
  useEffect(() => {
    const supabase = createClient()
    const { data: authListener } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        setRecoverySession(true)
        setChecking(false)
      }
    })
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (mode === 'reset') {
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
    return () => { authListener.subscription.unsubscribe() }
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
      setError(t('errTooManyAttemptsWait', { seconds: secondsLeft }))
      return
    }
    setLoading(true)
    const supabase = createClient()
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
        setError(t('errTooManyAttempts'))
      } else {
        setError(t('errInvalidCredentials'))
      }
      setLoading(false)
      return
    }
    if (data?.session) {
      toast.success(t('toastWelcomeBack'))
      router.replace('/dashboard')
    }
  }

  /* ── Register handler ──────────────────────────────────────────────── */
  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    if (!agreed) {
      setError(t('errAgreeTerms'))
      return
    }
    if (!checks.every((c) => c.ok)) {
      setError(t('errPasswordRequirements'))
      return
    }
    setLoading(true)
    const supabase = createClient()
    // NOTE: We deliberately do not pre-check `profiles.email` here. An
    // unauthenticated SELECT against a public column would leak whether an
    // email is registered (account-enumeration). Supabase's signUp() returns a
    // generic "User already registered" error for duplicates, which we map to
    // the same UX message below.
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
        setError(t('errEmailExists'))
      } else {
        setError(signUpError.message)
      }
      setLoading(false)
      return
    }
    const newUserId = data?.user?.id
    if (newUserId) {
      fetch('/api/emails/welcome', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: newUserId, email: email.toLowerCase().trim(), name }),
      }).catch(err => console.warn('[welcome-email] trigger failed:', err))
    }
    const urlParams = new URLSearchParams(window.location.search)
    const refCode = urlParams.get('ref')
    if (refCode && data.user?.id) {
      try {
        await supabase.rpc('accept_referral', {
          p_invite_code: refCode,
          p_invitee_id: data.user.id
        })
      } catch (e) {
        console.warn('Referral accept failed:', e)
      }
    }
    if (data?.session) {
      toast.success(t('toastWelcome'))
      router.replace('/dashboard')
      return
    }
    setError(t('infoCheckEmail'))
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
      { redirectTo: `${window.location.origin}/auth?mode=reset` },
    )
    setLoading(false)
    if (resetError) {
      console.error('[auth] resetPasswordForEmail:', resetError)
      setError(resetError.message || 'Ein Fehler ist aufgetreten. Bitte versuche es erneut.')
      return
    }
    setResetSent(true)
    setInfo(t('infoResetSent'))
  }

  /* ── Reset-Password handler ────────────────────────────────────────── */
  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setInfo('')
    if (!checks.every((c) => c.ok)) {
      setError(t('errPasswordRequirements'))
      return
    }
    if (password !== passwordConfirm) {
      setError(t('errPasswordMismatch'))
      return
    }
    setLoading(true)
    const supabase = createClient()
    const { error: updateError } = await supabase.auth.updateUser({ password })
    if (updateError) {
      setError(
        updateError.message.includes('session')
          ? t('errInvalidResetLink')
          : updateError.message,
      )
      setLoading(false)
      return
    }
    toast.success(t('toastPasswordUpdated'))
    await supabase.auth.signOut()
    setLoading(false)
    router.replace('/auth?mode=login')
  }

  /* ── Loading spinner ───────────────────────────────────────────────── */
  if (checking) {
    return (
      <div className="min-h-dvh bg-mn-void flex items-center justify-center" role="status">
        <div className="flex flex-col items-center gap-4">
          <div
            className="w-10 h-10 border-[3px] rounded-full animate-spin"
            style={{ borderColor: 'rgba(245,158,11,0.20)', borderTopColor: 'rgba(245,158,11,0.75)' }}
            aria-hidden="true"
          />
          <span className="sr-only">{t('loadingAria')}</span>
        </div>
      </div>
    )
  }

  /* ── UI ─────────────────────────────────────────────────────────────── */
  const modeIndex =
    mode === 'login' ? '01' : mode === 'register' ? '02' : mode === 'forgot' ? '03' : '04'
  const modeLabel =
    mode === 'login'    ? t('modeLogin') :
    mode === 'register' ? t('modeRegister') :
    mode === 'forgot'   ? t('modeForgot') :
    t('modeReset')

  const accent = (chunks: React.ReactNode) => <span style={{ color: 'rgba(245,158,11,0.85)' }}>{chunks}</span>

  return (
    <div className="min-h-dvh bg-mn-void relative flex items-start sm:items-center justify-center px-4 py-16 sm:py-12 md:py-16 safe-area-top safe-area-bottom overflow-y-auto">
      {/* Atmospheric orbs */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{ top: '-15%', left: '-12%', width: '55vw', height: '55vw', background: 'radial-gradient(circle, rgba(245,158,11,0.07) 0%, transparent 70%)', filter: 'blur(80px)' }}
        aria-hidden="true"
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{ bottom: '-10%', right: '-8%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(14,165,233,0.05) 0%, transparent 70%)', filter: 'blur(70px)' }}
        aria-hidden="true"
      />
      {/* Firefly particles */}
      {[...Array(6)].map((_, i) => (
        <div
          key={i}
          className="absolute pointer-events-none rounded-full"
          style={{
            width: 3 + (i % 3), height: 3 + (i % 3),
            background: 'rgba(253,230,138,0.6)',
            top: `${15 + i * 13}%`,
            left: `${8 + i * 14}%`,
            animation: `float ${7 + i * 2}s ease-in-out ${i * 1.2}s infinite`,
            filter: 'blur(0.5px)',
          }}
          aria-hidden="true"
        />
      ))}

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <Link
          href="/"
          className="group flex items-center justify-center gap-3 mb-10"
          aria-label={t('backToHome')}
        >
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena Logo"
            width={90}
            height={60}
            className="h-14 w-auto object-contain transition-transform duration-500 group-hover:scale-105 drop-shadow-[0_0_16px_rgba(245,158,11,0.30)]"
            priority
          />
          <span
            className="text-3xl font-medium tracking-tight"
            style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F1F5F9' }}
          >
            Mensaena<span style={{ color: 'rgba(245,158,11,0.80)' }}>.</span>
          </span>
        </Link>

        {/* Card */}
        <div className="bg-mn-raised rounded-modal border border-white/5 shadow-cinema-raised p-6 md:p-10">
          {/* Header */}
          <div className="mb-8">
            <div className="cinema-meta-label cinema-meta-label--subtle mb-4">{modeIndex} / {modeLabel}</div>
            <h1
              className="text-3xl md:text-[2.1rem] font-medium leading-[1.08] tracking-tight mb-3"
              style={{ fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif', color: '#F1F5F9' }}
            >
              {mode === 'login'    && t.rich('loginHeading',    { b: accent })}
              {mode === 'register' && t.rich('registerHeading', { b: accent })}
              {mode === 'forgot'   && t.rich('forgotHeading',   { b: accent })}
              {mode === 'reset'    && t.rich('resetHeading',    { b: accent })}
            </h1>
            <p className="text-sm text-mn-mute leading-relaxed">
              {mode === 'login'    && t('loginSubtitle')}
              {mode === 'register' && t('registerSubtitle')}
              {mode === 'forgot'   && t('forgotSubtitle')}
              {mode === 'reset'    && t('resetSubtitle')}
            </p>
          </div>

          {error && (
            <div className="flex items-start gap-3 p-3 rounded-xl mb-5 text-sm border" style={{ background: 'rgba(239,68,68,0.06)', borderColor: 'rgba(239,68,68,0.20)', color: '#F87171' }} role="alert">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" aria-hidden="true" />
              <span>{error}</span>
            </div>
          )}

          {info && (
            <div className="flex items-start gap-3 p-3 rounded-xl mb-5 text-sm border" style={{ background: 'rgba(34,197,94,0.06)', borderColor: 'rgba(34,197,94,0.20)', color: '#86EFAC' }} role="status">
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
                <label htmlFor="auth-name" className="block text-xs font-medium tracking-[0.12em] uppercase mb-1.5" style={{ color: 'rgba(245,240,232,0.55)' }}>
                  {t('name')}
                </label>
                <div className="relative">
                  <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-ghost pointer-events-none" aria-hidden="true" />
                  <input
                    id="auth-name"
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder={t('namePlaceholder')}
                    required
                    autoComplete="name"
                    className="w-full h-11 pl-10 pr-4 bg-mn-surface border border-white/7 rounded-input text-mn-ink placeholder:text-mn-ghost text-sm focus:outline-none focus:border-mn-amber/30 focus:shadow-input-focus transition-all"
                  />
                </div>
              </div>
            )}

            {/* Email */}
            {mode !== 'reset' && (
              <div>
                <label htmlFor="auth-email" className="block text-xs font-medium tracking-[0.12em] uppercase mb-1.5" style={{ color: 'rgba(245,240,232,0.55)' }}>
                  {t('email')}
                </label>
                <div className="relative">
                  <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-ghost pointer-events-none" aria-hidden="true" />
                  <input
                    id="auth-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder={t('emailPlaceholder')}
                    required
                    autoComplete="email"
                    disabled={mode === 'forgot' && resetSent}
                    className="w-full h-11 pl-10 pr-4 bg-mn-surface border border-white/7 rounded-input text-mn-ink placeholder:text-mn-ghost text-sm focus:outline-none focus:border-mn-amber/30 focus:shadow-input-focus transition-all disabled:opacity-50"
                  />
                </div>
              </div>
            )}

            {/* Password */}
            {mode !== 'forgot' && (
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label htmlFor="auth-password" className="block text-xs font-medium tracking-[0.12em] uppercase" style={{ color: 'rgba(245,240,232,0.55)' }}>
                    {mode === 'reset' ? t('passwordNewLabel') : t('passwordLabel')}
                  </label>
                  {mode === 'login' && (
                    <Link href="/auth?mode=forgot" className="text-xs font-medium text-mn-teal-soft hover:text-mn-teal transition-colors">
                      {t('forgotLink')}
                    </Link>
                  )}
                </div>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-ghost pointer-events-none" aria-hidden="true" />
                  <input
                    id="auth-password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={mode === 'login' ? t('passwordPlaceholder') : t('passwordNewPlaceholder')}
                    required
                    autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                    className="w-full h-11 pl-10 pr-11 bg-mn-surface border border-white/7 rounded-input text-mn-ink placeholder:text-mn-ghost text-sm focus:outline-none focus:border-mn-amber/30 focus:shadow-input-focus transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-mn-ghost hover:text-mn-ink-soft transition-colors"
                    aria-label={showPassword ? t('hidePassword') : t('showPassword')}
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
                {(mode === 'register' || mode === 'reset') && password.length > 0 && (
                  <div className="mt-3">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="flex-1 h-1 rounded-full bg-mn-surface overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all duration-500 ease-out"
                          style={{
                            width: `${(pwScore / 4) * 100}%`,
                            backgroundColor: pwScore <= 1 ? '#EF4444' : pwScore <= 2 ? '#F59E0B' : pwScore <= 3 ? '#0EA5E9' : '#22C55E',
                          }}
                        />
                      </div>
                      <span className="text-[9px] font-mono uppercase tracking-widest text-mn-mute w-14 text-right">
                        {pwScore <= 1 ? t('pwWeak') : pwScore <= 2 ? t('pwFair') : pwScore <= 3 ? t('pwGood') : t('pwStrong')}
                      </span>
                    </div>
                    <div className="space-y-1">
                      {checks.map((check, i) => (
                        <div key={i} className={`flex items-center gap-2 text-[11px] transition-colors ${check.ok ? 'text-mn-leben-soft' : 'text-mn-mute'}`}>
                          <CheckCircle2 className={`w-3.5 h-3.5 transition-colors ${check.ok ? 'text-mn-leben' : 'text-mn-ghost'}`} aria-hidden="true" />
                          {check.label}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Password confirm (reset only) */}
            {mode === 'reset' && (
              <div>
                <label htmlFor="auth-password-confirm" className="block text-xs font-medium tracking-[0.12em] uppercase mb-1.5" style={{ color: 'rgba(245,240,232,0.55)' }}>
                  {t('confirmPassword')}
                </label>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-mn-ghost pointer-events-none" aria-hidden="true" />
                  <input
                    id="auth-password-confirm"
                    type={showPassword ? 'text' : 'password'}
                    value={passwordConfirm}
                    onChange={(e) => setPasswordConfirm(e.target.value)}
                    placeholder={t('passwordConfirmPlaceholder')}
                    required
                    autoComplete="new-password"
                    className="w-full h-11 pl-10 pr-4 bg-mn-surface border border-white/7 rounded-input text-mn-ink placeholder:text-mn-ghost text-sm focus:outline-none focus:border-mn-amber/30 focus:shadow-input-focus transition-all"
                  />
                </div>
              </div>
            )}

            {/* Agreement (register only) */}
            {mode === 'register' && (
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => setAgreed(e.target.checked)}
                  className="mt-0.5 w-4 h-4 rounded border-white/20 bg-mn-surface accent-mn-amber focus:ring-mn-amber"
                />
                <span className="text-[11px] text-mn-mute leading-relaxed">
                  {t('agreePrefix')}{' '}
                  <Link href="/nutzungsbedingungen" className="text-mn-teal-soft hover:text-mn-teal transition-colors">
                    {t('termsLinkText')}
                  </Link>{' '}
                  {t('agreeMiddle')}{' '}
                  <Link href="/datenschutz" className="text-mn-teal-soft hover:text-mn-teal transition-colors">
                    {t('privacyLinkText')}
                  </Link>{' '}
                  {t('agreeSuffix')}
                </span>
              </label>
            )}

            {/* Rate-limit warning */}
            {lockUntil && secondsLeft > 0 && (
              <p className="text-xs font-mono uppercase text-mn-herzrot-warm text-center tracking-widest">
                {t('rateLimitWarning', { seconds: secondsLeft })}
              </p>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading || (mode === 'forgot' && resetSent) || (!!lockUntil && Date.now() < lockUntil)}
              className="group w-full flex items-center justify-center gap-2 h-12 rounded-button text-sm font-medium tracking-wide transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-mn-amber"
              style={{
                background: 'linear-gradient(135deg, #F59E0B, #FBBF24)',
                color: '#0A0F1C',
                boxShadow: '0 4px 16px rgba(245,158,11,0.35), 0 0 40px rgba(245,158,11,0.12)',
              }}
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 border-2 border-mn-void/30 border-t-mn-void rounded-full animate-spin" aria-hidden="true" />
                  {mode === 'login'    && t('btnLoginLoading')}
                  {mode === 'register' && t('btnRegisterLoading')}
                  {mode === 'forgot'   && t('btnForgotLoading')}
                  {mode === 'reset'    && t('btnResetLoading')}
                </>
              ) : (
                <>
                  {mode === 'login'    && (lockUntil ? t('btnLocked', { seconds: secondsLeft }) : t('btnLogin'))}
                  {mode === 'register' && t('btnRegister')}
                  {mode === 'forgot'   && (resetSent ? t('btnLinkSent') : t('btnSendLink'))}
                  {mode === 'reset'    && t('btnSavePassword')}
                  <span className="transition-transform group-hover:translate-x-0.5">→</span>
                </>
              )}
            </button>
          </form>

          {/* Toggle mode */}
          <div className="mt-8 pt-6 border-t text-center" style={{ borderColor: 'rgba(245,240,232,0.08)' }}>
            <p className="text-[11px] tracking-wide text-mn-mute">
              {mode === 'login' && (
                <>
                  {t('noAccountYet')}{' '}
                  <Link href="/auth?mode=register" className="font-semibold text-mn-teal-soft hover:text-mn-teal transition-colors">
                    {t('registerNow')}
                  </Link>
                </>
              )}
              {mode === 'register' && (
                <>
                  {t('alreadyRegistered')}{' '}
                  <Link href="/auth?mode=login" className="font-semibold text-mn-teal-soft hover:text-mn-teal transition-colors">
                    {t('login')}
                  </Link>
                </>
              )}
              {mode === 'forgot' && (
                <>
                  {t('rememberPassword')}{' '}
                  <Link href="/auth?mode=login" className="font-semibold text-mn-teal-soft hover:text-mn-teal transition-colors">
                    {t('backToLogin')}
                  </Link>
                </>
              )}
              {mode === 'reset' && !recoverySession && (
                <span style={{ color: 'rgba(245,158,11,0.65)' }}>{t('resetLinkHint')}</span>
              )}
              {mode === 'reset' && recoverySession && (
                <Link href="/auth?mode=login" className="font-semibold text-mn-teal-soft hover:text-mn-teal transition-colors">
                  {t('cancelReset')}
                </Link>
              )}
            </p>
          </div>
        </div>

        <div className="text-center mt-8">
          <Link href="/" className="text-xs font-medium text-mn-mute hover:text-mn-ink-soft transition-colors tracking-wide">
            {t('backToHome')}
          </Link>
        </div>
      </div>
    </div>
  )
}
