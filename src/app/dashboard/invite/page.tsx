'use client'

import { useEffect, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import toast from 'react-hot-toast'
import {
  Share2, Copy, Check, MessageCircle, Mail, Users,
  Award, ArrowLeft, Smartphone,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn, formatRelativeTime } from '@/lib/utils'
import { useAuthStore } from '@/store/useAuthStore'
import Card from '@/components/ui/Card'
import Button from '@/components/ui/Button'
import Badge from '@/components/ui/Badge'
import Avatar from '@/components/ui/Avatar'
import SectionHeader from '@/components/ui/SectionHeader'

// ── Types ────────────────────────────────────────────────────────────────────

interface AcceptedReferral {
  invitee_id: string
  accepted_at: string
  invitee: {
    display_name: string | null
    avatar_url: string | null
  } | null
}

// ── Constants ────────────────────────────────────────────────────────────────

const BADGE_THRESHOLD = 3
const BASE_URL = 'https://www.mensaena.de'

// ── Page ─────────────────────────────────────────────────────────────────────

export default function InvitePage() {
  const router = useRouter()
  const { user, initialized, init } = useAuthStore()

  const [inviteCode, setInviteCode]           = useState<string | null>(null)
  const [acceptedCount, setAcceptedCount]     = useState(0)
  const [sentCount, setSentCount]             = useState(0)
  const [acceptedList, setAcceptedList]       = useState<AcceptedReferral[]>([])
  const [loading, setLoading]                 = useState(true)
  const [copied, setCopied]                   = useState(false)

  // Init auth
  useEffect(() => { if (!initialized) init() }, [initialized, init])

  // Auth guard
  useEffect(() => {
    if (initialized && !user) router.replace('/login')
  }, [initialized, user, router])

  // Load data
  const loadData = useCallback(async () => {
    if (!user) return
    setLoading(true)
    const supabase = createClient()

    try {
      // Pending invite code – create one if none exists
      const { data: pending } = await supabase
        .from('referrals')
        .select('invite_code')
        .eq('inviter_id', user.id)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle()

      let code = pending?.invite_code ?? null
      if (!code) {
        code = crypto.randomUUID()
        await supabase.from('referrals').insert({
          inviter_id: user.id,
          invite_code: code,
          status: 'pending',
        })
      }
      setInviteCode(code)

      // Accepted count
      const { count: accepted } = await supabase
        .from('referrals')
        .select('*', { count: 'exact', head: true })
        .eq('inviter_id', user.id)
        .eq('status', 'accepted')

      setAcceptedCount(accepted ?? 0)

      // Pending count (all pending codes = "versendet")
      const { count: pCount } = await supabase
        .from('referrals')
        .select('*', { count: 'exact', head: true })
        .eq('inviter_id', user.id)
        .eq('status', 'pending')

      setSentCount(pCount ?? 0)

      // Accepted list with invitee profiles
      const { data: list } = await supabase
        .from('referrals')
        .select(`
          invitee_id,
          accepted_at,
          invitee:profiles!referrals_invitee_id_fkey(display_name, avatar_url)
        `)
        .eq('inviter_id', user.id)
        .eq('status', 'accepted')
        .order('accepted_at', { ascending: false })

      setAcceptedList((list as AcceptedReferral[]) ?? [])
    } catch {
      toast.error('Fehler beim Laden der Einladungsdaten')
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => { if (user) loadData() }, [user, loadData])

  // Derived values
  const inviteUrl  = inviteCode ? `${BASE_URL}/register?ref=${inviteCode}` : ''
  const progress   = Math.min((acceptedCount / BADGE_THRESHOLD) * 100, 100)
  const remaining  = Math.max(BADGE_THRESHOLD - acceptedCount, 0)
  const hasBadge   = acceptedCount >= BADGE_THRESHOLD
  const shareText  = encodeURIComponent(
    `Ich nutze Mensaena – die Nachbarschaftshilfe-Plattform! Tritt kostenlos bei: ${inviteUrl}`
  )

  const handleCopy = async () => {
    if (!inviteUrl) return
    try {
      await navigator.clipboard.writeText(inviteUrl)
      setCopied(true)
      toast.success('Link kopiert!')
      setTimeout(() => setCopied(false), 2000)
    } catch {
      toast.error('Kopieren fehlgeschlagen')
    }
  }

  // ── Loading skeleton ─────────────────────────────────────────────────────

  if (!initialized || loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8 space-y-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="h-28 rounded-2xl bg-stone-100 animate-pulse" />
        ))}
      </div>
    )
  }

  if (!user) return null

  // ── UI ───────────────────────────────────────────────────────────────────

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 space-y-6">

      {/* Header */}
      <div>
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-1.5 text-sm text-ink-500 hover:text-primary-600 transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück zum Dashboard
        </Link>
        <h1 className="text-2xl font-bold text-ink-900">Nachbar:innen einladen</h1>
        <p className="text-sm text-ink-500 mt-1">
          Lade Freunde und Nachbarn ein – und werde Nachbarschafts-Botschafter:in.
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { value: sentCount,      label: 'Versendet',      color: 'text-primary-600' },
          { value: acceptedCount,  label: 'Angenommen',     color: 'text-green-600'   },
          { value: remaining,      label: 'Bis zum Badge',  color: 'text-amber-500'   },
        ].map(({ value, label, color }) => (
          <Card key={label} variant="stat" className="text-center py-4">
            <div className={cn('text-2xl font-bold tabular-nums', color)}>{value}</div>
            <div className="text-xs text-ink-500 mt-0.5 leading-tight">{label}</div>
          </Card>
        ))}
      </div>

      {/* Fortschrittsbalken – Botschafter-Badge */}
      <Card variant="default">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Award className={cn('w-5 h-5', hasBadge ? 'text-amber-500' : 'text-ink-400')} />
            <span className="text-sm font-medium text-ink-800">
              Nachbarschafts-Botschafter:in
            </span>
          </div>
          {hasBadge && (
            <Badge variant="warning" size="sm" icon={<Award className="w-3 h-3" />}>
              Erreicht!
            </Badge>
          )}
        </div>

        <div className="w-full bg-stone-100 rounded-full h-2 overflow-hidden">
          <div
            className="h-2 rounded-full bg-gradient-to-r from-primary-400 to-primary-600 transition-all duration-700"
            style={{ width: `${progress}%` }}
          />
        </div>

        <p className="text-xs text-ink-500 mt-2">
          {hasBadge
            ? '🎉 Badge freigeschaltet! Du bist jetzt Nachbarschafts-Botschafter:in.'
            : `${acceptedCount} von ${BADGE_THRESHOLD} Einladungen angenommen`}
        </p>
      </Card>

      {/* Einladungslink */}
      <Card variant="default">
        <SectionHeader
          title="Dein Einladungslink"
          subtitle="Teile diesen Link – jede Registrierung zählt"
          icon={<Share2 className="w-4 h-4" />}
          className="mb-4"
        />

        {/* Link + Copy */}
        <div className="flex items-center gap-2 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2.5 mb-3">
          <span className="text-xs text-ink-600 truncate flex-1 font-mono select-all">
            {inviteUrl}
          </span>
          <button
            onClick={handleCopy}
            className={cn(
              'flex-shrink-0 p-1.5 rounded-lg transition-all',
              copied
                ? 'bg-green-100 text-green-600'
                : 'bg-white border border-stone-200 text-ink-500 hover:text-primary-600 hover:border-primary-300',
            )}
            aria-label="Link kopieren"
          >
            {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>

        {/* Share buttons */}
        <div className="grid grid-cols-3 gap-2">
          <a
            href={`https://wa.me/?text=${shareText}`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-green-50 hover:bg-green-100 border border-green-200 text-green-700 transition-colors"
          >
            <MessageCircle className="w-5 h-5" />
            <span className="text-xs font-medium">WhatsApp</span>
          </a>
          <a
            href={`mailto:?subject=${encodeURIComponent('Ich lade dich zu Mensaena ein!')}&body=${shareText}`}
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-blue-50 hover:bg-blue-100 border border-blue-200 text-blue-700 transition-colors"
          >
            <Mail className="w-5 h-5" />
            <span className="text-xs font-medium">E-Mail</span>
          </a>
          <a
            href={`sms:?body=${shareText}`}
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-purple-50 hover:bg-purple-100 border border-purple-200 text-purple-700 transition-colors"
          >
            <Smartphone className="w-5 h-5" />
            <span className="text-xs font-medium">SMS</span>
          </a>
        </div>
      </Card>

      {/* Angenommene Einladungen */}
      {acceptedList.length > 0 && (
        <Card variant="default">
          <SectionHeader
            title="Angenommene Einladungen"
            icon={<Users className="w-4 h-4" />}
            className="mb-4"
          />
          <ul className="space-y-3">
            {acceptedList.map((r) => (
              <li key={r.invitee_id} className="flex items-center gap-3">
                <Avatar
                  src={r.invitee?.avatar_url}
                  name={r.invitee?.display_name}
                  size="sm"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-ink-800 truncate">
                    {r.invitee?.display_name ?? 'Nachbar:in'}
                  </p>
                  <p className="text-xs text-ink-400">
                    {r.accepted_at ? formatRelativeTime(r.accepted_at) : ''}
                  </p>
                </div>
                <Award className="w-4 h-4 text-amber-400 flex-shrink-0" aria-label="Badge" />
              </li>
            ))}
          </ul>
        </Card>
      )}

      {/* Motivations-Karte */}
      <Card variant="accent" className="text-center py-8">
        <div className="text-4xl mb-3" aria-hidden="true">🏘️</div>
        <h3 className="font-semibold text-ink-800">
          Jede Einladung stärkt deine Nachbarschaft
        </h3>
        <p className="text-sm text-ink-500 mt-1.5 max-w-xs mx-auto">
          Gemeinsam machen wir Mensaena zu einer lebendigen Gemeinschaft –
          eine Einladung nach der anderen.
        </p>
      </Card>

    </div>
  )
}
