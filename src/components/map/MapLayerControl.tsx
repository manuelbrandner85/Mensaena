'use client'

import { useState } from 'react'
import { Layers, Loader2, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import { LAYER_GROUPS, LAYER_META, OVERPASS_LAYERS, type OverpassLayer } from '@/lib/services/overpass'

interface MapLayerControlProps {
  activeLayers: Set<OverpassLayer>
  loadingLayers: Set<OverpassLayer>
  onToggle: (layer: OverpassLayer) => void
}

export default function MapLayerControl({
  activeLayers,
  loadingLayers,
  onToggle,
}: MapLayerControlProps) {
  const [expanded, setExpanded] = useState(false)
  const activeCount = activeLayers.size

  return (
    <>
      {/* Desktop floating panel (md+) */}
      <div
        className="hidden md:block absolute top-3 right-3 z-[500] bg-white/95 backdrop-blur-md rounded-2xl shadow-lg border border-stone-200 overflow-hidden"
        style={{ maxWidth: expanded ? 240 : 180 }}
      >
        <button
          type="button"
          onClick={() => setExpanded((e) => !e)}
          className="w-full flex items-center gap-2 px-3 py-2 text-sm font-semibold text-ink-800 hover:bg-stone-50 transition-colors"
          aria-expanded={expanded}
        >
          <Layers className="w-4 h-4 text-primary-600" />
          <span className="flex-1 text-left">Ebenen</span>
          {activeCount > 0 && (
            <span className="text-xs font-bold bg-primary-100 text-primary-700 px-1.5 py-0.5 rounded-full">
              {activeCount}
            </span>
          )}
          <ChevronDown
            className={cn(
              'w-4 h-4 text-stone-400 transition-transform',
              expanded ? 'rotate-0' : '-rotate-90',
            )}
          />
        </button>

        {expanded && (
          <div className="border-t border-stone-100 py-1 max-h-[70vh] overflow-y-auto">
            {LAYER_GROUPS.map((group) => {
              const groupLayers = OVERPASS_LAYERS.filter((l) => LAYER_META[l].group === group)
              if (groupLayers.length === 0) return null
              return (
                <div key={group}>
                  <p className="px-3 pt-2.5 pb-1 text-xs font-semibold uppercase tracking-wider text-stone-400">
                    {group}
                  </p>
                  {groupLayers.map((layer) => {
                    const meta = LAYER_META[layer]
                    const active = activeLayers.has(layer)
                    const loading = loadingLayers.has(layer)
                    return (
                      <button
                        key={layer}
                        type="button"
                        onClick={() => onToggle(layer)}
                        className={cn(
                          'w-full flex items-center gap-2.5 px-3 py-2 text-sm transition-colors text-left',
                          active
                            ? 'bg-primary-50 text-primary-700 font-medium'
                            : 'text-ink-700 hover:bg-stone-50',
                        )}
                      >
                        <span
                          className={cn(
                            'w-4 h-4 rounded border-2 flex items-center justify-center flex-shrink-0 transition-colors',
                            active ? 'bg-primary-500 border-primary-500' : 'border-stone-300 bg-white',
                          )}
                        >
                          {active && !loading && (
                            <span className="text-white text-xs font-bold leading-none">✓</span>
                          )}
                          {loading && <Loader2 className="w-3 h-3 text-white animate-spin" />}
                        </span>
                        <span className="text-base leading-none" aria-hidden>
                          {meta.emoji}
                        </span>
                        <span className="flex-1 truncate">{meta.label}</span>
                      </button>
                    )
                  })}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Mobile horizontal chip strip (below md) — sits above the FABs */}
      <div className="md:hidden absolute bottom-[88px] left-0 right-0 z-[500] px-3">
        <div
          className="flex gap-2 overflow-x-auto pb-1"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          {OVERPASS_LAYERS.map((layer) => {
            const meta = LAYER_META[layer]
            const active = activeLayers.has(layer)
            const loading = loadingLayers.has(layer)
            return (
              <button
                key={layer}
                type="button"
                onClick={() => onToggle(layer)}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border whitespace-nowrap flex-shrink-0 transition-all shadow-sm',
                  active
                    ? 'text-white border-transparent'
                    : 'bg-white/90 backdrop-blur-sm text-ink-700 border-stone-200',
                )}
                style={active ? { background: meta.color, borderColor: meta.color } : undefined}
              >
                {loading ? (
                  <Loader2 className="w-3 h-3 animate-spin" />
                ) : (
                  <span className="text-sm leading-none" aria-hidden>{meta.emoji}</span>
                )}
                <span>{meta.label}</span>
              </button>
            )
          })}
        </div>
      </div>
    </>
  )
}
