'use client'

import { useState, useEffect } from 'react'
import {
  Award, Star, Trophy, Target, Heart, Shield, Zap, Crown,
  Users, MessageCircle, Calendar, Flame, BookOpen, Sprout,
  Clock, Lock,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

// ── Types ──────────────────────────────────────────────────────
interface Badge {
  id: string
  name: string
  description: string
  icon: string
  category: string
  requirement_type: string
  requirement_value: number
  points: number
  rarity: string
}

interface UserBadge {
  badge_id: string
  earned_at: string
}

// ── Badge Icon Mapping ──────────────────────────────────────────
const BADGE_ICONS: Record<string, React.ReactNode> = {
  star: <Star className="w-6 h-6" />,
  trophy: <Trophy className="w-6 h-6" />,
  target: <Target className="w-6 h-6" />,
  heart: <Heart className="w-6 h-6" />,
  shield: <Shield className="w-6 h-6" />,
  zap: <Zap className="w-6 h-6" />,
  crown: <Crown className="w-6 h-6" />,
  users: <Users className="w-6 h-6" />,
  message: <MessageCircle className="w-6 h-6" />,
  calendar: <Calendar className="w-6 h-6" />,
  flame: <Flame className="w-6 h-6" />,
  book: <BookOpen className="w-6 h-6" />,
  sprout: <Sprout className="w-6 h-6" />,
  clock: <Clock className="w-6 h-6" />,
  award: <Award className="w-6 h-6" />,
}

const RARITY_COLORS: Record<string, { bg: string; border: string; text: string; glow: string }> = {
  common:    { bg: 'bg-gray-50',   border: 'border-gray-200',  text: 'text-gray-600',   glow: '' },
  uncommon:  { bg: 'bg-primary-50', border: 'border-primary-200', text: 'text-primary-700', glow: '' },
  rare:      { bg: 'bg-blue-50',   border: 'border-blue-200',  text: 'text-blue-600',   glow: 'shadow-blue-100' },
  epic:      { bg: 'bg-purple-50', border: 'border-purple-200',text: 'text-purple-600', glow: 'shadow-purple-100' },
  legendary: { bg: 'bg-amber-50',  border: 'border-amber-300', text: 'text-amber-600',  glow: 'shadow-amber-200 shadow-lg' },
}

const RARITY_LABELS: Record<string, string> = {
  common: '⚪ Gewöhnlich', uncommon: '🟢 Ungewöhnlich', rare: '🔵 Selten',
  epic: '🟣 Episch', legendary: '🟡 Legendär',
}

const CATEGORY_LABELS: Record<string, string> = {
  social: '🤝 Soziales', helper: '🦸 Helfer', engagement: '🔥 Engagement',
  knowledge: '📚 Wissen', special: '⭐ Spezial',
}

// ── Default Badge Library (used when DB is empty) ───────────────
const DEFAULT_BADGES: Badge[] = [
  { id: 'b1', name: 'Willkommen!', description: 'Registrierung abgeschlossen', icon: 'star', category: 'engagement', requirement_type: 'register', requirement_value: 1, points: 10, rarity: 'common' },
  { id: 'b2', name: 'Erster Beitrag', description: 'Deinen ersten Beitrag erstellt', icon: 'zap', category: 'engagement', requirement_type: 'posts_created', requirement_value: 1, points: 20, rarity: 'common' },
  { id: 'b3', name: 'Aktiv dabei', description: '10 Beiträge erstellt', icon: 'flame', category: 'engagement', requirement_type: 'posts_created', requirement_value: 10, points: 50, rarity: 'uncommon' },
  { id: 'b4', name: 'Vielschreiber', description: '50 Beiträge erstellt', icon: 'book', category: 'engagement', requirement_type: 'posts_created', requirement_value: 50, points: 100, rarity: 'rare' },
  { id: 'b5', name: 'Ersthelfer', description: 'Erste Hilfe angeboten', icon: 'heart', category: 'helper', requirement_type: 'help_offered', requirement_value: 1, points: 25, rarity: 'common' },
  { id: 'b6', name: 'Held der Nachbarschaft', description: '25 Hilfsangebote', icon: 'shield', category: 'helper', requirement_type: 'help_offered', requirement_value: 25, points: 150, rarity: 'epic' },
  { id: 'b7', name: 'Vertrauenswürdig', description: 'Trust-Score über 4.0', icon: 'trophy', category: 'social', requirement_type: 'trust_score', requirement_value: 4, points: 100, rarity: 'rare' },
  { id: 'b8', name: 'Netzwerker', description: 'In 5 Gruppen beigetreten', icon: 'users', category: 'social', requirement_type: 'groups_joined', requirement_value: 5, points: 50, rarity: 'uncommon' },
  { id: 'b9', name: 'Wissensträger', description: '5 Wiki-Artikel geschrieben', icon: 'book', category: 'knowledge', requirement_type: 'articles_written', requirement_value: 5, points: 75, rarity: 'rare' },
  { id: 'b10', name: 'Challenge-Meister', description: '10 Challenges abgeschlossen', icon: 'target', category: 'special', requirement_type: 'challenges_completed', requirement_value: 10, points: 200, rarity: 'epic' },
  { id: 'b11', name: 'Gemeinschaftslegende', description: '100 Hilfsangebote + Trust 4.5+', icon: 'crown', category: 'special', requirement_type: 'legendary_helper', requirement_value: 100, points: 500, rarity: 'legendary' },
  { id: 'b12', name: 'Eventplaner', description: '5 Veranstaltungen erstellt', icon: 'calendar', category: 'social', requirement_type: 'events_created', requirement_value: 5, points: 75, rarity: 'uncommon' },
]

// ── Anforderungs-Text ───────────────────────────────────────────
function requirementHint(type: string, value: number): string {
  const map: Record<string, string> = {
    register:            'Registrierung abschließen',
    posts_created:       `${value} Beitrag${value !== 1 ? 'e' : ''} erstellen`,
    help_offered:        `${value} Hilfsangebot${value !== 1 ? 'e' : ''} erstellen`,
    trust_score:         `Trust-Score über ${value}.0 erreichen`,
    groups_joined:       `${value} Gruppen beitreten`,
    articles_written:    `${value} Wiki-Artikel schreiben`,
    challenges_completed:`${value} Challenges abschließen`,
    events_created:      `${value} Veranstaltungen erstellen`,
    legendary_helper:    `${value} Hilfsangebote + Trust-Score ≥ 4.5`,
  }
  return map[type] ?? `Ziel: ${value}`
}

// ── Badge Card ──────────────────────────────────────────────────
function BadgeCard({ badge, earned, earnedAt }: { badge: Badge; earned: boolean; earnedAt?: string }) {
  const rarity = RARITY_COLORS[badge.rarity] ?? RARITY_COLORS.common

  const accentMap: Record<string, string> = {
    common: '#94A3B8', uncommon: '#1EAAA6', rare: '#3B82F6',
    epic: '#8B5CF6', legendary: '#F59E0B',
  }
  const accent = accentMap[badge.rarity] ?? '#94A3B8'

  return (
    <div className={cn(
      'relative rounded-2xl border p-4 pt-5 shadow-soft hover:shadow-card transition-all overflow-hidden',
      earned ? `${rarity.bg} ${rarity.border} ${rarity.glow}` : 'bg-gray-50 border-gray-200 opacity-70',
    )}>
      {earned && (
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: `linear-gradient(90deg, ${accent}, ${accent}33)` }}
        />
      )}
      {!earned && (
        <div className="absolute top-2 right-2">
          <Lock className="w-4 h-4 text-gray-400" />
        </div>
      )}
      <div className={cn('relative w-12 h-12 rounded-xl flex items-center justify-center mb-3 transition-transform',
        earned ? `${rarity.bg} ${rarity.text} float-idle` : 'bg-gray-100 text-gray-400')}>
        {BADGE_ICONS[badge.icon] ?? <Award className="w-6 h-6" />}
      </div>
      <h3 className={cn('font-bold text-sm', earned ? 'text-gray-900' : 'text-gray-500')}>{badge.name}</h3>
      <p className="text-xs text-gray-500 mt-0.5">{badge.description}</p>

      {/* Anforderung für gesperrte Badges */}
      {!earned && (
        <div className="mt-2 flex items-start gap-1.5 bg-white/60 rounded-lg px-2 py-1.5 border border-gray-200">
          <Target className="w-3 h-3 text-gray-400 flex-shrink-0 mt-0.5" />
          <p className="text-[10px] text-gray-500 leading-snug">
            {requirementHint(badge.requirement_type, badge.requirement_value)}
          </p>
        </div>
      )}

      <div className="flex items-center justify-between mt-2">
        <span className={cn('text-[10px] px-1.5 py-0.5 rounded-full', rarity.bg, rarity.text, rarity.border, 'border')}>
          {RARITY_LABELS[badge.rarity]?.replace(/^.+\s/, '') ?? badge.rarity}
        </span>
        <span className="text-[10px] text-gray-400 flex items-center gap-0.5">
          <Star className="w-2.5 h-2.5 text-amber-400" /> {badge.points}
        </span>
      </div>
      {earned && earnedAt && (
        <p className="text-[10px] text-gray-400 mt-1">
          ✅ Erhalten am {new Date(earnedAt).toLocaleDateString('de-DE')}
        </p>
      )}
    </div>
  )
}

// ── Main Badges Page ────────────────────────────────────────────
export default function BadgesPage() {
  const [badges, setBadges] = useState<Badge[]>(DEFAULT_BADGES)
  const [userBadges, setUserBadges] = useState<Map<string, UserBadge>>(new Map())
  const [loading, setLoading] = useState(true)
  const [filterCat, setFilterCat] = useState('all')

  useEffect(() => {
    let cancelled = false
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()

      // Try to load from DB, fall back to defaults
      const { data: dbBadges, error: badgesErr } = await supabase
        .from('badges').select('*').order('points', { ascending: true })
      if (cancelled) return
      if (badgesErr) console.error('load badges failed:', badgesErr.message)
      if (dbBadges && dbBadges.length > 0) {
        setBadges(dbBadges as Badge[])
      }

      if (user) {
        // Bestehende Badges laden
        const { data: ub, error: ubErr } = await supabase
          .from('user_badges').select('badge_id, earned_at').eq('user_id', user.id)
        if (cancelled) return
        if (ubErr) console.error('load user_badges failed:', ubErr.message)
        const map = new Map<string, UserBadge>()
        for (const b of (ub ?? []) as UserBadge[]) map.set(b.badge_id, b)

        // ── Auto-Award: Anforderungen prüfen und fehlende Badges vergeben ──
        const allBadges = (dbBadges && dbBadges.length > 0) ? dbBadges as Badge[] : DEFAULT_BADGES
        try {
          const [postsRes, groupsRes, profileRes, eventsRes, wikiRes, challengesRes] = await Promise.all([
            supabase.from('posts').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
            supabase.from('group_members').select('id', { count: 'exact', head: true }).eq('user_id', user.id),
            supabase.from('profiles').select('trust_score').eq('id', user.id).maybeSingle(),
            supabase.from('events').select('id', { count: 'exact', head: true }).eq('author_id', user.id),
            supabase.from('knowledge_articles').select('id', { count: 'exact', head: true }).eq('author_id', user.id),
            supabase.from('challenge_progress').select('id', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'completed'),
          ])

          const stats: Record<string, number> = {
            register: 1, // User ist registriert
            posts_created: postsRes.count ?? 0,
            help_offered: postsRes.count ?? 0, // vereinfacht: posts = help offered
            groups_joined: groupsRes.count ?? 0,
            trust_score: profileRes.data?.trust_score ?? 0,
            events_created: eventsRes.count ?? 0,
            articles_written: wikiRes.count ?? 0,
            challenges_completed: challengesRes.count ?? 0,
            legendary_helper: postsRes.count ?? 0,
          }

          const newlyEarned: string[] = []
          for (const badge of allBadges) {
            if (map.has(badge.id)) continue // schon verdient
            const current = stats[badge.requirement_type] ?? 0
            if (current >= badge.requirement_value) {
              newlyEarned.push(badge.id)
            }
          }

          // Neue Badges in DB speichern
          if (newlyEarned.length > 0) {
            const inserts = newlyEarned.map(bid => ({ user_id: user.id, badge_id: bid }))
            await supabase.from('user_badges').insert(inserts).select()
            for (const bid of newlyEarned) {
              map.set(bid, { badge_id: bid, earned_at: new Date().toISOString() })
            }
          }
        } catch (e) {
          console.warn('Auto-award check failed:', e)
        }

        setUserBadges(map)
      }
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  const earnedCount = userBadges.size
  const totalPoints = Array.from(userBadges.keys()).reduce((sum, bid) => {
    const badge = badges.find(b => b.id === bid)
    return sum + (badge?.points ?? 0)
  }, 0)

  const filtered = filterCat === 'all' ? badges : badges.filter(b => b.category === filterCat)
  const categories = [...new Set(badges.map(b => b.category))]

  // "Fast geschafft": unearned badges sorted by lowest requirement (most achievable)
  const almostThere = badges
    .filter(b => !userBadges.has(b.id))
    .sort((a, b) => a.requirement_value - b.requirement_value)
    .slice(0, 4)

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-6">
      {/* Editorial header */}
      <header className="mb-8">
        <div className="meta-label meta-label--subtle mb-4">§ 29 / Badges</div>
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-purple-50 border border-purple-100 flex items-center justify-center flex-shrink-0 float-idle">
              <Award className="w-6 h-6 text-purple-700" />
            </div>
            <div>
              <h1 className="page-title">Badges & Erfolge</h1>
              <p className="page-subtitle mt-2">Sammle Auszeichnungen für dein <span className="text-accent">Engagement</span>.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0 text-xs tracking-wide text-ink-500">
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{earnedCount}</span>/<span className="font-serif italic text-ink-800 tabular-nums">{badges.length}</span> Badges
            </span>
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-stone-100 border border-stone-200">
              <span className="font-serif italic text-ink-800 tabular-nums">{totalPoints}</span> Punkte
            </span>
          </div>
        </div>

        {/* Progress */}
        <div className="mt-6">
          <div className="h-1.5 bg-stone-200 rounded-full overflow-hidden">
            <div className="h-full bg-ink-800 rounded-full transition-all"
              style={{ width: `${badges.length > 0 ? (earnedCount / badges.length * 100) : 0}%` }} />
          </div>
          <p className="text-xs text-ink-400 mt-2 tracking-wide">
            <span className="font-serif italic text-ink-800 tabular-nums">{badges.length > 0 ? Math.round(earnedCount / badges.length * 100) : 0}%</span> freigeschaltet
          </p>
        </div>
        <div className="mt-6 h-px bg-gradient-to-r from-stone-300 via-stone-200 to-transparent" />
      </header>

      <div>
        {/* Fast geschafft */}
        {almostThere.length > 0 && (
          <div className="mb-8">
            <h2 className="text-sm font-semibold text-ink-700 mb-3 flex items-center gap-2">
              <Zap className="w-4 h-4 text-amber-500" />
              Nächste Ziele
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {almostThere.map(b => (
                <div key={b.id} className="flex items-center gap-3 bg-amber-50 border border-amber-100 rounded-2xl px-4 py-3">
                  <div className="w-10 h-10 rounded-xl bg-amber-100 flex items-center justify-center flex-shrink-0 text-amber-700">
                    {BADGE_ICONS[b.icon] ?? <Award className="w-5 h-5" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-ink-800 truncate">{b.name}</p>
                    <p className="text-xs text-ink-500 mt-0.5">{requirementHint(b.requirement_type, b.requirement_value)}</p>
                  </div>
                  <span className="text-xs font-medium text-amber-700 bg-amber-100 px-2 py-1 rounded-full flex-shrink-0">
                    +{b.points} Pkt.
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Category Filter */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 mb-6">
          <div className="flex flex-wrap gap-2">
            <button onClick={() => setFilterCat('all')}
              className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all border',
                filterCat === 'all' ? 'bg-purple-100 border-purple-300 text-purple-700' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50')}>
              Alle ({badges.length})
            </button>
            {categories.map(cat => (
              <button key={cat} onClick={() => setFilterCat(filterCat === cat ? 'all' : cat)}
                className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all border',
                  filterCat === cat ? 'bg-purple-100 border-purple-300 text-purple-700' : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50')}>
                {CATEGORY_LABELS[cat] ?? cat} ({badges.filter(b => b.category === cat).length})
              </button>
            ))}
          </div>
        </div>

        {/* Badge Grid */}
        {loading ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[1, 2, 3, 4, 5, 6].map(i => <div key={i} className="h-40 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : (
          <>
            {/* Earned first, then locked — copy before sort so we don't mutate badges state */}
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
              {[...filtered]
                .sort((a, b) => {
                  const aE = userBadges.has(a.id) ? 0 : 1
                  const bE = userBadges.has(b.id) ? 0 : 1
                  return aE - bE
                })
                .map(b => (
                  <BadgeCard key={b.id} badge={b} earned={userBadges.has(b.id)}
                    earnedAt={userBadges.get(b.id)?.earned_at} />
                ))}
            </div>
          </>
        )}
      </div>
    </div>
  )
}
