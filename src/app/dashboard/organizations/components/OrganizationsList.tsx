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
        <Building2 className="w-10 h-10 text-gray-300 mx-auto mb-3" />
        <p className="text-gray-500 font-medium">Keine Organisationen gefunden</p>
        <p className="text-gray-400 text-sm mt-1">Versuche andere Suchbegriffe oder Filter.</p>
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
            <div key={i} className="bg-white rounded-2xl border border-gray-100 p-4 animate-pulse">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 bg-gray-100 rounded-xl flex-shrink-0" />
                <div className="flex-1">
                  <div className="h-4 bg-gray-100 rounded w-3/4 mb-2" />
                  <div className="h-3 bg-gray-50 rounded w-1/2" />
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
            className="px-6 py-2.5 bg-primary-50 text-primary-700 rounded-xl text-sm font-medium hover:bg-primary-100 transition-colors"
          >
            Mehr laden
          </button>
        </div>
      )}
    </div>
  )
}
