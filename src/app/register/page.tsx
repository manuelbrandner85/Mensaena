'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Leaf, Eye, EyeOff, Mail, Lock, User, AlertCircle, CheckCircle2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'

const passwordChecks = (pw: string) => [
  { label: 'Mindestens 8 Zeichen', ok: pw.length >= 8 },
  { label: 'Groß- und Kleinbuchstaben', ok: /[a-z]/.test(pw) && /[A-Z]/.test(pw) },
  { label: 'Mindestens eine Zahl', ok: /\d/.test(pw) },
]

export default function RegisterPage() {
  const router = useRouter()
  const [name, setName]                 = useState('')
  const [email, setEmail]               = useState('')
  const [password, setPassword]         = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading]           = useState(false)
  const [checking, setChecking]         = useState(true)
  const [error, setError]               = useState('')
  const [agreed, setAgreed]             = useState(false)

  const checks = passwordChecks(password)

  // Bereits eingeloggt? → direkt zum Dashboard
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

    // Prüfen ob E-Mail schon registriert ist
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

    // Registrierung ohne E-Mail-Bestätigung
    const { data, error: signUpError } = await supabase.auth.signUp({
      email: email.toLowerCase().trim(),
      password,
      options: {
        data: { full_name: name },
        // emailRedirectTo wird nicht gesetzt → kein Bestätigungslink nötig
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

    // Erfolgreich registriert und Session vorhanden → direkt zum Dashboard
    if (data?.session) {
      toast.success('Willkommen bei Mensaena! 🌿')
      router.replace('/dashboard')
      return
    }

    // Kein Session-Objekt (kann passieren wenn E-Mail-Bestätigung in Supabase noch aktiv ist)
    // → Hinweis anzeigen
    setError(
      'Fast geschafft! Bitte deaktiviere in Supabase unter Authentication → Providers → Email die Option "Confirm email", damit du dich direkt einloggen kannst.'
    )
    setLoading(false)
  }

  // Ladescreen während Session-Check
  if (checking) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-[3px] border-primary-200 border-t-primary-600 rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen hero-gradient flex items-center justify-center px-4 py-12">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 bg-primary-200/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-trust-100/30 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <Link href="/" className="flex items-center justify-center gap-2.5 mb-8">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary-500 to-primary-700 flex items-center justify-center shadow-md">
            <Leaf className="w-5 h-5 text-white" />
          </div>
          <span className="text-2xl font-bold text-gray-900">Mensaena</span>
        </Link>

        <div className="card p-8 shadow-hover">
          <div className="mb-7">
            <h1 className="text-2xl font-bold text-gray-900 mb-2">Konto erstellen</h1>
            <p className="text-sm text-gray-600">Kostenlos registrieren und Teil der Gemeinschaft werden.</p>
          </div>

          {error && (
            <div className="flex items-start gap-3 p-3 bg-red-50 border border-red-200 rounded-xl mb-5 text-sm text-red-700">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleRegister} className="space-y-5">
            {/* Name */}
            <div>
              <label className="label">Vollständiger Name</label>
              <div className="relative">
                <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Dein Name"
                  required
                  className="input pl-10"
                />
              </div>
            </div>

            {/* Email */}
            <div>
              <label className="label">E-Mail-Adresse</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="deine@email.de"
                  required
                  className="input pl-10"
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <label className="label">Passwort</label>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Sicheres Passwort wählen"
                  required
                  className="input pl-10 pr-12"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {/* Password Checks */}
              {password.length > 0 && (
                <div className="mt-2.5 space-y-1">
                  {checks.map((check, i) => (
                    <div key={i} className={`flex items-center gap-2 text-xs ${check.ok ? 'text-primary-600' : 'text-gray-400'}`}>
                      <CheckCircle2 className={`w-3.5 h-3.5 ${check.ok ? 'text-primary-500' : 'text-gray-300'}`} />
                      {check.label}
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Agree */}
            <label className="flex items-start gap-3 cursor-pointer group">
              <input
                type="checkbox"
                checked={agreed}
                onChange={(e) => setAgreed(e.target.checked)}
                className="mt-0.5 w-4 h-4 rounded border-gray-300 text-primary-600 focus:ring-primary-500"
              />
              <span className="text-xs text-gray-600 leading-relaxed">
                Ich stimme den{' '}
                <Link href="/nutzungsbedingungen" className="text-primary-600 underline hover:text-primary-700">
                  Nutzungsbedingungen
                </Link>{' '}
                und der{' '}
                <Link href="/datenschutz" className="text-primary-600 underline hover:text-primary-700">
                  Datenschutzerklärung
                </Link>{' '}
                zu.
              </span>
            </label>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full justify-center py-3.5 text-base"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  Registrieren…
                </>
              ) : (
                'Kostenlos registrieren'
              )}
            </button>
          </form>

          <p className="text-center text-sm text-gray-600 mt-6">
            Bereits registriert?{' '}
            <Link href="/login" className="font-semibold text-primary-600 hover:text-primary-700">
              Anmelden →
            </Link>
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
