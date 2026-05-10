'use client'

import { useEffect, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import toast from 'react-hot-toast'
import {
  Share2, Copy, Check, MessageCircle, Mail, Users,
  Award, ArrowLeft, Smartphone, CreditCard,
  Edit3,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn, formatRelativeTime } from '@/lib/utils'
import { useAuthStore } from '@/store/useAuthStore'
import Card from '@/components/ui/Card'
import Badge from '@/components/ui/Badge'
import Avatar from '@/components/ui/Avatar'
import SectionHeader from '@/components/ui/SectionHeader'
import FlyerSection from './components/FlyerSection'
import LeaderboardCard, { type LeaderboardEntry } from './components/LeaderboardCard'
import LocalChallengeCard from './components/LocalChallengeCard'

// ── Types ────────────────────────────────────────────────────────────────────

interface AcceptedReferral {
  invitee_id: string
  accepted_at: string
  invitee: { display_name: string | null; avatar_url: string | null } | null
}

interface ReferralRow {
  inviter_id: string
  inviter: { display_name: string | null; avatar_url: string | null } | null
}

// ── Constants ────────────────────────────────────────────────────────────────

const BASE_URL = 'https://www.mensaena.de'

const BADGE_LEVELS = [
  { min: 3,  key: 'bronze',  label: 'Bronze',   emoji: '🥉', color: 'text-mn-amber-warm', bg: 'bg-mn-surface', border: 'border-white/8' },
  { min: 10, key: 'silver',  label: 'Silber',   emoji: '🥈', color: 'text-mn-ink-soft',  bg: 'bg-mn-surface',  border: 'border-white/5'  },
  { min: 25, key: 'gold',    label: 'Gold',     emoji: '🥇', color: 'text-amber-700',  bg: 'bg-amber-50',  border: 'border-amber-200'  },
  { min: 50, key: 'legend',  label: 'Legende',  emoji: '👑', color: 'text-mn-amber', bg: 'bg-mn-surface', border: 'border-white/5' },
]

// ── Helpers ──────────────────────────────────────────────────────────────────

function generateVCard(name: string, inviteUrl: string): string {
  return [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${name} (Mensaena)`,
    `NOTE:Ich bin auf Mensaena – der Nachbarschaftshilfe-Plattform. Tritt bei: ${inviteUrl}`,
    `URL:${inviteUrl}`,
    'END:VCARD',
  ].join('\r\n')
}

function downloadVCard(name: string, inviteUrl: string) {
  const vcf = generateVCard(name, inviteUrl)
  const blob = new Blob([vcf], { type: 'text/vcard;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'mensaena-kontakt.vcf'
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function InvitePage() {
  const router = useRouter()
  const { user, profile, initialized, init } = useAuthStore()

  const [inviteCode, setInviteCode]       = useState<string | null>(null)
  const [acceptedCount, setAcceptedCount] = useState(0)
  const [sentCount, setSentCount]         = useState(0)
  const [acceptedList, setAcceptedList]   = useState<AcceptedReferral[]>([])
  const [leaderboard, setLeaderboard]     = useState<LeaderboardEntry[]>([])
  const [neighborCount, setNeighborCount] = useState(0)
  const [postalCode, setPostalCode]       = useState('')
  const [city, setCity]                   = useState('')
  const [personalMsg, setPersonalMsg]     = useState('')
  const [loading, setLoading]             = useState(true)
  const [copied, setCopied]               = useState(false)

  useEffect(() => { if (!initialized) init() }, [initialized, init])
  useEffect(() => { if (initialized && !user) router.replace('/login') }, [initialized, user, router])

  const loadData = useCallback(async () => {
    if (!user) return
    setLoading(true)
    const supabase = createClient()

    try {
      // ── Invite code ──────────────────────────────────────────────────────
      const { data: pending } = await supabase
        .from('referrals').select('invite_code')
        .eq('inviter_id', user.id).eq('status', 'pending').limit(1).maybeSingle()

      let code = pending?.invite_code ?? null
      if (!code) {
        code = crypto.randomUUID()
        await supabase.from('referrals').insert({ inviter_id: user.id, invite_code: code, status: 'pending' })
      }
      setInviteCode(code)

      // ── Accepted count & list ────────────────────────────────────────────
      const [{ count: accepted }, { count: pCount }, { data: list }] = await Promise.all([
        supabase.from('referrals').select('*', { count: 'exact', head: true })
          .eq('inviter_id', user.id).eq('status', 'accepted'),
        supabase.from('referrals').select('*', { count: 'exact', head: true })
          .eq('inviter_id', user.id).eq('status', 'pending'),
        supabase.from('referrals')
          .select('invitee_id, accepted_at, invitee:profiles!referrals_invitee_id_fkey(display_name, avatar_url)')
          .eq('inviter_id', user.id).eq('status', 'accepted').order('accepted_at', { ascending: false }),
      ])
      setAcceptedCount(accepted ?? 0)
      setSentCount(pCount ?? 0)
      setAcceptedList((list as AcceptedReferral[]) ?? [])

      // ── User location ────────────────────────────────────────────────────
      const { data: userProfile } = await supabase
        .from('profiles').select('home_postal_code, home_city')
        .eq('id', user.id).maybeSingle()

      const plz = userProfile?.home_postal_code ?? ''
      const userCity = userProfile?.home_city ?? ''
      setPostalCode(plz)
      setCity(userCity)

      // ── Neighbor count in same PLZ ───────────────────────────────────────
      if (plz) {
        const { count: nc } = await supabase
          .from('profiles').select('*', { count: 'exact', head: true })
          .eq('home_postal_code', plz)
        setNeighborCount(nc ?? 0)
      }

      // ── Leaderboard (client-side aggregation) ────────────────────────────
      const { data: topData } = await supabase
        .from('referrals')
        .select('inviter_id, inviter:profiles!referrals_inviter_id_fkey(display_name, avatar_url)')
        .eq('status', 'accepted')
        .limit(500)

      const inviterMap = new Map<string, { count: number; display_name: string | null; avatar_url: string | null }>()
      ;(topData as ReferralRow[] | null)?.forEach((r) => {
        const id = r.inviter_id
        if (!inviterMap.has(id)) {
          inviterMap.set(id, { count: 0, display_name: r.inviter?.display_name ?? null, avatar_url: r.inviter?.avatar_url ?? null })
        }
        inviterMap.get(id)!.count++
      })
      const board: LeaderboardEntry[] = Array.from(inviterMap.entries())
        .map(([id, d]) => ({ id, ...d, isCurrentUser: id === user.id }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5)
      setLeaderboard(board)

    } catch {
      toast.error('Fehler beim Laden der Einladungsdaten')
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => { if (user) loadData() }, [user, loadData])

  // ── Derived values ────────────────────────────────────────────────────────

  const inviteUrl     = inviteCode ? `${BASE_URL}/register?ref=${inviteCode}` : ''
  const displayName   = profile?.display_name ?? user?.email?.split('@')[0] ?? 'Nachbar:in'
  const msgSuffix     = personalMsg.trim() ? ` – ${personalMsg.trim()}` : ''
  const shareText     = encodeURIComponent(
    `${displayName} lädt dich zu Mensaena ein${msgSuffix}! Tritt kostenlos bei: ${inviteUrl}`
  )

  const currentLevel  = BADGE_LEVELS.filter(l => acceptedCount >= l.min).at(-1) ?? null
  const nextLevel     = BADGE_LEVELS.find(l => acceptedCount < l.min) ?? null
  const nextGoal      = nextLevel?.min ?? BADGE_LEVELS.at(-1)!.min
  const progress      = Math.min((acceptedCount / nextGoal) * 100, 100)

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

  // ── Loading skeleton ──────────────────────────────────────────────────────

  if (!initialized || loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8 space-y-4">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="h-28 rounded-2xl bg-mn-elevated animate-pulse" />
        ))}
      </div>
    )
  }

  if (!user) return null

  // ── UI ────────────────────────────────────────────────────────────────────

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 space-y-5">

      {/* Header */}
      <div>
        <Link href="/dashboard" className="inline-flex items-center gap-1.5 text-sm text-mn-mute hover:text-mn-amber transition-colors mb-4">
          <ArrowLeft className="w-4 h-4" />
          Zurück zum Dashboard
        </Link>
        <h1 className="text-2xl font-bold text-mn-ink">Nachbar:innen einladen</h1>
        <p className="text-sm text-mn-mute mt-1">Lade Freunde und Nachbarn ein – und werde Nachbarschafts-Botschafter:in.</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { value: sentCount,     label: 'Versendet',     color: 'text-mn-amber' },
          { value: acceptedCount, label: 'Angenommen',    color: 'text-mn-leben'   },
          { value: neighborCount || '–', label: 'In deiner PLZ', color: 'text-mn-teal-soft' },
        ].map(({ value, label, color }) => (
          <Card key={label} variant="stat" className="text-center py-4">
            <div className={cn('text-2xl font-bold tabular-nums', color)}>{value}</div>
            <div className="text-xs text-mn-mute mt-0.5 leading-tight">{label}</div>
          </Card>
        ))}
      </div>

      {/* ── B: Stufenbadges ─────────────────────────────────────────────────── */}
      <Card variant="default">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Award className={cn('w-5 h-5', currentLevel ? 'text-amber-500' : 'text-mn-mute')} />
            <span className="text-sm font-semibold text-mn-ink">
              {currentLevel ? `${currentLevel.emoji} ${currentLevel.label}-Botschafter:in` : 'Nachbarschafts-Botschafter:in'}
            </span>
          </div>
          {currentLevel && (
            <Badge variant="warning" size="sm" icon={<Award className="w-3 h-3" />}>
              {currentLevel.label}
            </Badge>
          )}
        </div>

        {/* Progress to next level */}
        <div className="w-full bg-mn-elevated rounded-full h-2 overflow-hidden mb-2">
          <div
            className="h-2 rounded-full bg-gradient-to-r from-primary-400 to-primary-600 transition-all duration-700"
            style={{ width: `${progress}%` }}
          />
        </div>
        <p className="text-xs text-mn-mute mb-4">
          {nextLevel
            ? `${acceptedCount} / ${nextGoal} – noch ${nextGoal - acceptedCount} für ${nextLevel.emoji} ${nextLevel.label}`
            : `👑 Maximales Level erreicht! Du bist eine Nachbarschafts-Legende.`}
        </p>

        {/* Level overview */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          {BADGE_LEVELS.map((lvl) => {
            const earned = acceptedCount >= lvl.min
            return (
              <div
                key={lvl.key}
                className={cn(
                  'text-center px-2 py-2.5 rounded-xl border text-xs font-medium transition-all',
                  earned ? `${lvl.bg} ${lvl.border} ${lvl.color}` : 'bg-mn-surface border-white/5 text-mn-mute',
                )}
              >
                <div className="text-lg mb-0.5">{lvl.emoji}</div>
                <div className="font-semibold">{lvl.label}</div>
                <div className="opacity-75">{lvl.min}+ Einl.</div>
              </div>
            )
          })}
        </div>
      </Card>

      {/* ── D: Persönliche Einladungs-Nachricht + Einladungslink ─────────────── */}
      <Card variant="default">
        <SectionHeader
          title="Dein Einladungslink"
          subtitle="Teile diesen Link – jede Registrierung zählt"
          icon={<Share2 className="w-4 h-4" />}
          className="mb-4"
        />

        {/* D: Personal message */}
        <div className="mb-4">
          <label className="flex items-center gap-1.5 text-xs font-medium text-mn-ink-soft mb-1.5">
            <Edit3 className="w-3.5 h-3.5" />
            Persönliche Nachricht (optional)
          </label>
          <textarea
            value={personalMsg}
            onChange={(e) => setPersonalMsg(e.target.value)}
            placeholder="z.B. Komm, wir helfen uns gegenseitig in der Gartenstraße!"
            maxLength={120}
            rows={2}
            className="w-full text-sm text-mn-ink-soft bg-mn-surface border border-white/5 rounded-xl px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-primary-300 focus:border-primary-300 placeholder:text-mn-mute"
          />
          <p className="text-xs text-mn-mute mt-1 text-right">{personalMsg.length}/120</p>
        </div>

        {/* Link + Copy */}
        <div className="flex items-center gap-2 bg-mn-surface border border-white/5 rounded-xl px-3 py-2.5 mb-3">
          <span className="text-xs text-mn-ink-soft truncate flex-1 font-mono select-all">{inviteUrl}</span>
          <button
            onClick={handleCopy}
            className={cn(
              'flex-shrink-0 p-1.5 rounded-lg transition-all',
              copied
                ? 'bg-mn-elevated text-mn-leben'
                : 'bg-mn-elevated border border-white/5 text-mn-mute hover:text-mn-amber hover:border-primary-300',
            )}
            aria-label="Link kopieren"
          >
            {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>

        {/* Share buttons */}
        <div className="grid grid-cols-3 gap-2 mb-3">
          <a
            href={`https://wa.me/?text=${shareText}`}
            target="_blank" rel="noopener noreferrer"
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-mn-surface hover:bg-mn-elevated border border-white/5 text-mn-leben transition-colors"
          >
            <MessageCircle className="w-5 h-5" />
            <span className="text-xs font-medium">WhatsApp</span>
          </a>
          <a
            href={`mailto:?subject=${encodeURIComponent(`${displayName} lädt dich zu Mensaena ein!`)}&body=${shareText}`}
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-mn-surface hover:bg-mn-elevated border border-white/5 text-mn-teal-soft transition-colors"
          >
            <Mail className="w-5 h-5" />
            <span className="text-xs font-medium">E-Mail</span>
          </a>
          <a
            href={`sms:?body=${shareText}`}
            className="flex flex-col items-center gap-1.5 p-3 rounded-xl bg-mn-surface hover:bg-mn-elevated border border-white/5 text-mn-amber transition-colors"
          >
            <Smartphone className="w-5 h-5" />
            <span className="text-xs font-medium">SMS</span>
          </a>
        </div>

        {/* F: VCard download */}
        <button
          onClick={() => downloadVCard(displayName, inviteUrl)}
          className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-mn-surface hover:bg-mn-elevated border border-white/5 text-mn-ink-soft text-sm font-medium transition-colors"
        >
          <CreditCard className="w-4 h-4" />
          Digitale Visitenkarte (.vcf) herunterladen
        </button>
      </Card>

      {/* ── C + G: Straßen-Challenge & Social Proof ──────────────────────────── */}
      {postalCode && (
        <LocalChallengeCard
          city={city}
          postalCode={postalCode}
          neighborCount={neighborCount}
          challengeGoal={5}
        />
      )}

      {/* ── Flyer (A, B, C, D, H) ────────────────────────────────────────────── */}
      {inviteUrl && (
        <FlyerSection
          inviteUrl={inviteUrl}
          userName={displayName}
          city={city}
        />
      )}

      {/* ── A: Botschafter-Rangliste ─────────────────────────────────────────── */}
      {leaderboard.length > 0 && <LeaderboardCard entries={leaderboard} />}

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
                <Avatar src={r.invitee?.avatar_url} name={r.invitee?.display_name} size="sm" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-mn-ink truncate">
                    {r.invitee?.display_name ?? 'Nachbar:in'}
                  </p>
                  <p className="text-xs text-mn-mute">
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
        <h3 className="font-semibold text-mn-ink">Jede Einladung stärkt deine Nachbarschaft</h3>
        <p className="text-sm text-mn-mute mt-1.5 max-w-xs mx-auto">
          Gemeinsam machen wir Mensaena zu einer lebendigen Gemeinschaft –
          eine Einladung nach der anderen.
        </p>
      </Card>

    </div>
  )
}
