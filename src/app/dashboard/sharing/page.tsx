'use client'

import { useState, useEffect } from 'react'
import { Shuffle, Smartphone, BookOpen, Shirt, Package2, TrendingUp } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'

// ── Teilen & Tauschen Widget ─────────────────────────────────────
function SharingStatsWidget() {
  const [catStats, setCatStats] = useState<{ label: string; count: number; icon: React.ReactNode; accent: string }[]>([])
  const [recentItems, setRecentItems] = useState<{ id: string; title: string; category: string }[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function load() {
      // Nur Teilen/Tauschen-relevante Posts (sharing-Typ mit passenden Kategorien)
      const [allRes, recentRes] = await Promise.all([
        supabase.from('posts').select('category')
          .eq('type', 'sharing')
          .in('category', ['sharing', 'everyday', 'knowledge', 'general'])
          .eq('status', 'active'),
        supabase.from('posts').select('id,title,category')
          .eq('type', 'sharing')
          .in('category', ['sharing', 'everyday', 'knowledge', 'general'])
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(4),
      ])
      if (cancelled) return
      if (allRes.error) console.error('sharing stats query failed:', allRes.error.message)
      if (recentRes.error) console.error('sharing recent query failed:', recentRes.error.message)
      const all = allRes.data ?? []
      setTotal(all.length)
      setCatStats([
        { label: 'Geräte & Elektronik', count: all.filter(p => p.category === 'sharing').length,   icon: <Smartphone className="w-4 h-4" />, accent: '#3B82F6' },
        { label: 'Kleidung',            count: all.filter(p => p.category === 'everyday').length,  icon: <Shirt className="w-4 h-4" />,       accent: '#EC4899' },
        { label: 'Bücher & Medien',     count: all.filter(p => p.category === 'knowledge').length, icon: <BookOpen className="w-4 h-4" />,    accent: '#F59E0B' },
        { label: 'Sonstiges',           count: all.filter(p => p.category === 'general').length,   icon: <Package2 className="w-4 h-4" />,    accent: '#1EAAA6' },
      ])
      setRecentItems(recentRes.data ?? [])
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="h-24 bg-teal-50 rounded-2xl animate-pulse border border-teal-200" />
  }

  const catEmoji: Record<string, string> = {
    sharing: '📱', everyday: '👕', knowledge: '📚', general: '🌿', moving: '📦'
  }

  return (
    <div className="space-y-4">
      {/* Kategorie-Übersicht */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {catStats.map(c => (
          <div
            key={c.label}
            className="relative flex flex-col items-center p-3 rounded-2xl bg-white border border-stone-100 shadow-soft hover:shadow-card transition-shadow overflow-hidden"
          >
            <div
              className="absolute top-0 left-0 right-0 h-px opacity-60"
              style={{ background: `linear-gradient(90deg, ${c.accent}66, transparent)` }}
            />
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center mb-1.5"
              style={{ background: `${c.accent}18`, color: c.accent }}
            >
              {c.icon}
            </div>
            <p className="display-numeral text-xl font-bold text-ink-900 tabular-nums">{c.count}</p>
            <p className="text-xs text-ink-500 text-center leading-tight">{c.label}</p>
          </div>
        ))}
      </div>

      {/* Aktuelle Angebote */}
      {recentItems.length > 0 && (
        <div className="relative bg-gradient-to-br from-primary-50 via-primary-50/80 to-cyan-50 border border-primary-200 rounded-2xl p-4 shadow-soft overflow-hidden">
          <div
            className="absolute top-0 left-0 right-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
          />
          <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
          <div className="relative flex items-center gap-2 mb-2">
            <TrendingUp className="w-4 h-4 text-primary-600 float-idle" />
            <p className="text-sm font-bold text-primary-800">Aktuelle Tausch-Angebote</p>
            <span className="display-numeral ml-auto text-xs bg-primary-100 text-primary-700 px-2 py-0.5 rounded-full tabular-nums">{total} gesamt</span>
          </div>
          <div className="relative flex flex-wrap gap-2">
            {recentItems.map(item => (
              <Link key={item.id} href={`/dashboard/posts/${item.id}`}
                className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white border border-primary-100 rounded-full text-xs font-medium text-primary-700 hover:bg-primary-50 transition-all shadow-soft">
                {catEmoji[item.category] ?? '🔄'} {item.title.length > 25 ? item.title.slice(0, 25) + '…' : item.title}
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Prinzip */}
      <div className="relative bg-white border border-primary-200 rounded-2xl p-4 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #1EAAA6, #1EAAA633)' }}
        />
        <p className="text-xs text-ink-600">
          🔄 <strong>Gemeinsam statt neu kaufen:</strong> Teile Geräte, die du selten nutzt.
          Tausche Bücher, Kleidung und Gegenstände. Ressourcen schonen und Nachbarn kennenlernen!
        </p>
      </div>
    </div>
  )
}

export default function SharingPage() {
  return (
    <ModulePage
      sectionLabel="§ 17 / Teilen & Tauschen"
      mood="warm"
      iconBgClass="bg-teal-50 border-teal-100"
      iconColorClass="text-teal-700"
      title="Teilen & Tauschen"
      description="Geräte teilen, Kleidung & Bücher tauschen – gemeinsam statt neu kaufen"
      icon={<Shuffle className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-teal-500 to-primary-600"
      postTypes={['sharing', 'rescue']}
      moduleFilter={[
        { type: 'sharing', categories: ['sharing', 'everyday', 'knowledge', 'general'] },  // Teilen & Tauschen
        { type: 'rescue',  categories: ['sharing', 'everyday', 'knowledge', 'general'] },  // Suche nach Gegenständen (alle Kategorien)
      ]}
      createTypes={[
        { value: 'sharing', label: '🔄 Gegenstand anbieten' },
        { value: 'rescue',  label: '🔴 Gegenstand suchen'   },
      ]}
      categories={[
        { value: 'sharing',   label: '📱 Geräte'           },
        { value: 'everyday',  label: '👕 Kleidung'         },
        { value: 'knowledge', label: '📚 Bücher'           },
        { value: 'general',   label: '🌿 Sonstiges'        },
      ]}
      emptyText="Noch keine Tausch-Angebote"
      examplePosts={[
        { emoji: '🔧', title: 'Biete Akkuschrauber zum Leihen', description: 'Habe einen Akkuschrauber (Bosch) mit Bits-Set. Könnt ihn tageweise ausleihen – einfach kurz Bescheid geben.', type: 'sharing', category: 'sharing' },
        { emoji: '📚', title: 'Verschenke Kinderbücher (2–8 Jahre)', description: 'Unsere Kinder sind rausgewachsen – zwei Kisten Bilder- und Vorlesebücher suchen ein neues Zuhause.', type: 'sharing', category: 'knowledge' },
        { emoji: '🔴', title: 'Suche Waffeleisen für Kindergeburtstag', description: 'Am Samstag feiert unsere Tochter Geburtstag und wir möchten Waffeln machen. Wer könnte uns eins leihen?', type: 'rescue', category: 'everyday' },
      ]}
    >
      <SharingStatsWidget />
    </ModulePage>
  )
}
