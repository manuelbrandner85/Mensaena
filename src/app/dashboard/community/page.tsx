'use client'

import { useState, useEffect } from 'react'
import { Users, TrendingUp, MessageSquare, Lightbulb } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Community Trending Widget ────────────────────────────────────
function CommunityPulseWidget() {
  const [stats, setStats] = useState({ posts: 0, votes_cast: 0, ideas: 0, problems: 0 })
  const [topPosts, setTopPosts] = useState<{ id: string; title: string; vote_count?: number; type: string }[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const [postsRes, topRes] = await Promise.all([
        supabase.from('posts').select('type, category')
          .in('type', ['community', 'help_request', 'help_offer']).eq('status', 'active'),
        supabase.from('posts').select('id,title,type')
          .eq('type', 'community').eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(4),
      ])

      const all = postsRes.data ?? []
      setStats({
        posts:    all.length,
        votes_cast: 0,  // would need post_votes table aggregate
        ideas:    all.filter(p => p.category === 'knowledge').length,
        problems: all.filter(p => p.category === 'emergency').length,
      })
      setTopPosts(topRes.data ?? [])
      setLoading(false)
    }
    load()
  }, [])

  if (loading) {
    return <div className="h-28 bg-violet-50 rounded-2xl animate-pulse border border-violet-200" />
  }

  const typeEmoji: Record<string, string> = {
    community: '🗳️', help_request: '🔴', help_offer: '🟢'
  }

  return (
    <div className="space-y-4">
      {/* Puls-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { icon: MessageSquare, label: 'Aktive Themen',   value: stats.posts,    color: 'bg-violet-50 border-violet-200 text-violet-700',  iconColor: 'text-violet-500' },
          { icon: TrendingUp,    label: 'Ideen & Vorschl.',value: stats.ideas,    color: 'bg-blue-50 border-blue-200 text-blue-700',         iconColor: 'text-blue-500'   },
          { icon: Lightbulb,     label: 'Gemeldete Probl.',value: stats.problems, color: 'bg-orange-50 border-orange-200 text-orange-700',   iconColor: 'text-orange-500' },
          { icon: Users,         label: 'Aktive Nutzer',   value: '–',            color: 'bg-green-50 border-green-200 text-green-700',      iconColor: 'text-green-500'  },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-3 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-5 h-5 mb-1 ${s.iconColor}`} />
            <p className="text-xl font-bold">{s.value}</p>
            <p className="text-xs text-center opacity-80">{s.label}</p>
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
      title="Community & Abstimmung"
      description="Lokale Abstimmungen, Probleme melden, gemeinsam Lösungen finden"
      icon={<Users className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-violet-500 to-purple-700"
      postTypes={['community', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'community',    label: '🗳️ Abstimmung'       },
        { value: 'help_request', label: '🔴 Problem melden'   },
        { value: 'help_offer',   label: '🟢 Lösung anbieten'  },
      ]}
      categories={[
        { value: 'community', label: '🏘️ Lokal'             },
        { value: 'general',   label: '📢 Ankündigung'       },
        { value: 'knowledge', label: '💡 Idee'              },
        { value: 'emergency', label: '🚨 Problem'           },
      ]}
      emptyText="Noch keine Community-Beiträge"
    >
      <CommunityPulseWidget />
    </ModulePage>
  )
}
