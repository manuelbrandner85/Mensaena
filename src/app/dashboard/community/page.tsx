'use client'

import { useState, useEffect } from 'react'
import { Users, TrendingUp, MessageSquare, Lightbulb, Info } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import { CommunityVoting } from '@/components/features/community'
import Link from 'next/link'

// ── Community Trending Widget ────────────────────────────────────
function StatTooltip({ text }: { text: string }) {
  const [show, setShow] = useState(false)
  return (
    <div className="relative inline-block ml-1">
      <button
        onMouseEnter={() => setShow(true)}
        onMouseLeave={() => setShow(false)}
        onTouchStart={() => setShow(v => !v)}
        className="text-gray-400 hover:text-gray-600 transition-colors"
        aria-label="Info"
      >
        <Info className="w-3 h-3" />
      </button>
      {show && (
        <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 w-44 bg-gray-900 text-white text-[11px] rounded-lg px-2.5 py-1.5 shadow-lg z-20 leading-snug pointer-events-none">
          {text}
          <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900" />
        </div>
      )}
    </div>
  )
}

function CommunityPulseWidget() {
  const [stats, setStats] = useState({ posts: 0, activeUsers: 0, ideas: 0, problems: 0 })
  const [topPosts, setTopPosts] = useState<{ id: string; title: string; vote_count?: number; type: string }[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Nur Community-relevante Posts laden
      const [postsRes, topRes] = await Promise.all([
        supabase.from('posts').select('type, category, user_id')
          .eq('type', 'community')
          .in('category', ['general', 'everyday', 'knowledge', 'emergency'])
          .eq('status', 'active'),
        supabase.from('posts').select('id,title,type')
          .eq('type', 'community')
          .in('category', ['general', 'everyday', 'knowledge', 'emergency'])
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(4),
      ])

      if (cancelled) return
      if (postsRes.error) console.error('community pulse stats failed:', postsRes.error.message)
      if (topRes.error) console.error('community pulse top failed:', topRes.error.message)

      const all = (postsRes.data ?? []) as { type: string; category: string; user_id: string }[]
      const uniqueUsers = new Set(all.map(p => p.user_id)).size
      setStats({
        posts:       all.length,
        activeUsers: uniqueUsers,
        ideas:       all.filter(p => p.category === 'knowledge').length,
        problems:    all.filter(p => p.category === 'emergency').length,
      })
      setTopPosts(topRes.data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="h-28 bg-violet-50 rounded-2xl animate-pulse border border-violet-200" />
  }

  const typeEmoji: Record<string, string> = {
    community: '🗳️', help_request: '🔴', help_offered: '🟢'
  }

  return (
    <div className="space-y-4">
      {/* Puls-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { icon: MessageSquare, label: 'Aktive Themen',   value: stats.posts,       color: 'bg-violet-50 border-violet-200 text-violet-700',  iconColor: 'text-violet-500', tip: 'Anzahl aktiver Community-Beiträge' },
          { icon: TrendingUp,    label: 'Ideen & Vorschl.',value: stats.ideas,       color: 'bg-blue-50 border-blue-200 text-blue-700',         iconColor: 'text-blue-500',   tip: 'Posts in der Kategorie "Idee/Wissen"' },
          { icon: Lightbulb,     label: 'Gemeldete Probl.',value: stats.problems,    color: 'bg-orange-50 border-orange-200 text-orange-700',   iconColor: 'text-orange-500', tip: 'Gemeldete Probleme in der Community' },
          { icon: Users,         label: 'Aktive Mitglieder',value: stats.activeUsers, color: 'bg-green-50 border-green-200 text-green-700',     iconColor: 'text-green-500',  tip: 'Mitglieder mit aktiven Beiträgen' },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-3 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-5 h-5 mb-1 ${s.iconColor}`} />
            <p className="text-xl font-bold">{s.value}</p>
            <div className="flex items-center justify-center gap-0.5">
              <p className="text-xs text-center opacity-80 leading-tight">{s.label}</p>
              <StatTooltip text={s.tip} />
            </div>
          </div>
        ))}
      </div>

      {/* Neueste Community-Themen */}
      {topPosts.length > 0 && (
        <div className="bg-violet-50 border border-violet-200 rounded-2xl p-4">
          <p className="text-sm font-bold text-violet-800 mb-2">🔥 Neue Community-Themen</p>
          <div className="space-y-2">
            {topPosts.map(p => (
              <Link key={p.id} href={`/dashboard/posts/${p.id}`}
                className="flex items-center gap-2 p-2.5 bg-white rounded-xl hover:bg-violet-50 transition-all border border-violet-100 group">
                <span className="text-sm flex-shrink-0">{typeEmoji[p.type] ?? '💬'}</span>
                <p className="text-xs font-medium text-gray-800 truncate group-hover:text-violet-700 flex-1">{p.title}</p>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Community-Tipp */}
      <div className="bg-white border border-violet-200 rounded-2xl p-4">
        <p className="text-xs font-bold text-violet-800 mb-1">💡 So funktioniert Community-Abstimmung</p>
        <p className="text-xs text-gray-600">
          Erstelle ein Community-Thema – andere Nutzer können <strong>👍 / 👎</strong> abstimmen.
          Ideen mit den meisten Stimmen werden sichtbarer und können zur Aktion werden!
        </p>
      </div>
    </div>
  )
}

export default function CommunityPage() {
  return (
    <ModulePage
      sectionLabel="§ 20 / Community"
      mood="warm"
      iconBgClass="bg-violet-50 border-violet-100"
      iconColorClass="text-violet-700"
      title="Community & Abstimmung"
      description="Lokale Abstimmungen, Probleme melden, gemeinsam Lösungen finden"
      icon={<Users className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-violet-500 to-purple-700"
      postTypes={['community']}
      moduleFilter={[
        { type: 'community', categories: ['general', 'everyday', 'knowledge', 'emergency'] },
      ]}
      createTypes={[
        { value: 'community', label: '🗳️ Abstimmung starten'  },
      ]}
      categories={[
        { value: 'general',   label: '🏘️ Lokal'              },
        { value: 'everyday',  label: '📢 Ankündigung'         },
        { value: 'knowledge', label: '💡 Idee / Vorschlag'    },
        { value: 'emergency', label: '🚨 Problem melden'      },
      ]}
      emptyText="Noch keine Community-Beiträge"
    >
      <CommunityPulseWidget />
      <div className="mt-4"><CommunityVoting /></div>
    </ModulePage>
  )
}
