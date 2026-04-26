'use client'

import { useState } from 'react'
import Link from 'next/link'
import {
  Phone, Mail, Globe, MapPin, Star, ExternalLink,
  Navigation, ChevronDown, ShieldCheck, AlertTriangle, Clock,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { getCategoryConfig, isCurrentlyOpen, COUNTRY_FLAGS } from '../types'
import type { Organization } from '../types'
import OrganizationCategoryBadge from './OrganizationCategoryBadge'

interface Props {
  org: Organization
  onShowOnMap?: (org: Organization) => void
}

export default function OrganizationCard({ org, onShowOnMap }: Props) {
  const [expanded, setExpanded] = useState(false)
  const config = getCategoryConfig(org.category)
  const Icon = config.icon
  const openStatus = isCurrentlyOpen(org.opening_hours)

  const mapsUrl = org.latitude && org.longitude
    ? `https://maps.google.com/?q=${org.latitude},${org.longitude}`
    : `https://maps.google.com/maps/search/?api=1&query=${encodeURIComponent([org.address, org.zip_code, org.city, org.country].filter(Boolean).join(' '))}`

  return (
    <div
      className={cn(
        'spotlight hover-lift relative bg-white rounded-2xl border border-stone-100 shadow-soft hover:shadow-card transition-all duration-300 overflow-hidden',
        org.is_emergency && 'ring-1 ring-red-200',
        expanded && 'shadow-card'
      )}
      role="article"
      aria-label={`Organisation: ${org.name}`}
    >
      {/* Top accent line (red for emergency, primary otherwise) */}
      <div
        className="absolute top-0 left-0 right-0 h-[3px] z-10"
        style={{
          background: org.is_emergency
            ? 'linear-gradient(90deg, #C62828, #C6282833)'
            : 'linear-gradient(90deg, #1EAAA6, #1EAAA633)',
        }}
      />
      <div className="p-4 pt-5">
        <div className="flex items-start gap-3">
          {/* Icon */}
          <div
            className={cn('w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 border', config.bg)}
            style={{ borderColor: `${org.is_emergency ? '#C62828' : '#1EAAA6'}22` }}
          >
            {org.logo_url ? (
              <img src={org.logo_url} alt="" className="w-7 h-7 rounded-lg object-cover" />
            ) : (
              <Icon className={cn('w-5 h-5', config.color)} />
            )}
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-2">
              <Link
                href={`/dashboard/organizations/${org.slug || org.id}`}
                className="font-semibold text-ink-900 text-sm leading-snug line-clamp-2 hover:text-primary-600 transition-colors"
              >
                {org.name}
              </Link>
              <div className="flex items-center gap-1 flex-shrink-0">
                {org.is_verified && (
                  <span className="text-xs bg-green-100 text-green-700 px-1.5 py-0.5 rounded-full font-medium flex items-center gap-0.5" title="Verifiziert">
                    <ShieldCheck className="w-3 h-3" />
                  </span>
                )}
                {org.is_emergency && (
                  <span className="text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full font-medium flex items-center gap-0.5" title="Notfalleinrichtung">
                    <AlertTriangle className="w-3 h-3" />
                  </span>
                )}
                <span className="text-lg leading-none">{COUNTRY_FLAGS[org.country] || ''}</span>
              </div>
            </div>

            <div className="flex items-center gap-2 mt-1 flex-wrap">
              <OrganizationCategoryBadge category={org.category} />
              <a
                href={mapsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-ink-500 flex items-center gap-0.5 hover:text-primary-600 hover:underline transition-colors"
                title="In Google Maps öffnen"
              >
                <MapPin className="w-3 h-3" />
                {org.city}{org.state ? `, ${org.state}` : ''}
                <ExternalLink className="w-2.5 h-2.5 opacity-40" />
              </a>
              {openStatus !== 'unknown' && (
                <span className={cn(
                  'text-xs flex items-center gap-0.5 font-medium',
                  openStatus === 'open' ? 'text-green-600' : 'text-red-500'
                )}>
                  <Clock className="w-3 h-3" />
                  {openStatus === 'open' ? 'Geöffnet' : 'Geschlossen'}
                </span>
              )}
              {org.distance_km != null && (
                <span className="text-xs text-ink-400">{org.distance_km} km</span>
              )}
            </div>

            {/* Rating */}
            {org.rating_count > 0 && (
              <div className="flex items-center gap-1 mt-1">
                <div className="flex items-center" aria-label={`Bewertung: ${org.rating_avg} von 5`}>
                  {[1, 2, 3, 4, 5].map(star => (
                    <Star
                      key={star}
                      className={cn(
                        'w-3 h-3',
                        star <= Math.round(org.rating_avg) ? 'text-yellow-400 fill-yellow-400' : 'text-stone-300'
                      )}
                    />
                  ))}
                </div>
                <span className="text-xs text-ink-500">
                  {org.rating_avg} ({org.rating_count})
                </span>
              </div>
            )}
          </div>
        </div>

        {(org.short_description || org.description) && (
          <p className="text-xs text-ink-600 mt-2 leading-relaxed line-clamp-2">
            {org.short_description || org.description}
          </p>
        )}

        {/* Tags */}
        {org.tags && org.tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-2">
            {org.tags.slice(0, 4).map(tag => (
              <span key={tag} className="text-xs bg-stone-50 text-ink-500 px-1.5 py-0.5 rounded-full">
                {tag}
              </span>
            ))}
            {org.tags.length > 4 && (
              <span className="text-xs text-ink-400">+{org.tags.length - 4}</span>
            )}
          </div>
        )}

        {/* Quick actions */}
        <div className="flex items-center gap-2 mt-3 flex-wrap">
          {org.phone && (
            <a
              href={`tel:${org.phone.replace(/\s/g, '')}`}
              className="flex items-center gap-1 text-xs bg-blue-50 text-blue-700 hover:bg-blue-100 px-2.5 py-1 rounded-full transition-colors font-medium"
              aria-label={`Anrufen: ${org.phone}`}
            >
              <Phone className="w-3 h-3" />
              {org.phone.replace(/\s+/g, ' ')}
            </a>
          )}
          {org.website && (
            <a
              href={org.website}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-xs bg-stone-50 text-ink-600 hover:bg-stone-100 px-2.5 py-1 rounded-full transition-colors"
            >
              <Globe className="w-3 h-3" />
              Website
              <ExternalLink className="w-2.5 h-2.5" />
            </a>
          )}
          {org.email && (
            <a
              href={`mailto:${org.email}`}
              className="flex items-center gap-1 text-xs bg-stone-50 text-ink-600 hover:bg-stone-100 px-2.5 py-1 rounded-full transition-colors"
            >
              <Mail className="w-3 h-3" />
              E-Mail
            </a>
          )}
          {onShowOnMap && org.latitude && org.longitude && (
            <button
              onClick={() => onShowOnMap(org)}
              className="flex items-center gap-1 text-xs bg-primary-50 text-primary-700 hover:bg-primary-100 px-2.5 py-1 rounded-full transition-colors"
            >
              <Navigation className="w-3 h-3" />
              Karte
            </button>
          )}
          <Link
            href={`/dashboard/organizations/${org.slug || org.id}`}
            className="flex items-center gap-1 text-xs text-primary-600 hover:text-primary-800 px-2 py-1 rounded-full ml-auto transition-colors font-medium"
          >
            Details
            <ExternalLink className="w-3 h-3" />
          </Link>
          <button
            onClick={() => setExpanded(e => !e)}
            className="flex items-center gap-1 text-xs text-ink-400 hover:text-ink-600 px-2 py-1 rounded-full transition-colors"
            aria-expanded={expanded}
            aria-label={expanded ? 'Weniger anzeigen' : 'Mehr anzeigen'}
          >
            <ChevronDown className={cn('w-3.5 h-3.5 transition-transform', expanded && 'rotate-180')} />
          </button>
        </div>
      </div>

      {/* Expanded details */}
      {expanded && (
        <div className="border-t border-stone-100 bg-stone-50/50 px-4 py-3 space-y-2">
          {(org.address || org.city) && (
            <div className="flex items-start gap-2 text-xs text-ink-600">
              <MapPin className="w-3.5 h-3.5 mt-0.5 text-ink-400 flex-shrink-0" />
              <div className="flex-1">
                {org.address
                  ? <span>{org.address}, {org.zip_code} {org.city}</span>
                  : <span>{org.city}, {org.country}</span>
                }
                <div className="flex gap-3 mt-1">
                  <a href={mapsUrl} target="_blank" rel="noopener noreferrer"
                     className="text-primary-600 hover:underline flex items-center gap-0.5">
                    <Navigation className="w-3 h-3" /> Google Maps
                  </a>
                </div>
              </div>
            </div>
          )}
          {(org.opening_hours_text || org.opening_hours?.notes) && (
            <div className="flex items-start gap-2 text-xs text-ink-600">
              <Clock className="w-3.5 h-3.5 mt-0.5 text-ink-400 flex-shrink-0" />
              <span>{org.opening_hours_text || org.opening_hours?.notes}</span>
            </div>
          )}
          {org.services && org.services.length > 0 && (
            <div className="flex flex-wrap gap-1 pt-1">
              {org.services.map(s => (
                <span key={s} className="text-xs bg-white border border-stone-200 text-ink-600 px-2 py-0.5 rounded-full">
                  {s}
                </span>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
