'use client'

import { useState, useEffect } from 'react'
import { BookOpen, FileText, Lightbulb, GraduationCap, Plus } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'
import dynamic from 'next/dynamic'

const JobsNearbyWidget = dynamic(() => import('@/components/jobs/JobsNearbyWidget'), { ssr: false })
const EducationWidget = dynamic(() => import('@/components/education/EducationWidget'), { ssr: false })

// ── Neueste Guides Widget ─────────────────────────────────────
function LatestGuidesWidget() {
  const [guides, setGuides] = useState<{ id: string; title: string; category: string; created_at: string }[]>([])
  const [stats, setStats]   = useState({ guides: 0, skills: 0, teaching: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Nur Wissens-relevante Posts (Kategorie knowledge)
      const [allRes, guidesRes] = await Promise.all([
        supabase.from('posts').select('type')
          .in('type', ['community', 'sharing', 'rescue'])
          .eq('category', 'knowledge')
          .eq('status', 'active'),
        supabase.from('posts').select('id,title,category,created_at')
          .in('type', ['community', 'sharing', 'rescue'])
          .eq('category', 'knowledge')
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(5),
      ])
      if (cancelled) return
      if (allRes.error)    console.error('knowledge stats query failed:',   allRes.error.message)
      if (guidesRes.error) console.error('knowledge guides query failed:',  guidesRes.error.message)
      const all = allRes.data ?? []
      setStats({
        guides:   all.filter(p => p.type === 'community').length,
        skills:   all.filter(p => p.type === 'sharing').length,
        teaching: all.filter(p => p.type === 'rescue').length,
      })
      setGuides(guidesRes.data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  const catEmoji: Record<string, string> = {
    knowledge: '📖', skills: '🛠️', general: '🌿', mental: '🧠'
  }

  if (loading) {
    return <div className="h-28 bg-teal-50 rounded-2xl animate-pulse border border-teal-200" />
  }

  const cards = [
    { icon: FileText,      label: 'Guides & Wissen', value: stats.guides,   accent: '#1EAAA6' },
    { icon: GraduationCap, label: 'Skills teilen',   value: stats.skills,   accent: '#8B5CF6' },
    { icon: Lightbulb,     label: 'Unterricht',      value: stats.teaching, accent: '#3B82F6' },
  ]

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
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

      {/* Neueste Guides */}
      {guides.length > 0 ? (
        <div className="relative bg-gradient-to-br from-primary-50 via-primary-50/80 to-cyan-50 border border-primary-200 rounded-2xl p-4 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <p className="relative text-sm font-bold text-primary-800 mb-2">📚 Neueste Einträge</p>
          <div className="relative space-y-1.5">
            {guides.map(g => (
              <Link key={g.id} href={`/dashboard/posts/${g.id}`}
                className="flex items-center gap-2 p-2.5 bg-white rounded-xl hover:bg-primary-50 transition-all border border-primary-100 group shadow-soft">
                <span className="text-sm flex-shrink-0 group-hover:scale-110 transition-transform">{catEmoji[g.category] ?? '📄'}</span>
                <p className="text-xs font-medium text-ink-800 truncate group-hover:text-primary-700 flex-1">{g.title}</p>
              </Link>
            ))}
          </div>
        </div>
      ) : (
        <div className="relative text-center py-8 bg-gradient-to-br from-primary-50 to-cyan-50 border border-primary-200 rounded-2xl space-y-2 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <p className="text-sm font-medium text-primary-800">Noch keine Guides vorhanden</p>
          <p className="text-xs text-primary-600">Teile dein Wissen – Anleitungen, Tipps und Guides sind wertvoll!</p>
          <Link
            href="/dashboard/create?module=knowledge&type=community&category=knowledge"
            className="shine inline-flex items-center gap-1.5 px-4 py-2 bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-semibold rounded-xl transition-all mt-1 shadow-glow-teal"
          >
            <Plus className="w-4 h-4" /> Wissen teilen
          </Link>
        </div>
      )}

      {/* Wissens-Tipp */}
      <div className="relative bg-white border border-primary-200 rounded-2xl p-4 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
        />
        <p className="text-xs text-ink-600">
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
      moduleKey="knowledge"
      sectionLabel="§ 19 / Bildung & Wissen"
      mood="scholarly"
      iconBgClass="bg-primary-50 border-primary-100"
      iconColorClass="text-primary-700"
      title="Bildung & Wissen"
      description="Guides, Tutorials, Naturwissen, Selbstversorgung – Wissen teilen und lernen"
      icon={<BookOpen className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-primary-500 to-teal-600"
      postTypes={['community', 'sharing', 'rescue']}
      moduleFilter={[
        { type: 'community', categories: ['knowledge', 'skills', 'general', 'mental'] },
        { type: 'sharing',   categories: ['knowledge', 'skills', 'general', 'mental'] },
        { type: 'rescue',    categories: ['knowledge', 'skills', 'general', 'mental'] },
      ]}
      createTypes={[
        { value: 'community', label: '📚 Wissen teilen'    },
        { value: 'sharing',   label: '🎓 Skill anbieten'   },
        { value: 'rescue',    label: '📘 Lernpartner suchen'},
      ]}
      categories={[
        { value: 'knowledge',  label: '📖 Guides'           },
        { value: 'skills',     label: '🛠️ Fähigkeiten'      },
        { value: 'general',    label: '🌿 Naturwissen'      },
        { value: 'mental',     label: '🧠 Selbstversorgung' },
      ]}
      emptyText="Noch keine Wissens-Beiträge"
      examplePosts={[
        { emoji: '📖', title: 'Brotbacken für Anfänger – kleiner Workshop', description: 'Ich zeige euch, wie man ein einfaches Sauerteigbrot backt. Treffpunkt bei mir in der Küche, 4 Plätze.', type: 'community', category: 'knowledge' },
        { emoji: '🌱', title: 'Tipps für Tomatenanbau im Balkonkasten', description: 'Teile meine Erfahrungen und Sortenempfehlungen für den kleinen Balkon. Fragen gerne in den Kommentaren!', type: 'sharing', category: 'general' },
        { emoji: '📘', title: 'Suche Lernpartner für Spanisch (B1)', description: 'Möchte mein Spanisch auffrischen und suche jemanden zum regelmäßigen Üben – ein Kaffee pro Woche?', type: 'rescue', category: 'skills' },
      ]}
    >
      <LatestGuidesWidget />
      <div className="mt-4">
        <JobsNearbyWidget />
      </div>
      <div className="mt-4">
        <EducationWidget compact />
      </div>
    </ModulePage>
  )
}
