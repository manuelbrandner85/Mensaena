'use client'

import { useState, useEffect } from 'react'
import { Phone, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import type { EmergencyNumber } from '../types'

const COUNTRY_FLAGS: Record<string, string> = { DE: '\uD83C\uDDE9\uD83C\uDDEA', AT: '\uD83C\uDDE6\uD83C\uDDF9', CH: '\uD83C\uDDE8\uD83C\uDDED' }
const COUNTRY_LABELS: Record<string, string> = { DE: 'Deutschland', AT: '\u00d6sterreich', CH: 'Schweiz' }

const CATEGORY_COLORS: Record<string, string> = {
  emergency: 'bg-red-50 border-red-200 text-red-700',
  crisis: 'bg-cyan-50 border-cyan-200 text-cyan-700',
  children: 'bg-pink-50 border-pink-200 text-pink-700',
  women: 'bg-rose-50 border-rose-200 text-rose-700',
  poison: 'bg-yellow-50 border-yellow-200 text-yellow-700',
  other: 'bg-gray-50 border-gray-200 text-gray-700',
}

interface Props {
  compact?: boolean
}

export default function QuickHelpNumbers({ compact = false }: Props) {
  const [numbers, setNumbers] = useState<EmergencyNumber[]>([])
  const [country, setCountry] = useState<string>('DE')
  const [openCategory, setOpenCategory] = useState<string | null>('emergency')

  useEffect(() => {
    const supabase = createClient()
    supabase.from('emergency_numbers').select('*').order('country').order('sort_order')
      .then(({ data }) => { if (data) setNumbers(data) })
  }, [])

  const filtered = numbers.filter(n => n.country === country)
  const categories = [...new Set(filtered.map(n => n.category))]

  if (compact) {
    const topNumbers = filtered.filter(n => n.category === 'emergency').slice(0, 3)
    return (
      <div className="flex flex-wrap gap-2">
        {topNumbers.map(n => (
          <a
            key={n.id}
            href={`tel:${n.number.replace(/[\s\-()]/g, '')}`}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs font-bold hover:bg-red-100 transition-colors"
            aria-label={`${n.label}: ${n.number}`}
          >
            <Phone className="w-3 h-3" />
            {n.number}
          </a>
        ))}
      </div>
    )
  }

  return (
    <div className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm">
      {/* Header + Country Tabs */}
      <div className="px-4 pt-4 pb-3 border-b border-gray-100">
        <div className="flex items-center gap-2 mb-3">
          <Phone className="w-4 h-4 text-red-500" />
          <p className="text-sm font-bold text-gray-800">Notfallnummern</p>
        </div>
        <div className="flex gap-2" role="tablist" aria-label="Land auswählen">
          {['DE', 'AT', 'CH'].map(c => (
            <button
              key={c}
              onClick={() => { setCountry(c); setOpenCategory('emergency') }}
              role="tab"
              aria-selected={country === c}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all border',
                country === c
                  ? 'bg-red-600 text-white border-red-600 shadow-sm'
                  : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
              )}
            >
              {COUNTRY_FLAGS[c]} {COUNTRY_LABELS[c]}
            </button>
          ))}
        </div>
      </div>

      {/* Accordion Groups */}
      <div className="divide-y divide-gray-50" role="tabpanel">
        {categories.map(cat => {
          const catNumbers = filtered.filter(n => n.category === cat)
          const catLabel = cat === 'emergency' ? 'Notruf' : cat === 'crisis' ? 'Krisen & Seelsorge' : cat === 'children' ? 'Kinder & Jugend' : cat === 'women' ? 'Frauen' : cat === 'poison' ? 'Gift' : 'Weitere'
          return (
            <div key={cat}>
              <button
                onClick={() => setOpenCategory(o => o === cat ? null : cat)}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 transition-colors"
                aria-expanded={openCategory === cat}
              >
                <span className="text-xs font-bold text-gray-700">{catLabel}</span>
                <ChevronDown className={cn('w-3.5 h-3.5 text-gray-400 transition-transform', openCategory === cat && 'rotate-180')} />
              </button>
              {openCategory === cat && (
                <div className="px-4 pb-3 grid grid-cols-1 gap-2">
                  {catNumbers.map(n => (
                    <a
                      key={n.id}
                      href={`tel:${n.number.replace(/[\s\-()]/g, '')}`}
                      className={cn(
                        'flex items-center gap-3 p-2.5 rounded-xl border transition-all hover:scale-[1.01] active:scale-[0.99]',
                        CATEGORY_COLORS[cat] || CATEGORY_COLORS.other
                      )}
                    >
                      <Phone className="w-3.5 h-3.5 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-bold leading-tight">{n.label}</p>
                        {n.description && <p className="text-xs opacity-60 mt-0.5">{n.description}</p>}
                      </div>
                      <span className="text-sm font-black tracking-tight whitespace-nowrap">{n.number}</span>
                    </a>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
