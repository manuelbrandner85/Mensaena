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

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { icon: Star,        label: 'Skills angeboten', value: stats.offered, color: 'bg-purple-50 border-purple-200 text-purple-700', ic: 'text-purple-500' },
          { icon: TrendingUp,  label: 'Skills gesucht',   value: stats.seekers, color: 'bg-blue-50 border-blue-200 text-blue-700',       ic: 'text-blue-500'   },
          { icon: Wrench,      label: 'Mentoren aktiv',   value: stats.mentors, color: 'bg-green-50 border-green-200 text-green-700',    ic: 'text-green-500'  },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-3 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-5 h-5 mb-1 ${s.ic}`} />
            <p className="text-xl font-bold">{s.value}</p>
            <p className="text-xs text-center opacity-80">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Aktuell angebotene Skills */}
      {topSkills.length > 0 ? (
        <div className="bg-purple-50 border border-purple-200 rounded-2xl p-4">
          <p className="text-sm font-bold text-purple-800 mb-2">⭐ Aktuell verfügbare Skills</p>
          <div className="flex flex-wrap gap-2">
            {topSkills.map(s => (
              <Link key={s.id} href={`/dashboard/posts/${s.id}`}
                className="px-3 py-1.5 bg-white border border-purple-200 rounded-full text-xs font-medium text-purple-700 hover:bg-purple-100 transition-all">
                {s.title}
              </Link>
            ))}
          </div>
        </div>
      ) : (
        <div className="text-center py-8 bg-purple-50 border border-purple-200 rounded-2xl space-y-2">
          <p className="text-sm font-medium text-purple-800">Noch keine Skills geteilt</p>
          <p className="text-xs text-purple-600">Sei der Erste – teile eine Fähigkeit mit deiner Community!</p>
          <Link
            href="/dashboard/create?module=skills&type=sharing&category=skills"
            className="inline-flex items-center gap-1.5 px-4 py-2 bg-purple-500 hover:bg-purple-600 text-white text-sm font-semibold rounded-xl transition-colors mt-1"
          >
            <Plus className="w-4 h-4" /> Skill anbieten
          </Link>
        </div>
      )}

      {/* Hinweis */}
      <div className="bg-white border border-warm-200 rounded-2xl p-4">
        <p className="text-xs text-gray-600">
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
        { type: 'sharing',   categories: ['skills'] },     // Skills anbieten
        { type: 'rescue',    categories: ['skills'] },     // Skills suchen
        { type: 'community', categories: ['skills'] },     // Mentoring
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
    >
      <TopSkillsWidget />
    </ModulePage>
  )
}
