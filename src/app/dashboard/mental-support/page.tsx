'use client'

import { useState } from 'react'
import { Brain, Phone, Heart, Shield, MessageCircle, ChevronDown } from 'lucide-react'
import ModulePage from '@/components/shared/ModulePage'
import { cn } from '@/lib/utils'

// ── Verifizierte Krisenhotlines (Quellen: telefonseelsorge.de/at, 143.ch, rataufdraht.at) ──
const HOTLINES: Record<string, {
  flag: string
  label: string
  lines: {
    name: string
    number: string
    desc: string
    color: string
    dot: string
    isWeb?: boolean
    url?: string
  }[]
}> = {
  DE: {
    flag: '🇩🇪',
    label: 'Deutschland',
    lines: [
      {
        name: 'TelefonSeelsorge (evangelisch)',
        number: '0800 111 0 111',
        desc: 'Kostenlos, anonym, 24/7 – telefonseelsorge.de',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'TelefonSeelsorge (katholisch)',
        number: '0800 111 0 222',
        desc: 'Kostenlos, anonym, 24/7 – telefonseelsorge.de',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'TelefonSeelsorge (EU-Helpline)',
        number: '116 123',
        desc: 'Kostenlos, anonym, 24/7',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'Nummer gegen Kummer – Kinder & Jugend',
        number: '116 111',
        desc: 'Mo–Sa 14–20 Uhr, kostenlos – nummergegenkummer.de',
        color: 'bg-pink-50 border-pink-200 text-pink-800',
        dot: 'bg-pink-400',
      },
      {
        name: 'Elterntelefon',
        number: '0800 111 0 550',
        desc: 'Mo–Fr 9–11 & 17–19 Uhr, Di+Do bis 19 Uhr, kostenlos',
        color: 'bg-pink-50 border-pink-200 text-pink-800',
        dot: 'bg-pink-400',
      },
      {
        name: 'Hilfetelefon – Gewalt gegen Frauen',
        number: '116 016',
        desc: 'Kostenlos, anonym, 24/7, viele Sprachen – hilfetelefon.de',
        color: 'bg-rose-50 border-rose-200 text-rose-800',
        dot: 'bg-rose-400',
      },
      {
        name: 'Online-Beratung TelefonSeelsorge',
        number: 'online.telefonseelsorge.de',
        desc: 'Chat & E-Mail, kostenlos',
        color: 'bg-indigo-50 border-indigo-200 text-indigo-800',
        dot: 'bg-indigo-400',
        isWeb: true,
        url: 'https://online.telefonseelsorge.de',
      },
    ],
  },
  AT: {
    flag: '🇦🇹',
    label: 'Österreich',
    lines: [
      {
        name: 'Telefonseelsorge Österreich',
        number: '142',
        desc: 'Kostenlos, anonym, 24/7 – telefonseelsorge.at',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'Rat auf Draht – Kinder & Jugend',
        number: '147',
        desc: 'Kostenlos, anonym, 24/7 – rataufdraht.at',
        color: 'bg-pink-50 border-pink-200 text-pink-800',
        dot: 'bg-pink-400',
      },
      {
        name: 'Frauenhelpline gegen Gewalt',
        number: '0800 222 555',
        desc: 'Kostenlos, anonym, 24/7',
        color: 'bg-rose-50 border-rose-200 text-rose-800',
        dot: 'bg-rose-400',
      },
      {
        name: 'Männernotruf',
        number: '0800 400 777',
        desc: 'Kostenlos, 24/7',
        color: 'bg-indigo-50 border-indigo-200 text-indigo-800',
        dot: 'bg-indigo-400',
      },
      {
        name: 'PSD Wien – Sozialpsychiatrischer Notdienst',
        number: '01 31330',
        desc: 'Psychiatrische Krisenintervention, 24/7 – psd-wien.at',
        color: 'bg-purple-50 border-purple-200 text-purple-800',
        dot: 'bg-purple-400',
      },
      {
        name: 'Suizidprävention (Online-Chat)',
        number: 'suizid-praevention.gv.at',
        desc: 'Online-Chat, 10–22 Uhr',
        color: 'bg-teal-50 border-teal-200 text-teal-800',
        dot: 'bg-teal-400',
        isWeb: true,
        url: 'https://www.suizid-praevention.gv.at',
      },
      {
        name: 'Online-Beratung Telefonseelsorge AT',
        number: 'onlineberatung-telefonseelsorge.at',
        desc: 'Chat & E-Mail, kostenlos',
        color: 'bg-sky-50 border-sky-200 text-sky-800',
        dot: 'bg-sky-400',
        isWeb: true,
        url: 'https://onlineberatung-telefonseelsorge.at',
      },
    ],
  },
  CH: {
    flag: '🇨🇭',
    label: 'Schweiz',
    lines: [
      {
        name: 'Die Dargebotene Hand',
        number: '143',
        desc: 'Kostenlos, anonym, 24/7 – 143.ch',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'Dargebotene Hand (Englisch)',
        number: '0800 143 000',
        desc: 'English helpline, kostenlos, begrenzte Zeiten – 143.ch',
        color: 'bg-cyan-50 border-cyan-200 text-cyan-800',
        dot: 'bg-cyan-400',
      },
      {
        name: 'Kinder-/Jugendtelefon (147)',
        number: '147',
        desc: 'Kostenlos, anonym, 24/7 – 147.ch',
        color: 'bg-pink-50 border-pink-200 text-pink-800',
        dot: 'bg-pink-400',
      },
      {
        name: 'Hilfetelefon Häusliche Gewalt',
        number: '0800 040 040',
        desc: 'Kostenlos, 24/7',
        color: 'bg-rose-50 border-rose-200 text-rose-800',
        dot: 'bg-rose-400',
      },
      {
        name: 'Online-Chat Dargebotene Hand',
        number: '143.ch/chat',
        desc: 'Chat, kostenlos',
        color: 'bg-indigo-50 border-indigo-200 text-indigo-800',
        dot: 'bg-indigo-400',
        isWeb: true,
        url: 'https://www.143.ch/hilfesuchende/chat/',
      },
    ],
  },
}

// ── Krisen-Hotlines Widget ────────────────────────────────────
function CrisisHotlinesWidget() {
  const [country, setCountry] = useState<'DE' | 'AT' | 'CH'>('AT')
  const cfg = HOTLINES[country]

  return (
    <div className="space-y-4">
      {/* Wichtiger Hinweis */}
      <div className="relative bg-gradient-to-br from-cyan-50 via-cyan-50/80 to-sky-50 border border-cyan-300 rounded-2xl p-4 flex items-start gap-3 shadow-soft overflow-hidden">
        <div
          className="absolute top-0 left-0 right-0 h-[3px]"
          style={{ background: 'linear-gradient(90deg, #06B6D4, #06B6D433)' }}
        />
        <div className="bg-noise absolute inset-0 opacity-15 pointer-events-none" />
        <Shield className="relative w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5 float-idle" />
        <div className="relative">
          <p className="text-sm font-bold text-cyan-800">Du bist nicht allein 💙</p>
          <p className="text-xs text-cyan-700 mt-1">
            Dieses Modul bietet anonyme, kostenlose Hilfe. Alle Beiträge können anonym erstellt werden.
            Bei akuten Krisen wende dich bitte an die untenstehenden Hotlines.
          </p>
        </div>
      </div>

      {/* Hotlines */}
      <div className="relative bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-soft">
        <div
          className="absolute top-0 left-0 right-0 h-[3px] z-10"
          style={{ background: 'linear-gradient(90deg, #06B6D4, #06B6D433)' }}
        />
        {/* Header + Länder-Tabs */}
        <div className="px-4 pt-4 pb-3 border-b border-gray-100">
          <div className="flex items-center gap-2 mb-3">
            <Phone className="w-4 h-4 text-cyan-600 flex-shrink-0" />
            <p className="text-sm font-bold text-gray-800">Professionelle Krisenhotlines</p>
          </div>
          <div className="flex gap-2 flex-wrap">
            {(['DE', 'AT', 'CH'] as const).map(c => (
              <button
                key={c}
                onClick={() => setCountry(c)}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all border',
                  country === c
                    ? 'bg-cyan-600 text-white border-cyan-600 shadow-sm'
                    : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                )}
              >
                {HOTLINES[c].flag} {HOTLINES[c].label}
              </button>
            ))}
          </div>
        </div>

        {/* Hotlines-Liste */}
        <div className="p-4 space-y-2">
          {cfg.lines.map(h => (
            <div key={h.name} className={cn('rounded-xl border p-3', h.color)}>
              <div className="flex items-start gap-2 mb-2.5">
                <div className={cn('w-2 h-2 rounded-full flex-shrink-0 mt-1.5', h.dot)} />
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold leading-tight">{h.name}</p>
                  <p className="text-xs opacity-70 mt-0.5">{h.desc}</p>
                </div>
              </div>
              {h.isWeb ? (
                <a
                  href={h.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-2 w-full py-2.5 bg-white/80 hover:bg-white rounded-lg font-bold text-sm transition-all border border-current/10"
                >
                  <MessageCircle className="w-4 h-4" />
                  Online-Chat öffnen →
                </a>
              ) : (
                <a
                  href={`tel:${h.number.replace(/[\s\-()]/g, '')}`}
                  className="flex items-center justify-center gap-2 w-full py-2.5 bg-white/80 hover:bg-white rounded-lg font-black text-base tracking-wide transition-all border border-current/10 active:scale-95"
                >
                  <Phone className="w-4 h-4" />
                  {h.number}
                </a>
              )}
            </div>
          ))}
        </div>

        {/* Quelle */}
        <div className="px-4 py-2 border-t border-gray-50 bg-gray-50/50">
          <p className="text-xs text-gray-400">
            {country === 'DE'
              ? 'Quellen: telefonseelsorge.de, nummergegenkummer.de, hilfetelefon.de'
              : country === 'AT'
              ? 'Quellen: telefonseelsorge.at, rataufdraht.at, oesterreich.gv.at'
              : 'Quellen: 143.ch, 147.ch, ch.ch'}
          </p>
        </div>
      </div>

      {/* Feature-Kacheln */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {[
          { icon: MessageCircle, label: 'Anonym posten',    desc: 'Dein Name bleibt verborgen',          color: 'bg-cyan-50 text-cyan-700' },
          { icon: Heart,         label: 'Einfühlsam',       desc: 'Community unterstützt einander',      color: 'bg-pink-50 text-pink-700' },
          { icon: Shield,        label: 'Sicher & diskret', desc: 'Kein Druck, keine Vorwürfe',          color: 'bg-blue-50 text-blue-700' },
        ].map(f => (
          <div key={f.label} className={cn('relative p-3 rounded-2xl border border-current/10 shadow-soft hover:shadow-card transition-shadow overflow-hidden', f.color)}>
            <f.icon className="w-5 h-5 mb-1.5" />
            <p className="text-xs font-bold">{f.label}</p>
            <p className="text-xs opacity-70 mt-0.5">{f.desc}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

export default function MentalSupportPage() {
  return (
    <ModulePage
      sectionLabel="§ 25 / Mentale Unterstützung"
      mood="calm"
      iconBgClass="bg-cyan-50 border-cyan-100"
      iconColorClass="text-cyan-700"
      title="Mentale Unterstützung"
      description="Gesprächspartner, anonyme Hilfe, naturbasierte Unterstützung – du bist nicht allein"
      icon={<Brain className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-cyan-500 to-sky-600"
      postTypes={['crisis', 'rescue']}
      moduleFilter={[
        { type: 'crisis', categories: ['mental', 'general'] },    // Mentale Krisen
        { type: 'rescue', categories: ['mental', 'general'] },    // Gesprächspartner suchen
      ]}
      createTypes={[
        { value: 'crisis',  label: '💙 Unterstützung anbieten' },
        { value: 'rescue',  label: '🔴 Gesprächspartner suchen' },
      ]}
      categories={[
        { value: 'mental',  label: '💬 Gespräch'      },
        { value: 'general', label: '🌿 Anonyme Hilfe' },
        { value: 'skills',  label: '🌳 Naturbasiert'  },
      ]}
      emptyText="Noch keine Angebote für mentale Unterstützung"
      allowAnonymous={true}
    >
      <CrisisHotlinesWidget />
    </ModulePage>
  )
}
