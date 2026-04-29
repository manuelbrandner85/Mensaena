'use client'

import { useState, useEffect } from 'react'
import Image from 'next/image'
import {
  Award, Star, Trophy, Target, Heart, Shield, Zap, Crown,
  Users, MessageCircle, Calendar, Flame, BookOpen, Sprout,
  Clock, Lock,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import { getUserLevel, getNextLevel, getLevelProgress, getPointsToNextLevel, LEVELS } from '@/lib/levels'

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
  common:    { bg: 'bg-stone-50',   border: 'border-stone-200',  text: 'text-ink-600',   glow: '' },
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

// ── Orden / Medaillen Badge Card ────────────────────────────────
function BadgeCard({ badge, earned, earnedAt }: { badge: Badge; earned: boolean; earnedAt?: string }) {
  const accentMap: Record<string, { from: string; to: string; ribbon: string; shine: string; ring: string }> = {
    common:    { from: '#CBD5E1', to: '#94A3B8', ribbon: '#64748B', shine: '#E2E8F0', ring: 'ring-stone-300' },
    uncommon:  { from: '#5EEAD4', to: '#1EAAA6', ribbon: '#147170', shine: '#CCFBF1', ring: 'ring-primary-300' },
    rare:      { from: '#93C5FD', to: '#3B82F6', ribbon: '#1D4ED8', shine: '#DBEAFE', ring: 'ring-blue-300' },
    epic:      { from: '#C4B5FD', to: '#8B5CF6', ribbon: '#6D28D9', shine: '#EDE9FE', ring: 'ring-purple-300' },
    legendary: { from: '#FDE68A', to: '#F59E0B', ribbon: '#B45309', shine: '#FEF3C7', ring: 'ring-amber-400' },
  }
  const colors = accentMap[badge.rarity] ?? accentMap.common

  return (
    <div className={cn(
      'relative flex flex-col items-center text-center p-5 rounded-2xl transition-all group',
      earned
        ? 'bg-white border border-stone-100 shadow-md hover:shadow-xl hover:-translate-y-1'
        : 'bg-stone-50/80 border border-dashed border-stone-200 opacity-60',
    )}>
      {/* Orden-Medaille */}
      <div className="relative mb-4">
        {/* Band / Ribbon */}
        {earned && (
          <div className="absolute -top-2 left-1/2 -translate-x-1/2 w-8 overflow-hidden">
            <div className="flex justify-center gap-[2px]">
              <div className="w-3 h-6 rounded-b-sm" style={{ background: colors.ribbon }} />
              <div className="w-3 h-6 rounded-b-sm" style={{ background: colors.from }} />
            </div>
          </div>
        )}

        {/* Medaillen-Kreis */}
        <div className={cn(
          'relative w-16 h-16 rounded-full flex items-center justify-center mt-3',
          earned ? `ring-4 ${colors.ring} shadow-lg` : 'ring-2 ring-stone-200',
        )} style={earned ? {
          background: `linear-gradient(135deg, ${colors.from} 0%, ${colors.to} 100%)`,
        } : { background: '#F1F5F9' }}>
          {/* Shine-Effekt */}
          {earned && (
            <div className="absolute inset-0 rounded-full overflow-hidden">
              <div className="absolute -top-2 -left-2 w-8 h-8 rounded-full opacity-40" style={{ background: colors.shine }} />
            </div>
          )}
          <div className={cn('relative z-10', earned ? 'text-white drop-shadow-sm' : 'text-ink-400')}>
            {BADGE_ICONS[badge.icon] ?? <Award className="w-6 h-6" />}
          </div>
        </div>

        {/* Stern-Dekoration für rare+ */}
        {earned && (badge.rarity === 'rare' || badge.rarity === 'epic' || badge.rarity === 'legendary') && (
          <div className="absolute -bottom-1 left-1/2 -translate-x-1/2">
            <Star className="w-4 h-4 drop-shadow-sm" style={{ color: colors.to, fill: colors.to }} />
          </div>
        )}

        {/* Schloss für gesperrte */}
        {!earned && (
          <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-6 h-6 rounded-full bg-stone-200 flex items-center justify-center">
            <Lock className="w-3 h-3 text-ink-400" />
          </div>
        )}
      </div>

      {/* Name */}
      <h3 className={cn('font-bold text-sm leading-tight', earned ? 'text-ink-900' : 'text-ink-400')}>
        {badge.name}
      </h3>

      {/* Beschreibung */}
      <p className={cn('text-xs mt-1 leading-relaxed', earned ? 'text-ink-500' : 'text-ink-400')}>
        {badge.description}
      </p>

      {/* Anforderung (gesperrt) */}
      {!earned && (
        <div className="mt-3 px-3 py-1.5 bg-stone-100 rounded-lg">
          <p className="text-xs text-ink-400 flex items-center gap-1">
            <Target className="w-3 h-3" />
            {requirementHint(badge.requirement_type, badge.requirement_value)}
          </p>
        </div>
      )}

      {/* Rarity + Punkte */}
      <div className="flex items-center gap-2 mt-3">
        <span className="text-xs px-2 py-0.5 rounded-full font-medium" style={earned ? {
          background: `${colors.from}33`,
          color: colors.ribbon,
        } : { background: '#F1F5F9', color: '#94A3B8' }}>
          {RARITY_LABELS[badge.rarity] ?? badge.rarity}
        </span>
        <span className="text-xs text-ink-400 flex items-center gap-0.5">
          <Star className="w-2.5 h-2.5 text-amber-400" /> {badge.points}
        </span>
      </div>

      {/* Erhalten-Datum */}
      {earned && earnedAt && (
        <p className="text-xs text-primary-600 mt-2 font-medium">
          Erhalten am {new Date(earnedAt).toLocaleDateString('de-DE')}
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
  const [leaderboard, setLeaderboard] = useState<Array<{ name: string; avatar_url: string | null; points: number }>>([])
  const [showLeaderboard, setShowLeaderboard] = useState(false)

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

      // Rangliste laden: Top 10 User nach Badge-Punkten
      try {
        const { data: allUserBadges } = await supabase
          .from('user_badges')
          .select('user_id, badge_id')
        if (allUserBadges && allUserBadges.length > 0) {
          const allBadges = (dbBadges && dbBadges.length > 0) ? dbBadges as Badge[] : DEFAULT_BADGES
          const pointsByUser: Record<string, number> = {}
          for (const ub of allUserBadges) {
            const badge = allBadges.find(b => b.id === ub.badge_id)
            pointsByUser[ub.user_id] = (pointsByUser[ub.user_id] ?? 0) + (badge?.points ?? 0)
          }
          const topUserIds = Object.entries(pointsByUser).sort(([,a],[,b]) => b - a).slice(0, 10)
          if (topUserIds.length > 0) {
            const { data: profiles } = await supabase
              .from('profiles')
              .select('id, name, display_name, avatar_url')
              .in('id', topUserIds.map(([id]) => id))
            const lb = topUserIds.map(([uid, pts]) => {
              const p = (profiles ?? []).find((pr: any) => pr.id === uid) as any
              return { name: p?.display_name || p?.name || 'Nutzer', avatar_url: p?.avatar_url, points: pts }
            })
            setLeaderboard(lb)
          }
        }
      } catch { /* Rangliste optional */ }

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

        {/* Level-System */}
        {(() => {
          const level = getUserLevel(totalPoints)
          const next = getNextLevel(totalPoints)
          const progress = getLevelProgress(totalPoints)
          const toNext = getPointsToNextLevel(totalPoints)
          return (
            <div className="mt-6 space-y-4">
              {/* Aktuelles Level */}
              <div className={cn('flex items-center gap-4 p-4 rounded-2xl border', level.bgColor, level.borderColor)}>
                <div className="text-3xl">{level.emoji}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className={cn('text-sm font-bold', level.color)}>Level {level.level}</span>
                    <span className={cn('text-xs font-medium px-2 py-0.5 rounded-full', level.bgColor, level.color, level.borderColor, 'border')}>
                      {level.name}
                    </span>
                  </div>
                  <p className="text-xs text-ink-500 mt-0.5">{totalPoints} Punkte gesammelt</p>
                </div>
                {next && (
                  <div className="text-right flex-shrink-0">
                    <p className="text-xs text-ink-400">Nächstes Level</p>
                    <p className="text-sm font-bold text-ink-700">{next.emoji} {next.name}</p>
                  </div>
                )}
              </div>

              {/* Fortschrittsbalken */}
              {next && (
                <div>
                  <div className="h-2.5 bg-stone-200 rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all duration-500"
                      style={{
                        width: `${progress}%`,
                        background: `linear-gradient(90deg, ${level.level >= 4 ? '#8B5CF6' : '#1EAAA6'}, ${level.level >= 4 ? '#F59E0B' : '#147170'})`,
                      }}
                    />
                  </div>
                  <p className="text-xs text-ink-500 mt-1.5">
                    Noch <span className="font-bold text-ink-700">{toNext} Punkte</span> bis Level {next.level} ({next.name})
                  </p>
                </div>
              )}
              {!next && (
                <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 text-center">
                  <p className="text-sm font-bold text-amber-700">👑 Maximales Level erreicht!</p>
                  <p className="text-xs text-amber-600 mt-0.5">Du bist eine Legende der Community.</p>
                </div>
              )}

              {/* Alle Levels */}
              <div className="flex items-center gap-1 overflow-x-auto py-1">
                {LEVELS.map(l => (
                  <div key={l.level} className={cn(
                    'flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium border whitespace-nowrap transition-all',
                    totalPoints >= l.minPoints
                      ? `${l.bgColor} ${l.color} ${l.borderColor}`
                      : 'bg-stone-50 text-ink-400 border-stone-200',
                  )}>
                    <span>{l.emoji}</span>
                    <span>{l.name}</span>
                  </div>
                ))}
              </div>
            </div>
          )
        })()}
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
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4 mb-6">
          <div className="flex flex-wrap gap-2">
            <button onClick={() => setFilterCat('all')}
              className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all border',
                filterCat === 'all' ? 'bg-purple-100 border-purple-300 text-purple-700' : 'bg-white border-stone-200 text-ink-600 hover:bg-stone-50')}>
              Alle ({badges.length})
            </button>
            {categories.map(cat => (
              <button key={cat} onClick={() => setFilterCat(filterCat === cat ? 'all' : cat)}
                className={cn('px-3 py-1.5 rounded-xl text-xs font-medium transition-all border',
                  filterCat === cat ? 'bg-purple-100 border-purple-300 text-purple-700' : 'bg-white border-stone-200 text-ink-600 hover:bg-stone-50')}>
                {CATEGORY_LABELS[cat] ?? cat} ({badges.filter(b => b.category === cat).length})
              </button>
            ))}
          </div>
        </div>

        {/* Badge Grid */}
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[1, 2, 3, 4, 5, 6].map(i => <div key={i} className="h-40 bg-white rounded-2xl animate-pulse border" />)}
          </div>
        ) : (
          <>
            {/* Earned first, then locked — copy before sort so we don't mutate badges state */}
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
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

        {/* Rangliste */}
        {leaderboard.length > 0 && (
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <button
              onClick={() => setShowLeaderboard(s => !s)}
              className="w-full flex items-center justify-between p-4 hover:bg-stone-50 transition-colors"
            >
              <div className="flex items-center gap-2">
                <Trophy className="w-5 h-5 text-amber-500" />
                <h3 className="text-sm font-bold text-ink-900">Community-Rangliste</h3>
              </div>
              <span className="text-xs text-ink-400">{showLeaderboard ? '▲' : '▼'}</span>
            </button>
            {showLeaderboard && (
              <div className="px-4 pb-4 space-y-2">
                {leaderboard.map((user, i) => {
                  const level = getUserLevel(user.points)
                  const medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : `${i + 1}.`
                  return (
                    <div key={i} className={cn(
                      'flex items-center gap-3 p-2.5 rounded-xl transition-all',
                      i < 3 ? 'bg-amber-50/50' : 'hover:bg-stone-50',
                    )}>
                      <span className="w-7 text-center text-sm font-bold">{medal}</span>
                      <div className="w-8 h-8 rounded-full bg-stone-200 flex items-center justify-center text-xs font-bold text-ink-500 overflow-hidden flex-shrink-0">
                        {user.avatar_url
                          ? <Image src={user.avatar_url} alt="" width={32} height={32} className="w-full h-full object-cover" />
                          : user.name.charAt(0).toUpperCase()
                        }
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-ink-900 truncate">{user.name}</p>
                        <p className="text-xs text-ink-400">{level.emoji} {level.name}</p>
                      </div>
                      <span className="text-sm font-bold text-ink-700 tabular-nums">{user.points}</span>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
