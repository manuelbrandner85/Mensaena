'use client'

import { Brain, Phone, Heart, Shield, MessageCircle } from 'lucide-react'
import ModulePage from '@/components/shared/ModulePage'

// ── Krisen-Hotlines Widget ────────────────────────────────────
function CrisisHotlinesWidget() {
  const hotlines = [
    { name: 'Telefonseelsorge', number: '142', desc: 'Kostenlos, 24/7, anonym', color: 'bg-blue-50 border-blue-200 text-blue-800', dot: 'bg-blue-400' },
    { name: 'Krisentelefon',    number: '01 406 95 95', desc: 'Wien, Mo-Fr 10-23 Uhr', color: 'bg-purple-50 border-purple-200 text-purple-800', dot: 'bg-purple-400' },
    { name: 'Rat auf Draht',    number: '147', desc: 'Kinder & Jugendliche, kostenlos 24/7', color: 'bg-pink-50 border-pink-200 text-pink-800', dot: 'bg-pink-400' },
    { name: 'Frauenhelpline',   number: '0800 222 555', desc: 'Gewalt, kostenlos 24/7', color: 'bg-rose-50 border-rose-200 text-rose-800', dot: 'bg-rose-400' },
    { name: 'Suizidpräventions-Chat', number: 'suizid-praevention.gv.at', desc: 'Online-Chat, 10-22 Uhr', color: 'bg-cyan-50 border-cyan-200 text-cyan-800', dot: 'bg-cyan-400', isWeb: true },
  ]

  return (
    <div className="space-y-4">
      {/* Wichtiger Hinweis */}
      <div className="bg-cyan-50 border border-cyan-300 rounded-2xl p-4 flex items-start gap-3">
        <Shield className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-bold text-cyan-800">Du bist nicht allein 💙</p>
          <p className="text-xs text-cyan-700 mt-1">
            Dieses Modul bietet anonyme, kostenlose Hilfe. Alle Beiträge können anonym erstellt werden.
            Bei akuten Krisen wende dich bitte an die untenstehenden Hotlines.
          </p>
        </div>
      </div>

      {/* Hotlines */}
      <div className="bg-white border border-warm-200 rounded-2xl p-4">
        <p className="text-sm font-bold text-gray-800 mb-3 flex items-center gap-1.5">
          <Phone className="w-4 h-4 text-cyan-600" /> Professionelle Krisenhotlines (AT)
        </p>
        <div className="space-y-2">
          {hotlines.map(h => (
            <div key={h.name} className={`flex items-center gap-3 p-3 rounded-xl border ${h.color}`}>
              <div className={`w-2 h-2 rounded-full flex-shrink-0 ${h.dot}`} />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-bold">{h.name}</p>
                <p className="text-xs opacity-70">{h.desc}</p>
              </div>
              {h.isWeb ? (
                <a href={`https://${h.number}`} target="_blank" rel="noopener noreferrer"
                  className="text-xs font-bold bg-white/60 px-2 py-1 rounded-lg hover:bg-white transition-all whitespace-nowrap">
                  Zum Chat →
                </a>
              ) : (
                <a href={`tel:${h.number.replace(/\s/g, '')}`}
                  className="text-xs font-bold bg-white/60 px-2 py-1 rounded-lg hover:bg-white transition-all whitespace-nowrap">
                  {h.number}
                </a>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Anonym posten – Erinnerung */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {[
          { icon: MessageCircle, label: 'Anonym posten',    desc: 'Dein Name bleibt verborgen',          color: 'bg-cyan-50 text-cyan-700' },
          { icon: Heart,         label: 'Einfühlsam',       desc: 'Community unterstützt einander',      color: 'bg-pink-50 text-pink-700' },
          { icon: Shield,        label: 'Sicher & diskret', desc: 'Kein Druck, keine Vorwürfe',          color: 'bg-blue-50 text-blue-700' },
        ].map(f => (
          <div key={f.label} className={`p-3 rounded-2xl ${f.color} border border-current/10`}>
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
      title="Mentale Unterstützung"
      description="Gesprächspartner, anonyme Hilfe, naturbasierte Unterstützung – du bist nicht allein"
      icon={<Brain className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-cyan-500 to-sky-600"
      postTypes={['mental', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'mental',       label: '💙 Unterstützung anbieten' },
        { value: 'help_request', label: '🔴 Gesprächspartner suchen' },
        { value: 'help_offer',   label: '🟢 Zuhören & Begleiten'    },
      ]}
      categories={[
        { value: 'mental',    label: '💬 Gespräch'         },
        { value: 'general',   label: '🌿 Anonyme Hilfe'    },
        { value: 'community', label: '👥 Lokale Treffen'   },
        { value: 'skills',    label: '🌳 Naturbasiert'     },
      ]}
      emptyText="Noch keine Angebote für mentale Unterstützung"
      allowAnonymous={true}
    >
      <CrisisHotlinesWidget />
    </ModulePage>
  )
}
