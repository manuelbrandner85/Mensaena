'use client'

import { useState, useEffect } from 'react'
import { Siren, Clock, TrendingUp, Phone, ChevronDown } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'
import Link from 'next/link'
import { cn } from '@/lib/utils'

// ── Verifizierte Notfallnummern (Quellen: bmi.gv.at, polizei.gv.at, ch.ch, drk.de) ──
const EMERGENCY_NUMBERS: Record<string, {
  flag: string
  label: string
  groups: { title: string; numbers: { label: string; num: string; color: string; desc?: string }[] }[]
}> = {
  DE: {
    flag: '🇩🇪',
    label: 'Deutschland',
    groups: [
      {
        title: 'Notruf',
        numbers: [
          { label: 'Notruf – Feuerwehr & Rettung', num: '112',    color: 'bg-red-50 border-red-200 text-red-700',    desc: 'EU-weit kostenlos, 24/7' },
          { label: 'Polizei',                       num: '110',    color: 'bg-blue-50 border-blue-200 text-blue-700', desc: 'Deutschlandweit kostenlos, 24/7' },
          { label: 'Ärztlicher Bereitschaftsdienst',num: '116117', color: 'bg-orange-50 border-orange-200 text-orange-700', desc: 'Nicht lebensbedrohlich, kostenlos, 24/7' },
        ],
      },
      {
        title: 'Krisen & Seelsorge',
        numbers: [
          { label: 'TelefonSeelsorge (ev.)',         num: '0800 111 0 111', color: 'bg-cyan-50 border-cyan-200 text-cyan-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'TelefonSeelsorge (kath.)',        num: '0800 111 0 222', color: 'bg-cyan-50 border-cyan-200 text-cyan-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'TelefonSeelsorge (EU-weit)',      num: '116 123',        color: 'bg-cyan-50 border-cyan-200 text-cyan-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'Kinder- & Jugendtelefon',         num: '116 111',        color: 'bg-pink-50 border-pink-200 text-pink-700',   desc: 'Mo–Sa 14–20 Uhr, kostenlos' },
          { label: 'Elterntelefon',                   num: '0800 111 0 550', color: 'bg-pink-50 border-pink-200 text-pink-700',   desc: 'Kostenlos, Mo–Fr 9–17, Di+Do bis 19 Uhr' },
          { label: 'Hilfetelefon Gewalt gg. Frauen',  num: '116 016',        color: 'bg-rose-50 border-rose-200 text-rose-700',   desc: 'Kostenlos, anonym, 24/7' },
        ],
      },
      {
        title: 'Weitere Nummern',
        numbers: [
          { label: 'Giftnotruf Berlin',               num: '030 19240',      color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: '24/7' },
          { label: 'Giftnotruf Bonn',                 num: '0228 19240',     color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: '24/7' },
          { label: 'Giftnotruf Erfurt',               num: '0361 730 730',   color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: '24/7' },
          { label: 'Krankentransport',                num: '19222',          color: 'bg-gray-50 border-gray-200 text-gray-700',       desc: 'Nicht lebensbedrohlich' },
        ],
      },
    ],
  },
  AT: {
    flag: '🇦🇹',
    label: 'Österreich',
    groups: [
      {
        title: 'Notruf',
        numbers: [
          { label: 'Rettung',                  num: '144',        color: 'bg-red-50 border-red-200 text-red-700',    desc: 'Österreichweit kostenlos, 24/7' },
          { label: 'Feuerwehr',                num: '122',        color: 'bg-orange-50 border-orange-200 text-orange-700', desc: 'Österreichweit kostenlos, 24/7' },
          { label: 'Polizei',                  num: '133',        color: 'bg-blue-50 border-blue-200 text-blue-700', desc: 'Österreichweit kostenlos, 24/7' },
          { label: 'Bergrettung',              num: '140',        color: 'bg-emerald-50 border-emerald-200 text-emerald-700', desc: 'Österreichweit kostenlos, 24/7' },
          { label: 'Euro-Notruf',              num: '112',        color: 'bg-red-50 border-red-200 text-red-700',    desc: 'EU-weit kostenlos, 24/7' },
          { label: 'Ärztenotdienst',           num: '141',        color: 'bg-orange-50 border-orange-200 text-orange-700', desc: 'Österreichweit kostenlos, 24/7' },
          { label: 'Notruf f. Gehörlose',      num: '0800 133 133', color: 'bg-gray-50 border-gray-200 text-gray-700', desc: 'Fax/SMS, kostenlos' },
        ],
      },
      {
        title: 'Krisen & Seelsorge',
        numbers: [
          { label: 'Telefonseelsorge',         num: '142',        color: 'bg-cyan-50 border-cyan-200 text-cyan-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'Rat auf Draht (Kinder)',   num: '147',        color: 'bg-pink-50 border-pink-200 text-pink-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'Frauenhelpline',           num: '0800 222 555',color: 'bg-rose-50 border-rose-200 text-rose-700',  desc: 'Gewalt gegen Frauen, kostenlos, 24/7' },
          { label: 'Männernotruf',             num: '0800 400 777',color: 'bg-indigo-50 border-indigo-200 text-indigo-700', desc: 'Kostenlos, 24/7' },
          { label: 'PSD Wien (Psychiatrie)',   num: '01 31330',   color: 'bg-purple-50 border-purple-200 text-purple-700', desc: 'Krisen-Intervention, 24/7' },
        ],
      },
      {
        title: 'Weitere Nummern',
        numbers: [
          { label: 'Vergiftungsinfo (VIZ)',    num: '01 406 43 43', color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: '24/7' },
          { label: 'Gasgebrechen',             num: '128',        color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: 'Österreichweit, 24/7' },
        ],
      },
    ],
  },
  CH: {
    flag: '🇨🇭',
    label: 'Schweiz',
    groups: [
      {
        title: 'Notruf',
        numbers: [
          { label: 'Sanität / Rettung',        num: '144',        color: 'bg-red-50 border-red-200 text-red-700',    desc: 'Schweizweit kostenlos, 24/7' },
          { label: 'Polizei',                  num: '117',        color: 'bg-blue-50 border-blue-200 text-blue-700', desc: 'Schweizweit kostenlos, 24/7' },
          { label: 'Feuerwehr',                num: '118',        color: 'bg-orange-50 border-orange-200 text-orange-700', desc: 'Schweizweit kostenlos, 24/7' },
          { label: 'Rega (Rettungshelikopter)',num: '1414',       color: 'bg-emerald-50 border-emerald-200 text-emerald-700', desc: '24/7' },
          { label: 'Euro-Notruf',              num: '112',        color: 'bg-red-50 border-red-200 text-red-700',    desc: 'EU-weit kostenlos, 24/7' },
        ],
      },
      {
        title: 'Krisen & Seelsorge',
        numbers: [
          { label: 'Die Dargebotene Hand',     num: '143',        color: 'bg-cyan-50 border-cyan-200 text-cyan-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'Kinder-/Jugendtelefon',    num: '147',        color: 'bg-pink-50 border-pink-200 text-pink-700',   desc: 'Kostenlos, anonym, 24/7' },
          { label: 'Hilfetelefon Gewalt',      num: '0800 040 040', color: 'bg-rose-50 border-rose-200 text-rose-700', desc: 'Häusliche Gewalt, kostenlos, 24/7' },
        ],
      },
      {
        title: 'Weitere Nummern',
        numbers: [
          { label: 'Tox Info Suisse (Gift)',   num: '145',        color: 'bg-yellow-50 border-yellow-200 text-yellow-700', desc: 'Vergiftungen, 24/7' },
          { label: 'REGA Pannenhilfe',         num: '+41 800 140 140', color: 'bg-gray-50 border-gray-200 text-gray-700', desc: 'Strassenhilfe, 24/7' },
        ],
      },
    ],
  },
}

// ── Aktive Notfälle Widget ───────────────────────────────────────
function ActiveCrisisWidget() {
  const [crises, setCrises] = useState<{ id: string; title: string; urgency: string; created_at: string; location_text?: string }[]>([])
  const [stats, setStats]   = useState({ critical: 0, high: 0, resolved_today: 0 })
  const [loading, setLoading] = useState(true)
  const [country, setCountry] = useState<'DE' | 'AT' | 'CH'>('AT')
  const [openGroup, setOpenGroup] = useState<string | null>('Notruf')

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const [activeRes, resolvedRes] = await Promise.all([
        supabase.from('posts').select('id,title,urgency,created_at,location_text')
          .eq('type', 'crisis').eq('status', 'active')
          .order('urgency', { ascending: false })
          .order('created_at', { ascending: false })
          .limit(5),
        supabase.from('posts').select('*', { count: 'exact', head: true })
          .eq('type', 'crisis').eq('status', 'fulfilled')
          .gte('updated_at', today.toISOString()),
      ])
      const list = activeRes.data ?? []
      setCrises(list)
      setStats({
        critical:       list.filter(p => p.urgency === 'critical').length,
        high:           list.filter(p => p.urgency === 'high').length,
        resolved_today: resolvedRes.count ?? 0,
      })
      setLoading(false)
    }
    load()
    const channel = supabase
      .channel('crisis-updates')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posts', filter: 'type=eq.crisis' }, () => load())
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [])

  const cfg = EMERGENCY_NUMBERS[country]

  return (
    <div className="space-y-4">
      {/* Live-Zähler */}
      {loading ? (
        <div className="h-24 bg-red-50 rounded-2xl animate-pulse border border-red-200" />
      ) : (
        <div className="grid grid-cols-3 gap-3">
          <div className="bg-red-100 border border-red-300 rounded-2xl p-4 text-center">
            <p className="text-3xl font-bold text-red-700">{stats.critical}</p>
            <p className="text-xs text-red-600 mt-0.5">🔴 Kritisch</p>
          </div>
          <div className="bg-orange-100 border border-orange-200 rounded-2xl p-4 text-center">
            <p className="text-3xl font-bold text-orange-700">{stats.high}</p>
            <p className="text-xs text-orange-600 mt-0.5">⚠️ Dringend</p>
          </div>
          <div className="bg-green-100 border border-green-200 rounded-2xl p-4 text-center">
            <p className="text-3xl font-bold text-green-700">{stats.resolved_today}</p>
            <p className="text-xs text-green-600 mt-0.5">✅ Heute gelöst</p>
          </div>
        </div>
      )}

      {/* Aktive Notfälle */}
      {!loading && (
        crises.length === 0 ? (
          <div className="bg-green-50 border border-green-200 rounded-2xl p-5 text-center">
            <div className="text-3xl mb-2">✅</div>
            <p className="font-semibold text-green-800">Alles ruhig – keine aktiven Notfälle!</p>
            <p className="text-xs text-green-600 mt-1">Gut so. Wenn du einen Notfall siehst, melde ihn sofort.</p>
          </div>
        ) : (
          <div className="bg-red-50 border border-red-300 rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
              <p className="text-sm font-bold text-red-800">Live – Aktive Notfälle</p>
              <span className="ml-auto text-xs bg-red-200 text-red-700 px-2 py-0.5 rounded-full">{crises.length} aktiv</span>
            </div>
            <div className="space-y-2">
              {crises.map(c => {
                const ago = (() => {
                  const diff = Date.now() - new Date(c.created_at).getTime()
                  const m = Math.floor(diff / 60000)
                  if (m < 1) return 'gerade'
                  if (m < 60) return `${m} Min.`
                  return `${Math.floor(m / 60)} Std.`
                })()
                return (
                  <Link key={c.id} href={`/dashboard/posts/${c.id}`}
                    className="flex items-center gap-3 p-2.5 bg-white rounded-xl hover:bg-red-50 transition-all border border-red-100 group">
                    <div className={`w-2 h-2 rounded-full flex-shrink-0 ${c.urgency === 'critical' ? 'bg-red-600 animate-pulse' : 'bg-orange-400'}`} />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-semibold text-gray-900 truncate group-hover:text-red-700">{c.title}</p>
                      {c.location_text && <p className="text-xs text-gray-500">📍 {c.location_text}</p>}
                    </div>
                    <div className="flex items-center gap-1 flex-shrink-0">
                      <Clock className="w-3 h-3 text-gray-400" />
                      <span className="text-xs text-gray-400">{ago}</span>
                    </div>
                  </Link>
                )
              })}
            </div>
          </div>
        )
      )}

      {/* ── Offizielle Notfallnummern ─────────────────────────── */}
      <div className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm">
        {/* Header + Länder-Tabs */}
        <div className="px-4 pt-4 pb-3 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-3">
            <Phone className="w-4 h-4 text-red-500 flex-shrink-0" />
            <p className="text-sm font-bold text-gray-800">Offizielle Notfallnummern</p>
          </div>
          <div className="flex gap-2">
            {(['DE', 'AT', 'CH'] as const).map(c => (
              <button
                key={c}
                onClick={() => { setCountry(c); setOpenGroup('Notruf') }}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all border',
                  country === c
                    ? 'bg-red-600 text-white border-red-600 shadow-sm'
                    : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                )}
              >
                {EMERGENCY_NUMBERS[c].flag} {EMERGENCY_NUMBERS[c].label}
              </button>
            ))}
          </div>
        </div>

        {/* Akkordeon-Gruppen */}
        <div className="divide-y divide-gray-50">
          {cfg.groups.map(group => (
            <div key={group.title}>
              <button
                onClick={() => setOpenGroup(g => g === group.title ? null : group.title)}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 transition-colors"
              >
                <span className="text-xs font-bold text-gray-700">{group.title}</span>
                <ChevronDown className={cn(
                  'w-3.5 h-3.5 text-gray-400 transition-transform',
                  openGroup === group.title && 'rotate-180'
                )} />
              </button>
              {openGroup === group.title && (
                <div className="px-4 pb-3 grid grid-cols-1 gap-2">
                  {group.numbers.map(h => (
                    <a
                      key={h.num}
                      href={`tel:${h.num.replace(/[\s\-()]/g, '')}`}
                      className={cn(
                        'flex items-center gap-3 p-2.5 rounded-xl border transition-all hover:scale-[1.01] active:scale-[0.99]',
                        h.color
                      )}
                    >
                      <Phone className="w-3.5 h-3.5 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-bold leading-tight">{h.label}</p>
                        {h.desc && <p className="text-xs opacity-60 mt-0.5">{h.desc}</p>}
                      </div>
                      <span className="text-sm font-black tracking-tight whitespace-nowrap">{h.num}</span>
                    </a>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Quelle */}
        <div className="px-4 py-2 border-t border-gray-50 bg-gray-50/50">
          <p className="text-xs text-gray-400">
            Quellen: {country === 'DE' ? 'drk.de, telefonseelsorge.de, 116117.de' : country === 'AT' ? 'polizei.gv.at, oesterreich.gv.at, telefonseelsorge.at' : 'ch.ch, 143.ch, sos144.ch'}
          </p>
        </div>
      </div>
    </div>
  )
}

export default function CrisisPage() {
  return (
    <ModulePage
      title="🚨 Krisensystem"
      description="Notfall-Hilfe, schnelle Helfer-Zuweisung, Essensversorgung – sofortige Hilfe"
      icon={<Siren className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-red-600 to-rose-700"
      postTypes={['crisis', 'rescue']}
      createTypes={[
        { value: 'crisis', label: '🚨 Notfall melden'   },
        { value: 'crisis', label: '🔴 Dringend Hilfe'   },
        { value: 'rescue', label: '🟢 Ich helfe sofort' },
      ]}
      categories={[
        { value: 'emergency', label: '🆘 Notfall'          },
        { value: 'food',      label: '🍎 Essensversorgung' },
        { value: 'housing',   label: '🏠 Unterkunft'       },
        { value: 'general',   label: '🌿 Sonstige Hilfe'   },
      ]}
      emptyText="Keine aktiven Notfälle – gut so!"
    >
      <ActiveCrisisWidget />
    </ModulePage>
  )
}
