'use client'

import { useEffect, useState, useCallback } from 'react'
import { Home, Building2, Plus, AlertTriangle } from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import PostCard, { type PostCardPost } from '@/components/shared/PostCard'
import ModulePage, { type ModuleFilterRule } from '@/components/shared/ModulePage'

function HousingSplitView() {
  const [available, setAvailable] = useState<PostCardPost[]>([])
  const [wanted, setWanted]       = useState<PostCardPost[]>([])
  const [savedIds, setSavedIds]   = useState<string[]>([])
  const [userId, setUserId]       = useState<string>()
  const [loading, setLoading]     = useState(true)
  const [mobileTab, setMobileTab] = useState<'available' | 'wanted'>('available')

  const load = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      setUserId(user.id)
      const { data: saved } = await supabase.from('saved_posts').select('post_id').eq('user_id', user.id)
      setSavedIds((saved ?? []).map((s: { post_id: string }) => s.post_id))
    }
    // Nur Posts laden, die wirklich zum Wohnen-Modul gehören (housing + passende Kategorien)
    const [offersRes, requestsRes] = await Promise.all([
      supabase.from('posts').select('*, profiles(name,avatar_url)')
        .eq('status','active').eq('type','housing')
        .order('created_at',{ ascending: false }).limit(12),
      supabase.from('posts').select('*, profiles(name,avatar_url)')
        .eq('status','active').in('type',['rescue','crisis'])
        .in('category',['housing','moving','everyday','emergency'])
        .order('created_at',{ ascending: false }).limit(12),
    ])
    setAvailable(offersRes.data ?? [])
    setWanted(requestsRes.data ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  if (loading) {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {[0,1].map(i => (
          <div key={i} className="space-y-3">
            <div className="h-8 bg-gray-100 rounded-xl w-40 animate-pulse" />
            {[0,1,2].map(j => (
              <div key={j} className="bg-white rounded-2xl border border-warm-200 p-5 animate-pulse h-32" />
            ))}
          </div>
        ))}
      </div>
    )
  }

  const toggle = (id: string, s: boolean) =>
    setSavedIds(prev => s ? [...prev, id] : prev.filter(x => x !== id))

  // Pinned: urgent crisis posts (type === 'crisis')
  const urgentWanted = wanted.filter(p => p.type === 'crisis')

  return (
    <div>
      {/* Pinned: Dringende Gesuche */}
      {urgentWanted.length > 0 && (
        <div className="mb-5 p-4 bg-red-50 border-2 border-red-200 rounded-2xl">
          <div className="flex items-center gap-2 mb-3">
            <AlertTriangle className="w-4 h-4 text-red-600 flex-shrink-0" />
            <span className="text-sm font-bold text-red-800">
              {urgentWanted.length} dringend{urgentWanted.length !== 1 ? 'e' : 'es'} Wohngesuch{urgentWanted.length !== 1 ? 'e' : ''}
            </span>
            <span className="ml-auto text-xs text-red-500 bg-red-100 px-2 py-0.5 rounded-full">Sofort</span>
          </div>
          <div className="space-y-2">
            {urgentWanted.map(p => (
              <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds} compact onSaveToggle={toggle} />
            ))}
          </div>
        </div>
      )}

      {/* Mobile Tab-Switcher */}
      <div className="flex lg:hidden gap-2 mb-4">
        <button
          onClick={() => setMobileTab('available')}
          className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl font-semibold text-sm border transition-all ${
            mobileTab === 'available'
              ? 'bg-green-500 text-white border-green-500'
              : 'bg-white text-gray-600 border-gray-200'
          }`}
        >
          <Building2 className="w-4 h-4" />
          Angebote
          <span className={`text-xs px-1.5 py-0.5 rounded-full font-bold ${mobileTab === 'available' ? 'bg-white/20' : 'bg-gray-100'}`}>
            {available.length}
          </span>
        </button>
        <button
          onClick={() => setMobileTab('wanted')}
          className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl font-semibold text-sm border transition-all ${
            mobileTab === 'wanted'
              ? 'bg-red-500 text-white border-red-500'
              : 'bg-white text-gray-600 border-gray-200'
          }`}
        >
          <Home className="w-4 h-4" />
          Gesuche
          <span className={`text-xs px-1.5 py-0.5 rounded-full font-bold ${mobileTab === 'wanted' ? 'bg-white/20' : 'bg-gray-100'}`}>
            {wanted.length}
          </span>
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Wohnungen verfügbar */}
        <div className={mobileTab === 'wanted' ? 'hidden lg:block' : ''}>
          <div className="flex items-center gap-2 mb-3">
            <div className="w-7 h-7 bg-green-100 rounded-lg flex items-center justify-center">
              <Building2 className="w-4 h-4 text-green-600" />
            </div>
            <h3 className="font-bold text-gray-900">Wohnungen verfügbar</h3>
            <span className="ml-auto text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-medium">
              {available.length}
            </span>
          </div>
          {available.length === 0 ? (
            <div className="text-center py-10 bg-white rounded-2xl border border-warm-200 space-y-3">
              <Building2 className="w-10 h-10 text-gray-200 mx-auto" />
              <p className="text-sm text-gray-500 font-medium">Noch keine Wohnangebote</p>
              <p className="text-xs text-gray-400">Hast du eine Wohnung oder ein Zimmer anzubieten?</p>
              <Link
                href="/dashboard/create?type=housing"
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-green-500 hover:bg-green-600 text-white text-sm font-semibold rounded-xl transition-colors"
              >
                <Plus className="w-4 h-4" /> Wohnangebot eintragen
              </Link>
            </div>
          ) : (
            <div className="space-y-3">
              {available.map(p => (
                <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds} compact onSaveToggle={toggle} />
              ))}
          </div>
        )}
        </div>

        {/* Wohnungen gesucht */}
        <div className={mobileTab === 'available' ? 'hidden lg:block' : ''}>
          <div className="flex items-center gap-2 mb-3">
            <div className="w-7 h-7 bg-red-100 rounded-lg flex items-center justify-center">
              <Home className="w-4 h-4 text-red-600" />
            </div>
            <h3 className="font-bold text-gray-900">Wohnungen gesucht</h3>
            <span className="ml-auto text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full font-medium">
              {wanted.length}
            </span>
          </div>
          {wanted.length === 0 ? (
            <div className="text-center py-10 bg-white rounded-2xl border border-warm-200 space-y-3">
              <Home className="w-10 h-10 text-gray-200 mx-auto" />
              <p className="text-sm text-gray-500 font-medium">Noch keine Suchanfragen</p>
              <p className="text-xs text-gray-400">Suchst du selbst eine Wohnung oder Unterkunft?</p>
              <Link
                href="/dashboard/create?type=rescue"
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-red-500 hover:bg-red-600 text-white text-sm font-semibold rounded-xl transition-colors"
              >
                <Plus className="w-4 h-4" /> Wohnungssuche eintragen
              </Link>
            </div>
          ) : (
            <div className="space-y-3">
              {wanted.map(p => (
                <PostCard key={p.id} post={p} currentUserId={userId} savedIds={savedIds} compact onSaveToggle={toggle} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default function HousingPage() {
  return (
    <ModulePage
      sectionLabel="§ 22 / Wohnen"
      iconBgClass="bg-blue-50 border-blue-100"
      iconColorClass="text-blue-700"
      title="Wohnen & Alltag"
      description="Wohnungen, Notunterkünfte, Umzugshilfe, Haushaltshilfe – lokale Unterstützung"
      icon={<Home className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-blue-500 to-blue-700"
      postTypes={['housing', 'rescue', 'crisis']}
      moduleFilter={[
        { type: 'housing' },                                             // ALLE housing-Posts
        { type: 'rescue',  categories: ['housing', 'moving', 'everyday'] }, // rescue nur mit Wohn-Kategorien
        { type: 'crisis',  categories: ['housing', 'moving', 'emergency'] }, // crisis nur Wohn-Notfälle
      ]}
      createTypes={[
        { value: 'housing', label: '🏡 Wohnung anbieten' },
        { value: 'rescue',  label: '🟡 Wohnung suchen'   },
        { value: 'crisis',  label: '🚨 Notunterkunft'   },
      ]}
      categories={[
        { value: 'housing',   label: '🏠 Wohnangebot'    },
        { value: 'moving',    label: '📦 Umzug'          },
        { value: 'everyday',  label: '🧹 Haushaltshilfe' },
        { value: 'emergency', label: '🚨 Notunterkunft'  },
        { value: 'general',   label: '🌿 Sonstiges'      },
      ]}
      emptyText="Noch keine Wohn-Beiträge"
    >
      <HousingSplitView />
    </ModulePage>
  )
}
