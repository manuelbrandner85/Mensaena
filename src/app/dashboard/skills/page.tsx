'use client'

import { useState, useEffect } from 'react'
import { Wrench, TrendingUp, Star, Plus } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Top Skills Widget ─────────────────────────────────────────
function TopSkillsWidget() {
  const [topSkills, setTopSkills]   = useState<{ title: string; id: string }[]>([])
  const [stats, setStats]           = useState({ offered: 0, seekers: 0, mentors: 0 })
  const [loading, setLoading]       = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Nur Skill-relevante Posts (Kategorie skills)
      const [allRes, skillsRes] = await Promise.all([
        supabase.from('posts').select('type')
          .in('type', ['sharing', 'rescue', 'community'])
          .eq('category', 'skills')
          .eq('status', 'active'),
        supabase.from('posts').select('id,title')
          .eq('type', 'sharing').eq('category', 'skills').eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(6),
      ])
      if (cancelled) return
      if (allRes.error)    console.error('skills stats query failed:', allRes.error.message)
      if (skillsRes.error) console.error('skills list query failed:',  skillsRes.error.message)
      const all = allRes.data ?? []
      setStats({
        offered:  all.filter(p => p.type === 'sharing' || p.type === 'community').length,
        seekers:  all.filter(p => p.type === 'rescue').length,
        mentors:  all.filter(p => p.type === 'sharing').length,
      })
      setTopSkills(skillsRes.data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="h-28 bg-purple-50 rounded-2xl animate-pulse border border-purple-200" />
  }

  const cards = [
    { icon: Star,       label: 'Skills angeboten', value: stats.offered, accent: '#8B5CF6' },
    { icon: TrendingUp, label: 'Skills gesucht',   value: stats.seekers, accent: '#3B82F6' },
    { icon: Wrench,     label: 'Mentoren aktiv',   value: stats.mentors, accent: '#1EAAA6' },
  ]

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        {cards.map(s => {
          const Icon = s.icon
          return (
            <div
              key={s.label}
              className="relative flex flex-col items-center p-3 rounded-2xl bg-white border border-stone-100 shadow-soft hover:shadow-card transition-shadow overflow-hidden"
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
              <p className="display-numeral text-xl font-bold text-ink-900 tabular-nums">{s.value}</p>
              <p className="text-xs text-ink-500 text-center leading-tight">{s.label}</p>
            </div>
          )
        })}
      </div>

      {/* Aktuell angebotene Skills */}
      {topSkills.length > 0 ? (
        <div className="relative bg-gradient-to-br from-purple-50 via-purple-50/80 to-violet-50 border border-purple-200 rounded-2xl p-4 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #8B5CF6, #8B5CF633)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <p className="relative text-sm font-bold text-purple-800 mb-2">⭐ Aktuell verfügbare Skills</p>
          <div className="relative flex flex-wrap gap-2">
            {topSkills.map(s => (
              <Link key={s.id} href={`/dashboard/posts/${s.id}`}
                className="px-3 py-1.5 bg-white border border-purple-200 rounded-full text-xs font-medium text-purple-700 hover:bg-purple-100 transition-all shadow-soft">
                {s.title}
              </Link>
            ))}
          </div>
        </div>
      ) : (
        <div className="relative text-center py-8 bg-gradient-to-br from-purple-50 to-violet-50 border border-purple-200 rounded-2xl space-y-2 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #8B5CF6, #8B5CF633)' }}
          />
          <p className="text-sm font-medium text-purple-800">Noch keine Skills geteilt</p>
          <p className="text-xs text-purple-600">Sei der Erste – teile eine Fähigkeit mit deiner Community!</p>
          <Link
            href="/dashboard/create?module=skills&type=sharing&category=skills"
            className="shine inline-flex items-center gap-1.5 px-4 py-2 bg-gradient-to-r from-purple-500 to-violet-600 hover:from-purple-600 hover:to-violet-700 text-white text-sm font-semibold rounded-xl transition-all mt-1"
            style={{ boxShadow: '0 4px 16px -4px rgba(139,92,246,0.5)' }}
          >
            <Plus className="w-4 h-4" /> Skill anbieten
          </Link>
        </div>
      )}

      {/* Hinweis */}
      <div className="relative bg-white border border-purple-200 rounded-2xl p-4 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #8B5CF6, #8B5CF633)' }}
        />
        <p className="text-xs text-ink-600">
          💡 <strong>Skill-Netzwerk:</strong> Biete deine Fähigkeiten an – von Handwerk bis Digital.
          Finde Mentoren oder werde selbst einer. Skills verbinden Menschen und schaffen Gemeinschaft.
        </p>
      </div>
    </div>
  )
}

export default function SkillsPage() {
  return (
    <ModulePage
      sectionLabel="§ 24 / Skills"
      mood="scholarly"
      iconBgClass="bg-purple-50 border-purple-100"
      iconColorClass="text-purple-700"
      title="Skill-Netzwerk"
      description="Fähigkeiten anbieten, voneinander lernen, Mentoring – gemeinsam wachsen"
      icon={<Wrench className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-purple-500 to-violet-600"
      postTypes={['sharing', 'rescue', 'community']}
      moduleFilter={[
        { type: 'sharing',   categories: ['skills', 'knowledge', 'general', 'mental'] },
        { type: 'rescue',    categories: ['skills', 'knowledge', 'general', 'mental'] },
        { type: 'community', categories: ['skills', 'knowledge', 'general', 'mental'] },
      ]}
      createTypes={[
        { value: 'sharing',   label: '⭐ Skill anbieten'   },
        { value: 'rescue',    label: '🔴 Skill suchen'     },
        { value: 'community', label: '🎓 Mentoring'        },
      ]}
      categories={[
        { value: 'skills',    label: '🛠️ Handwerk'         },
        { value: 'knowledge', label: '💻 Digital'           },
        { value: 'general',   label: '🎨 Kreativität'       },
        { value: 'mental',    label: '🌱 Persönlichkeit'    },
      ]}
      emptyText="Noch keine Skills geteilt"
      examplePosts={[
        { emoji: '🔨', title: 'Biete Fahrrad-Reparatur (für kleines Dankeschön)', description: 'Repariere gerne Fahrräder – von Platten bis Schaltung. Freue mich über Kuchen, Kaffee oder eine Kleinigkeit.', type: 'sharing', category: 'skills' },
        { emoji: '💻', title: 'Helfe bei PC-Problemen in der Nachbarschaft', description: 'Wenn Laptop, Drucker oder WLAN spinnen, schaue ich gerne mal drüber. Keine teuren Reparaturen, aber viele Alltagsprobleme lassen sich lösen.', type: 'sharing', category: 'knowledge' },
        { emoji: '🎨', title: 'Suche jemanden, der Gitarre beibringt', description: 'Möchte als Anfänger ein paar Akkorde lernen. Gerne gegen Tausch: biete dafür Nachhilfe in Mathe oder Englisch.', type: 'rescue', category: 'general' },
      ]}
    >
      <TopSkillsWidget />
    </ModulePage>
  )
}
