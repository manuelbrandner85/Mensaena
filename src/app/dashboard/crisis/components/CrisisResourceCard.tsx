'use client'

import { Package, Users, Clock, CheckCircle2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Crisis } from '../types'

interface Props {
  crisis: Crisis
  className?: string
}

export default function CrisisResourceCard({ crisis, className }: Props) {
  const hasResources = crisis.needed_resources.length > 0
  const hasSkills = crisis.needed_skills.length > 0

  if (!hasResources && !hasSkills) return null

  return (
    <div className={cn('bg-mn-elevated border border-white/5 rounded-2xl p-4 shadow-sm', className)}>
      <h4 className="text-sm font-bold text-mn-ink mb-3 flex items-center gap-2">
        <Package className="w-4 h-4 text-mn-amber" />
        Benötigte Ressourcen & Fähigkeiten
      </h4>

      {hasResources && (
        <div className="mb-3">
          <p className="text-xs font-semibold text-mn-ink-soft mb-2">Materialien:</p>
          <div className="flex flex-wrap gap-1.5">
            {crisis.needed_resources.map(r => (
              <span key={r} className="inline-flex items-center gap-1 px-2 py-0.5 bg-mn-amber/5 border border-mn-amber/20 rounded-full text-xs text-mn-amber">
                <Package className="w-3 h-3" />
                {r}
              </span>
            ))}
          </div>
        </div>
      )}

      {hasSkills && (
        <div>
          <p className="text-xs font-semibold text-mn-ink-soft mb-2">Fähigkeiten:</p>
          <div className="flex flex-wrap gap-1.5">
            {crisis.needed_skills.map(s => (
              <span key={s} className="inline-flex items-center gap-1 px-2 py-0.5 bg-mn-surface border border-white/5 rounded-full text-xs text-mn-teal-soft">
                <Users className="w-3 h-3" />
                {s}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Helper progress */}
      <div className="mt-3 pt-3 border-t border-white/5">
        <div className="flex items-center justify-between text-xs text-mn-ink-soft mb-1">
          <span className="flex items-center gap-1">
            <Users className="w-3 h-3" />
            Helfer: {crisis.helper_count} / {crisis.needed_helpers}
          </span>
          {crisis.helper_count >= crisis.needed_helpers && (
            <span className="flex items-center gap-1 text-mn-leben font-semibold">
              <CheckCircle2 className="w-3 h-3" />
              Komplett
            </span>
          )}
        </div>
        <div className="w-full h-2 bg-mn-elevated rounded-full overflow-hidden">
          <div
            className={cn(
              'h-full rounded-full transition-all duration-500',
              crisis.helper_count >= crisis.needed_helpers ? 'bg-green-500' : 'bg-mn-amber'
            )}
            style={{ width: `${Math.min(100, (crisis.helper_count / Math.max(1, crisis.needed_helpers)) * 100)}%` }}
          />
        </div>
      </div>
    </div>
  )
}
