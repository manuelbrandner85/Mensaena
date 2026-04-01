'use client'

import { useState, useEffect } from 'react'
import { BookOpen, FileText, Lightbulb, GraduationCap } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Neueste Guides Widget ─────────────────────────────────────
function LatestGuidesWidget() {
  const [guides, setGuides] = useState<{ id: string; title: string; category: string; created_at: string }[]>([])
  const [stats, setStats]   = useState({ guides: 0, skills: 0, teaching: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const [allRes, guidesRes] = await Promise.all([
        supabase.from('posts').select('type')
          .in('type', ['knowledge', 'skill', 'help_offer']).eq('status', 'active'),
        supabase.from('posts').select('id,title,category,created_at')
          .in('type', ['knowledge', 'skill'])
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(5),
      ])
      const all = allRes.data ?? []
      setStats({
        guides:   all.filter(p => p.type === 'knowledge').length,
        skills:   all.filter(p => p.type === 'skill').length,
        teaching: all.filter(p => p.type === 'help_offer').length,
      })
      setGuides(guidesRes.data ?? [])
      setLoading(false)
    }
    load()
  }, [])

  const catEmoji: Record<string, string> = {
    knowledge: '📖', skills: '🛠️', general: '🌿', mental: '🧠'
  }

  if (loading) {
    return <div className="h-28 bg-teal-50 rounded-2xl animate-pulse border border-teal-200" />
  }

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { icon: FileText,       label: 'Guides & Wissen', value: stats.guides,   color: 'bg-teal-50 border-teal-200 text-teal-700',     ic: 'text-teal-500'     },
          { icon: GraduationCap,  label: 'Skills teilen',   value: stats.skills,   color: 'bg-emerald-50 border-emerald-200 text-emerald-700', ic: 'text-emerald-500' },
          { icon: Lightbulb,      label: 'Unterricht',      value: stats.teaching, color: 'bg-blue-50 border-blue-200 text-blue-700',       ic: 'text-blue-500'     },
        ].map(s => (
          <div key={s.label} className={`flex flex-col items-center p-3 rounded-2xl border ${s.color}`}>
            <s.icon className={`w-5 h-5 mb-1 ${s.ic}`} />
            <p className="text-xl font-bold">{s.value}</p>
            <p className="text-xs text-center opacity-80">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Neueste Guides */}
      {guides.length > 0 && (
        <div className="bg-teal-50 border border-teal-200 rounded-2xl p-4">
          <p className="text-sm font-bold text-teal-800 mb-2">📚 Neueste Einträge</p>
          <div className="space-y-1.5">
            {guides.map(g => (
              <Link key={g.id} href={`/dashboard/posts/${g.id}`}
                className="flex items-center gap-2 p-2 bg-white rounded-xl hover:bg-teal-50 transition-all border border-teal-100 group">
                <span className="text-sm flex-shrink-0">{catEmoji[g.category] ?? '📄'}</span>
                <p className="text-xs font-medium text-gray-800 truncate group-hover:text-teal-700 flex-1">{g.title}</p>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Wissens-Tipp */}
      <div className="bg-white border border-warm-200 rounded-2xl p-4">
        <p className="text-xs text-gray-600">
          💡 <strong>Wissen teilen = Gemeinschaft stärken.</strong> Teile Guides, How-Tos oder Naturwissen.
          Biete Nachhilfe, Kurse oder Mentoring an – dein Wissen ist wertvoll!
        </p>
      </div>
    </div>
  )
}

export default function KnowledgePage() {
  return (
    <ModulePage
      title="Bildung & Wissen"
      description="Guides, Tutorials, Naturwissen, Selbstversorgung – Wissen teilen und lernen"
      icon={<BookOpen className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-emerald-500 to-teal-600"
      postTypes={['knowledge', 'help_offer', 'skill']}
      createTypes={[
        { value: 'knowledge',  label: '📚 Wissen teilen'    },
        { value: 'skill',      label: '🎓 Skill anbieten'   },
        { value: 'help_offer', label: '🟢 Unterrichten'     },
      ]}
      categories={[
        { value: 'knowledge',  label: '📖 Guides'           },
        { value: 'skills',     label: '🛠️ Fähigkeiten'      },
        { value: 'general',    label: '🌿 Naturwissen'      },
        { value: 'mental',     label: '🧠 Selbstversorgung' },
      ]}
      emptyText="Noch keine Wissens-Beiträge"
    >
      <LatestGuidesWidget />
    </ModulePage>
  )
}
