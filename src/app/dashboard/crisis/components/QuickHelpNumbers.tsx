'use client'

import { useState, useEffect } from 'react'
import { Phone, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import type { EmergencyNumber } from '../types'

const COUNTRY_FLAGS: Record<string, string> = { DE: '🇩🇪', AT: '🇦🇹', CH: '🇨🇭' }
const COUNTRY_LABELS: Record<string, string> = { DE: 'Deutschland', AT: 'Österreich', CH: 'Schweiz' }

const CATEGORY_COLORS: Record<string, string> = {
  emergency: 'bg-mn-surface border-mn-herzrot/20 text-mn-herzrot',
  crisis: 'bg-cyan-50 border-cyan-200 text-cyan-700',
  children: 'bg-mn-surface border-white/5 text-mn-herzrot-warm',
  women: 'bg-rose-50 border-rose-200 text-rose-700',
  poison: 'bg-mn-surface border-white/8 text-mn-amber',
  other: 'bg-mn-surface border-white/5 text-mn-ink-soft',
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
            className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-mn-surface border border-mn-herzrot/20 rounded-xl text-mn-herzrot text-xs font-bold hover:bg-mn-elevated transition-colors"
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
    <div className="bg-mn-elevated border border-white/5 rounded-2xl overflow-hidden shadow-sm">
      {/* Header + Country Tabs */}
      <div className="px-4 pt-4 pb-3 border-b border-white/5">
        <div className="flex items-center gap-2 mb-3">
          <Phone className="w-4 h-4 text-mn-herzrot" />
          <p className="text-sm font-bold text-mn-ink">Notfallnummern</p>
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
                  ? 'bg-red-600 text-white border-mn-herzrot/20 shadow-sm'
                  : 'bg-mn-surface text-mn-ink-soft border-white/5 hover:bg-mn-elevated'
              )}
            >
              {COUNTRY_FLAGS[c]} {COUNTRY_LABELS[c]}
            </button>
          ))}
        </div>
      </div>

      {/* Accordion Groups */}
      <div className="divide-y divide-stone-100" role="tabpanel">
        {categories.map(cat => {
          const catNumbers = filtered.filter(n => n.category === cat)
          const catLabel = cat === 'emergency' ? 'Notruf' : cat === 'crisis' ? 'Krisen & Seelsorge' : cat === 'children' ? 'Kinder & Jugend' : cat === 'women' ? 'Frauen' : cat === 'poison' ? 'Gift' : 'Weitere'
          return (
            <div key={cat}>
              <button
                onClick={() => setOpenCategory(o => o === cat ? null : cat)}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-mn-surface transition-colors"
                aria-expanded={openCategory === cat}
              >
                <span className="text-xs font-bold text-mn-ink-soft">{catLabel}</span>
                <ChevronDown className={cn('w-3.5 h-3.5 text-mn-mute transition-transform', openCategory === cat && 'rotate-180')} />
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
