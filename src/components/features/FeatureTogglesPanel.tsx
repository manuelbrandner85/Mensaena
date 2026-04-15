'use client'

import { useState, useEffect } from 'react'
import { ToggleRight, Sparkles } from 'lucide-react'
import { FEATURE_FLAGS, useFeatureFlag, type FeatureKey } from '@/lib/feature-flags'

function FlagRow({ flagKey, label, description }: { flagKey: FeatureKey; label: string; description: string }) {
  const [enabled, setEnabled] = useFeatureFlag(flagKey)
  const [mounted, setMounted] = useState(false)
  useEffect(() => { setMounted(true) }, [])

  return (
    <li className="flex items-start justify-between gap-3 py-3 border-b border-stone-100 last:border-0">
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-gray-900">{label}</p>
        <p className="text-xs text-gray-500 mt-0.5">{description}</p>
      </div>
      <button
        onClick={() => setEnabled(!enabled)}
        className={`relative flex-shrink-0 w-11 h-6 rounded-full transition-colors ${
          mounted && enabled ? 'bg-primary-500' : 'bg-gray-300'
        }`}
        aria-pressed={mounted ? enabled : false}
        aria-label={`${label} umschalten`}
      >
        <span
          className={`absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
            mounted && enabled ? 'translate-x-5' : 'translate-x-0.5'
          }`}
        />
      </button>
    </li>
  )
}

export default function FeatureTogglesPanel() {
  const [open, setOpen] = useState(false)

  // Group flags by module for a clearer overview
  const grouped: Record<string, typeof FEATURE_FLAGS[number][]> = {}
  for (const flag of FEATURE_FLAGS) {
    if (!grouped[flag.module]) grouped[flag.module] = []
    grouped[flag.module].push(flag)
  }

  return (
    <div className="rounded-2xl border border-warm-200 bg-white shadow-soft overflow-hidden">
      <button
        onClick={() => setOpen(v => !v)}
        className="w-full flex items-center justify-between gap-3 p-5 text-left hover:bg-stone-50 transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary-50 border border-primary-100 text-primary-700 flex items-center justify-center">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-gray-900">Neue Features verwalten</h3>
            <p className="text-xs text-gray-500 mt-0.5">
              {FEATURE_FLAGS.length} Features — einzeln an- oder ausschalten
            </p>
          </div>
        </div>
        <ToggleRight className={`w-5 h-5 text-gray-400 transition-transform ${open ? 'rotate-90' : ''}`} />
      </button>

      {open && (
        <div className="border-t border-stone-100 p-5 space-y-5 bg-stone-50/50">
          {Object.entries(grouped).map(([module, flags]) => (
            <section key={module}>
              <h4 className="text-[10px] tracking-[0.14em] uppercase text-ink-400 font-semibold mb-1">
                {module}
              </h4>
              <ul>
                {flags.map(f => (
                  <FlagRow key={f.key} flagKey={f.key} label={f.label} description={f.description} />
                ))}
              </ul>
            </section>
          ))}
        </div>
      )}
    </div>
  )
}
