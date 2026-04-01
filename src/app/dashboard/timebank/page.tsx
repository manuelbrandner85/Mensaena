'use client'

import { useState, useEffect } from 'react'
import { Clock, Plus, Users, Star, ArrowRight, HandCoins, BookOpen, Wrench, Heart, Leaf } from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'

// ── Zeitbank Widget ──────────────────────────────────────────
function TimebankWidget() {
  const [myHours, setMyHours]       = useState<number | null>(null)
  const [myBalance, setMyBalance]   = useState<number>(0)
  const [stats, setStats]           = useState({ total_givers: 0, total_hours: 0 })

  useEffect(() => {
    const load = async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()

      // Echte Stunden aus duration_hours-Feld
      const { data: allPosts } = await supabase
        .from('posts')
        .select('duration_hours, user_id')
        .in('type', ['help_offer', 'skill'])
        .eq('status', 'active')
        .not('duration_hours', 'is', null)

      const totalHours = (allPosts ?? []).reduce((sum, p) => sum + (p.duration_hours ?? 0), 0)
      const uniqueGivers = new Set((allPosts ?? []).map(p => p.user_id)).size

      setStats({ total_givers: uniqueGivers, total_hours: Math.round(totalHours) })

      if (user) {
        const { data: myPosts } = await supabase
          .from('posts')
          .select('duration_hours')
          .in('type', ['help_offer', 'skill'])
          .eq('user_id', user.id)
          .not('duration_hours', 'is', null)

        const mine = (myPosts ?? []).reduce((s, p) => s + (p.duration_hours ?? 0), 0)
        setMyHours(Math.round(mine * 10) / 10)

        // Balance: Stunden angeboten - Stunden in Anspruch genommen (geschätzt)
        const { count: usedCount } = await supabase.from('interactions')
          .select('*', { count: 'exact', head: true })
          .eq('helper_id', user.id).eq('status', 'accepted')
        setMyBalance(Math.round((mine - (usedCount ?? 0)) * 10) / 10)
      }
    }
    load()
  }, [])

  return (
    <div className="bg-gradient-to-br from-amber-50 to-yellow-50 border border-amber-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-4">
        <HandCoins className="w-5 h-5 text-amber-600" />
        <h3 className="font-bold text-amber-900">Dein Zeitkonto</h3>
      </div>
      
      <div className="grid grid-cols-3 gap-3 mb-4">
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <p className="text-2xl font-bold text-amber-600">{myHours ?? '–'}</p>
          <p className="text-xs text-gray-500 mt-0.5">Meine Stunden</p>
        </div>
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <p className={`text-2xl font-bold ${myBalance >= 0 ? 'text-green-600' : 'text-red-500'}`}>
            {myBalance >= 0 ? `+${myBalance}` : myBalance}
          </p>
          <p className="text-xs text-gray-500 mt-0.5">Zeitguthaben</p>
        </div>
        <div className="bg-white rounded-xl p-3 text-center border border-amber-100">
          <p className="text-2xl font-bold text-blue-600">{stats.total_hours}</p>
          <p className="text-xs text-gray-500 mt-0.5">Community-Std.</p>
        </div>
      </div>

      <div className="space-y-2">
        <p className="text-xs font-semibold text-amber-800 uppercase tracking-wide">Wie es funktioniert</p>
        {[
          { icon: '1', text: 'Biete eine Stunde deiner Zeit an (z.B. Gartenarbeit)' },
          { icon: '2', text: 'Helfe jemandem – und verdiene Zeitgutschriften' },
          { icon: '3', text: 'Tausche deine Gutschriften gegen Hilfe die du brauchst' },
        ].map((step, i) => (
          <div key={i} className="flex items-start gap-2 text-sm text-amber-900">
            <span className="w-5 h-5 rounded-full bg-amber-200 text-amber-800 flex items-center justify-center text-xs font-bold flex-shrink-0">{step.icon}</span>
            <span>{step.text}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

// ── Kategorien-Widget ────────────────────────────────────────
const TIME_CATEGORIES = [
  { icon: <Wrench className="w-5 h-5" />, label: 'Handwerk & Reparatur', category: 'skills', color: 'bg-orange-100 text-orange-700 border-orange-200 hover:bg-orange-200' },
  { icon: <Leaf className="w-5 h-5" />, label: 'Garten & Natur', category: 'general', color: 'bg-green-100 text-green-700 border-green-200 hover:bg-green-200' },
  { icon: <BookOpen className="w-5 h-5" />, label: 'Nachhilfe & Lernen', category: 'knowledge', color: 'bg-blue-100 text-blue-700 border-blue-200 hover:bg-blue-200' },
  { icon: <Heart className="w-5 h-5" />, label: 'Pflege & Fürsorge', category: 'mental', color: 'bg-pink-100 text-pink-700 border-pink-200 hover:bg-pink-200' },
  { icon: <Users className="w-5 h-5" />, label: 'Gemeinschaft', category: 'community', color: 'bg-violet-100 text-violet-700 border-violet-200 hover:bg-violet-200' },
  { icon: <Star className="w-5 h-5" />, label: 'Kreatives & Kunst', category: 'general', color: 'bg-yellow-100 text-yellow-700 border-yellow-200 hover:bg-yellow-200' },
]

function SkillCategoriesWidget({ activeCategory, onFilter }: {
  activeCategory: string
  onFilter: (cat: string) => void
}) {
  return (
    <div className="bg-white border border-warm-200 rounded-2xl p-5">
      <h3 className="font-bold text-gray-900 mb-1 flex items-center gap-2">
        <Clock className="w-5 h-5 text-primary-600" />
        Was kannst du anbieten?
      </h3>
      <p className="text-xs text-gray-400 mb-3">Klicke auf eine Kategorie, um die Liste zu filtern</p>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
        {TIME_CATEGORIES.map((cat, i) => (
          <button key={i}
            onClick={() => onFilter(activeCategory === cat.category ? '' : cat.category)}
            className={`flex items-center gap-2 p-3 rounded-xl border text-sm font-medium transition-all hover:scale-105 ${cat.color} ${
              activeCategory === cat.category ? 'ring-2 ring-offset-1 ring-primary-400' : ''
            }`}
          >
            {cat.icon}
            <span className="text-left leading-tight">{cat.label}</span>
          </button>
        ))}
      </div>
      {activeCategory && (
        <button onClick={() => onFilter('')} className="mt-2 text-xs text-primary-600 hover:underline w-full text-center">
          Filter zurücksetzen
        </button>
      )}
    </div>
  )
}

// ── Haupt-Export ─────────────────────────────────────────────
export default function TimebankPage() {
  const [activeCategory, setActiveCategory] = useState('')

  return (
    <ModulePage
      title="Zeitbank"
      description="Tausche Zeit statt Geld – biete Stunden an, verdiene Gutschriften, baue Gemeinschaft auf"
      icon={<Clock className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-amber-500 to-yellow-600"
      postTypes={['skill', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'help_offer',   label: '⏰ Stunde anbieten'  },
        { value: 'help_request', label: '🔴 Hilfe benötigt'   },
        { value: 'skill',        label: '⭐ Skill eintragen'   },
      ]}
      categories={[
        { value: 'skills',    label: '🔧 Handwerk'      },
        { value: 'general',   label: '🌿 Garten & Natur' },
        { value: 'knowledge', label: '📚 Nachhilfe'     },
        { value: 'mental',    label: '💙 Fürsorge'      },
        { value: 'community', label: '👥 Gemeinschaft'  },
      ]}
      emptyText="Noch keine Zeitbank-Einträge – sei der Erste!"
      filterCategory={activeCategory}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <TimebankWidget />
        <SkillCategoriesWidget activeCategory={activeCategory} onFilter={setActiveCategory} />
      </div>
    </ModulePage>
  )
}
