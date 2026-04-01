'use client'

import { useState, useEffect } from 'react'
import { Sprout, Calendar, MapPin, Users, Leaf, Wheat, Sun } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import ModulePage from '@/components/shared/ModulePage'

// ── Saison-Widget ─────────────────────────────────────────────
const SEASONS: Record<string, { emoji: string; crops: string[] }> = {
  'Frühling': { emoji: '🌱', crops: ['Salat', 'Radieschen', 'Spinat', 'Kohlrabi'] },
  'Sommer':   { emoji: '☀️', crops: ['Tomaten', 'Gurken', 'Zucchini', 'Beeren'] },
  'Herbst':   { emoji: '🍂', crops: ['Äpfel', 'Kartoffeln', 'Kürbis', 'Zwiebeln'] },
  'Winter':   { emoji: '❄️', crops: ['Kohl', 'Rüben', 'Lauch', 'Feldsalat'] },
}

function getSeasonNow() {
  const m = new Date().getMonth()
  if (m >= 2 && m <= 4) return 'Frühling'
  if (m >= 5 && m <= 7) return 'Sommer'
  if (m >= 8 && m <= 10) return 'Herbst'
  return 'Winter'
}

function SeasonWidget() {
  const season = getSeasonNow()
  const info = SEASONS[season]

  return (
    <div className="bg-gradient-to-br from-green-50 to-lime-50 border border-green-200 rounded-2xl p-5">
      <div className="flex items-center gap-2 mb-3">
        <Sprout className="w-5 h-5 text-green-700" />
        <h3 className="font-bold text-green-900">Aktuelle Ernte-Saison</h3>
        <span className="ml-auto text-2xl">{info.emoji}</span>
      </div>
      <p className="text-sm font-semibold text-green-800 mb-2">{season} – Was jetzt reif ist:</p>
      <div className="flex flex-wrap gap-2 mb-4">
        {info.crops.map(crop => (
          <span key={crop} className="bg-white border border-green-200 text-green-800 text-xs font-medium px-3 py-1 rounded-full">
            🌿 {crop}
          </span>
        ))}
      </div>
      <div className="bg-green-100 rounded-xl p-3 text-sm text-green-900">
        <p className="font-semibold mb-1">💡 Erntehilfe – so geht's:</p>
        <ul className="space-y-0.5 text-green-800 text-xs">
          <li>• Landwirte bieten Ernte-Tage an – du hilfst und bekommst einen Anteil</li>
          <li>• Perfekt für Selbstversorgung, Wissen und Gemeinschaft</li>
          <li>• Keine Erfahrung nötig – alle sind willkommen</li>
        </ul>
      </div>
    </div>
  )
}

// ── Erntehilfe-Regeln ─────────────────────────────────────────
function HarvestRulesWidget() {
  return (
    <div className="bg-white border border-warm-200 rounded-2xl p-5">
      <h3 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
        <Wheat className="w-5 h-5 text-yellow-600" />
        Wie funktioniert Erntehilfe?
      </h3>
      <div className="space-y-3">
        {[
          {
            step: '1',
            title: 'Betrieb findet Helfer',
            desc: 'Landwirte, Kleingärtner oder Hobbybauern inserieren einen Ernte-Einsatz mit Datum, Ort und was geerntet wird.',
            color: 'bg-green-100 text-green-700',
          },
          {
            step: '2',
            title: 'Du meldest dein Interesse',
            desc: 'Mit einem Klick auf "Interesse melden" oder direkt per WhatsApp/Telefon – unkompliziert und direkt.',
            color: 'bg-blue-100 text-blue-700',
          },
          {
            step: '3',
            title: 'Gemeinsam ernten',
            desc: 'Du verbringst ein paar Stunden auf dem Feld und bekommst als Dankeschön Ernteanteile mit nach Hause.',
            color: 'bg-amber-100 text-amber-700',
          },
        ].map((item) => (
          <div key={item.step} className="flex gap-3">
            <span className={`w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 ${item.color}`}>
              {item.step}
            </span>
            <div>
              <p className="text-sm font-semibold text-gray-800">{item.title}</p>
              <p className="text-xs text-gray-500 mt-0.5">{item.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ── Haupt-Export ──────────────────────────────────────────────
export default function HarvestPage() {
  return (
    <ModulePage
      title="Erntehilfe & Selbsternte"
      description="Helfe beim Ernten – erhalte frisches Gemüse & Obst, knüpfe Kontakte zu lokalen Bauernhöfen"
      icon={<Sprout className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-lime-600 to-green-700"
      postTypes={['supply', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'help_offer',   label: '🌾 Ernte-Einsatz anbieten' },
        { value: 'help_request', label: '🔴 Helfer gesucht'         },
        { value: 'supply',       label: '🛒 Selbsternte-Angebot'    },
      ]}
      categories={[
        { value: 'food',      label: '🍎 Obst & Gemüse'     },
        { value: 'general',   label: '🌿 Kräuter & Wildpfl.' },
        { value: 'sharing',   label: '🐝 Imkerei & Honig'   },
        { value: 'everyday',  label: '🥚 Tiere & Erzeugnisse'},
        { value: 'community', label: '👥 Gemeinschaftsgarten'},
      ]}
      emptyText="Noch keine Erntehilfe-Angebote – trag deinen Betrieb ein!"
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SeasonWidget />
        <HarvestRulesWidget />
      </div>
    </ModulePage>
  )
}
