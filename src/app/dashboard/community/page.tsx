'use client'

import { useState, useEffect } from 'react'
import { Users, TrendingUp, MessageSquare, Lightbulb, Info } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'
import CityInfoCard from '@/components/knowledge/CityInfoCard'
import HistoricalGallery from '@/components/knowledge/HistoricalGallery'

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

  const cards = [
    { icon: MessageSquare, label: 'Aktive Themen',    value: stats.posts,       accent: '#8B5CF6', tip: 'Anzahl aktiver Community-Beiträge' },
    { icon: TrendingUp,    label: 'Ideen & Vorschl.', value: stats.ideas,       accent: '#3B82F6', tip: 'Posts in der Kategorie "Idee/Wissen"' },
    { icon: Lightbulb,     label: 'Gemeldete Probl.', value: stats.problems,    accent: '#F97316', tip: 'Gemeldete Probleme in der Community' },
    { icon: Users,         label: 'Aktive Mitglieder',value: stats.activeUsers, accent: '#1EAAA6', tip: 'Mitglieder mit aktiven Beiträgen' },
  ]

  return (
    <div className="space-y-4">
      {/* Puls-Kacheln */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map(s => {
          const Icon = s.icon
          return (
            <div
              key={s.label}
              className="relative flex flex-col items-center p-3 rounded-2xl bg-white border border-gray-100 shadow-soft hover:shadow-card transition-shadow overflow-hidden"
            >
              <div
                className="absolute top-0 left-0 right-0 h-px opacity-60"
                style={{ background: `linear-gradient(90deg, ${s.accent}66, transparent)` }}
              />
              <div
                className="w-8 h-8 rounded-lg flex items-center justify-center mb-1.5"
                style={{ background: `${s.accent}18` }}
              >
                <Icon className="w-4 h-4" style={{ color: s.accent }} />
              </div>
              <p className="display-numeral text-xl font-bold text-gray-900 tabular-nums">{s.value}</p>
              <div className="flex items-center justify-center gap-0.5">
                <p className="text-xs text-gray-500 text-center leading-tight">{s.label}</p>
                <StatTooltip text={s.tip} />
              </div>
            </div>
          )
        })}
      </div>

      {/* Neueste Community-Themen */}
      {topPosts.length > 0 && (
        <div className="relative bg-gradient-to-br from-violet-50 to-violet-50/60 border border-violet-200 rounded-2xl p-4 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #8B5CF6, #8B5CF633)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <p className="relative text-sm font-bold text-violet-800 mb-2">🔥 Neue Community-Themen</p>
          <div className="relative space-y-2">
            {topPosts.map(p => (
              <Link key={p.id} href={`/dashboard/posts/${p.id}`}
                className="flex items-center gap-2 p-2.5 bg-white rounded-xl hover:bg-violet-50 hover:border-violet-200 transition-all border border-violet-100 group shadow-soft">
                <span className="text-sm flex-shrink-0 group-hover:scale-110 transition-transform">{typeEmoji[p.type] ?? '💬'}</span>
                <p className="text-xs font-medium text-gray-800 truncate group-hover:text-violet-700 flex-1">{p.title}</p>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Community-Tipp */}
      <div className="relative bg-white border border-violet-200 rounded-2xl p-4 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #8B5CF6, #8B5CF633)' }}
        />
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
      examplePosts={[
        { emoji: '🗳️', title: 'Solarenergie-Initiative – macht ihr mit?', description: 'Ich möchte eine Sammelbestellung für Balkon-Solar-Module organisieren. Wer hätte Interesse? Gemeinsam sparen wir Kosten.', type: 'community', category: 'knowledge' },
        { emoji: '📢', title: 'Straßenfest am Samstag – Helfer gesucht', description: 'Wir planen ein kleines Straßenfest mit Grill und Musik. Wer hilft beim Aufbau oder bringt Kuchen mit?', type: 'community', category: 'everyday' },
        { emoji: '💡', title: 'Gemeinschaftsgarten auf der Brachfläche?', description: 'Die Brache an der Ecke könnte ein schöner Nachbarschaftsgarten werden. Hat jemand Lust, sich zu engagieren?', type: 'community', category: 'knowledge' },
      ]}
    >
      <div className="mb-4">
        <CityInfoCard compact />
      </div>
      <div className="mb-4">
        <HistoricalGallery
          title="Entdecke die Geschichte deiner Nachbarschaft"
          limit={8}
        />
      </div>
      <CommunityPulseWidget />
    </ModulePage>
  )
}
