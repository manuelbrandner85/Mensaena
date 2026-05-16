'use client'

import { Building2 } from 'lucide-react'
import type { Organization } from '../types'
import OrganizationCard from './OrganizationCard'

interface Props {
  organizations: Organization[]
  loading: boolean
  hasMore: boolean
  onLoadMore: () => void
  onShowOnMap?: (org: Organization) => void
}

export default function OrganizationsList({ organizations, loading, hasMore, onLoadMore, onShowOnMap }: Props) {
  if (!loading && organizations.length === 0) {
    return (
      <div className="text-center py-12" role="status">
        <Building2 className="w-10 h-10 text-mn-ghost mx-auto mb-3" />
        <p className="text-mn-mute font-medium">Keine Organisationen gefunden</p>
        <p className="text-mn-mute text-sm mt-1">Versuche andere Suchbegriffe oder Filter.</p>
      </div>
    )
  }

  return (
    <div>
      <div className="grid grid-cols-1 gap-3" role="list" aria-label="Hilfsorganisationen">
        {organizations.map(org => (
          <div key={org.id} role="listitem">
            <OrganizationCard org={org} onShowOnMap={onShowOnMap} />
          </div>
        ))}
      </div>

      {loading && (
        <div className="grid grid-cols-1 gap-3 mt-3">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="bg-mn-elevated rounded-2xl border border-white/5 p-4 animate-pulse">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 bg-mn-elevated rounded-xl flex-shrink-0" />
                <div className="flex-1">
                  <div className="h-4 bg-mn-elevated rounded w-3/4 mb-2" />
                  <div className="h-3 bg-mn-surface rounded w-1/2" />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {hasMore && !loading && (
        <div className="flex justify-center mt-6">
          <button
            onClick={onLoadMore}
            className="px-6 py-2.5 bg-mn-bronze/5 text-mn-bronze rounded-xl text-sm font-medium hover:bg-mn-bronze/10 transition-colors"
          >
            Mehr laden
          </button>
        </div>
      )}
    </div>
  )
}
