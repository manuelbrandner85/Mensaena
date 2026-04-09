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
  uncommon:  { bg: 'bg-green-50',  border: 'border-green-200', text: 'text-green-600',  glow: '' },
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

// ── Badge Card ──────────────────────────────────────────────────
function BadgeCard({ badge, earned, earnedAt }: { badge: Badge; earned: boolean; earnedAt?: string }) {
  const rarity = RARITY_COLORS[badge.rarity] ?? RARITY_COLORS.common

  return (
    <div className={cn(
      'relative rounded-2xl border p-4 transition-all',
      earned ? `${rarity.bg} ${rarity.border} ${rarity.glow}` : 'bg-gray-50 border-gray-200 opacity-60',
    )}>
      {!earned && (
        <div className="absolute top-2 right-2">
          <Lock className="w-4 h-4 text-gray-400" />
        </div>
      )}
      <div className={cn('w-12 h-12 rounded-xl flex items-center justify-center mb-3',
        earned ? `${rarity.bg} ${rarity.text}` : 'bg-gray-100 text-gray-400')}>
        {BADGE_ICONS[badge.icon] ?? <Award className="w-6 h-6" />}
      </div>
      <h3 className={cn('font-bold text-sm', earned ? 'text-gray-900' : 'text-gray-500')}>{badge.name}</h3>
      <p className="text-xs text-gray-500 mt-0.5">{badge.description}</p>
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
    async function load() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()

      // Try to load from DB, fall back to defaults
      const { data: dbBadges } = await supabase.from('badges').select('*').order('points', { ascending: true })
      if (dbBadges && dbBadges.length > 0) {
        setBadges(dbBadges)
      }

      if (user) {
        const { data: ub } = await supabase.from('user_badges').select('*').eq('user_id', user.id)
        const map = new Map<string, UserBadge>()
        ;(ub ?? []).forEach((b: any) => map.set(b.badge_id, b))
        setUserBadges(map)
      }
      setLoading(false)
    }
    load()
  }, [])

  const earnedCount = userBadges.size
  const totalPoints = Array.from(userBadges.keys()).reduce((sum, bid) => {
    const badge = badges.find(b => b.id === bid)
    return sum + (badge?.points ?? 0)
  }, 0)

  const filtered = filterCat === 'all' ? badges : badges.filter(b => b.category === filterCat)
  const categories = [...new Set(badges.map(b => b.category))]

  return (
    <div className="min-h-screen bg-gradient-to-b from-purple-50 via-white to-white">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 to-indigo-700 text-white px-4 sm:px-6 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2.5 bg-white/20 rounded-xl backdrop-blur-sm"><Award className="w-6 h-6" /></div>
            <h1 className="text-2xl font-bold">Badges & Erfolge</h1>
          </div>
          <p className="text-purple-100 text-sm">Sammle Badges für dein Engagement in der Community</p>
          <div className="flex gap-4 mt-4">
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              🏅 {earnedCount} / {badges.length} Badges
            </div>
            <div className="bg-white/15 backdrop-blur-sm rounded-xl px-3 py-1.5 text-sm">
              ⭐ {totalPoints} Punkte
            </div>
          </div>

          {/* Progress */}
          <div className="mt-4">
            <div className="h-2.5 bg-white/20 rounded-full overflow-hidden">
              <div className="h-full bg-white/80 rounded-full transition-all"
                style={{ width: `${badges.length > 0 ? (earnedCount / badges.length * 100) : 0}%` }} />
            </div>
            <p className="text-xs text-purple-200 mt-1">{badges.length > 0 ? Math.round(earnedCount / badges.length * 100) : 0}% aller Badges freigeschaltet</p>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 -mt-4">
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
            {/* Earned first, then locked */}
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 pb-8">
              {filtered
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
