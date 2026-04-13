'use client'

import { useState } from 'react'
import Link from 'next/link'
import {
  Phone, Mail, Globe, MapPin, Star, ExternalLink, Printer, ArrowLeft,
  ShieldCheck, AlertTriangle, Clock, Languages, Users, Accessibility,
  Navigation, ChevronDown,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  getCategoryConfig, isCurrentlyOpen, COUNTRY_FLAGS, COUNTRY_LABELS,
  DAYS_MAP, ACCESSIBILITY_OPTIONS, SERVICES_OPTIONS, TARGET_GROUPS_OPTIONS,
  type Organization, type OpeningHours,
} from '../types'
import OrganizationCategoryBadge from './OrganizationCategoryBadge'

interface Props {
  organization: Organization
}

function OpeningHoursTable({ hours }: { hours: OpeningHours }) {
  const dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as const

  return (
    <table className="w-full text-xs" aria-label="Öffnungszeiten">
      <tbody>
        {dayOrder.map(day => {
          const d = hours[day]
          const today = new Date().getDay()
          const dayIndex = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'].indexOf(day)
          const isToday = today === dayIndex
          return (
            <tr key={day} className={cn(isToday && 'bg-primary-50 font-semibold')}>
              <td className="py-1.5 pr-4 text-gray-600">{DAYS_MAP[day]}</td>
              <td className="py-1.5 text-gray-900">
                {d?.closed ? (
                  <span className="text-red-500">Geschlossen</span>
                ) : d?.open && d?.close ? (
                  `${d.open} – ${d.close} Uhr`
                ) : (
                  <span className="text-gray-400">–</span>
                )}
              </td>
            </tr>
          )
        })}
        {hours.notes && (
          <tr>
            <td colSpan={2} className="py-1.5 text-gray-500 italic">{hours.notes}</td>
          </tr>
        )}
      </tbody>
    </table>
  )
}

export default function OrganizationDetail({ organization: org }: Props) {
  const [showAllServices, setShowAllServices] = useState(false)
  const config = getCategoryConfig(org.category)
  const openStatus = isCurrentlyOpen(org.opening_hours)

  const mapsUrl = org.latitude && org.longitude
    ? `https://maps.google.com/?q=${org.latitude},${org.longitude}`
    : `https://maps.google.com/maps/search/?api=1&query=${encodeURIComponent([org.address, org.zip_code, org.city, org.country].filter(Boolean).join(' '))}`

  const accessibilityFeatures = org.accessibility
    ? ACCESSIBILITY_OPTIONS.filter(opt => (org.accessibility as Record<string, boolean>)?.[opt.key])
    : []

  const serviceLabels = org.services?.map(s => {
    const opt = SERVICES_OPTIONS.find(o => o.value === s)
    return opt?.label ?? s
  }) ?? []

  const targetLabels = org.target_groups?.map(t => {
    const opt = TARGET_GROUPS_OPTIONS.find(o => o.value === t)
    return opt?.label ?? t
  }) ?? []

  return (
    <div className="max-w-4xl mx-auto">
      {/* Back button */}
      <Link
        href="/dashboard/organizations"
        className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-primary-600 mb-4 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zur Übersicht
      </Link>

      {/* Header */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden mb-4">
        {org.cover_image_url && (
          <div className="h-48 bg-gradient-to-br from-primary-100 to-primary-50 overflow-hidden">
            <img src={org.cover_image_url} alt="" className="w-full h-full object-cover" />
          </div>
        )}
        <div className="p-5">
          <div className="flex items-start gap-4">
            <div className={cn('w-14 h-14 rounded-2xl flex items-center justify-center flex-shrink-0', config.bg)}>
              {org.logo_url ? (
                <img src={org.logo_url} alt="" className="w-10 h-10 rounded-xl object-cover" />
              ) : (
                <config.icon className={cn('w-7 h-7', config.color)} />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-start gap-2 flex-wrap">
                <h1 className="text-xl font-bold text-gray-900">{org.name}</h1>
                {org.is_verified && (
                  <span className="inline-flex items-center gap-1 text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">
                    <ShieldCheck className="w-3.5 h-3.5" /> Verifiziert
                  </span>
                )}
                {org.is_emergency && (
                  <span className="inline-flex items-center gap-1 text-xs bg-red-100 text-red-600 px-2 py-1 rounded-full font-medium">
                    <AlertTriangle className="w-3.5 h-3.5" /> Notfalldienst
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2 mt-2 flex-wrap">
                <OrganizationCategoryBadge category={org.category} size="md" />
                <span className="text-sm text-gray-500">
                  {COUNTRY_FLAGS[org.country]} {COUNTRY_LABELS[org.country] || org.country}
                </span>
                {openStatus !== 'unknown' && (
                  <span className={cn(
                    'inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full',
                    openStatus === 'open' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600'
                  )}>
                    <Clock className="w-3 h-3" />
                    {openStatus === 'open' ? 'Jetzt geöffnet' : 'Momentan geschlossen'}
                  </span>
                )}
              </div>
              {org.rating_count > 0 && (
                <div className="flex items-center gap-1 mt-2" aria-label={`Bewertung: ${org.rating_avg} von 5`}>
                  {[1, 2, 3, 4, 5].map(star => (
                    <Star key={star} className={cn('w-4 h-4', star <= Math.round(org.rating_avg) ? 'text-yellow-400 fill-yellow-400' : 'text-gray-200')} />
                  ))}
                  <span className="text-sm text-gray-600 ml-1">{org.rating_avg} ({org.rating_count} Bewertungen)</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Main content (2 cols) */}
        <div className="lg:col-span-2 space-y-4">
          {/* Description */}
          {org.description && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-2">Über die Organisation</h2>
              <p className="text-sm text-gray-600 leading-relaxed whitespace-pre-line">{org.description}</p>
            </section>
          )}

          {/* Services */}
          {serviceLabels.length > 0 && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3">Angebote & Leistungen</h2>
              <div className="flex flex-wrap gap-2">
                {(showAllServices ? serviceLabels : serviceLabels.slice(0, 8)).map(s => (
                  <span key={s} className="text-xs bg-primary-50 text-primary-700 px-3 py-1.5 rounded-full font-medium">
                    {s}
                  </span>
                ))}
                {serviceLabels.length > 8 && !showAllServices && (
                  <button
                    onClick={() => setShowAllServices(true)}
                    className="text-xs text-primary-600 hover:text-primary-800 px-2 py-1"
                  >
                    +{serviceLabels.length - 8} weitere
                  </button>
                )}
              </div>
            </section>
          )}

          {/* Target groups */}
          {targetLabels.length > 0 && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Users className="w-4 h-4 text-gray-400" /> Zielgruppen
              </h2>
              <div className="flex flex-wrap gap-2">
                {targetLabels.map(t => (
                  <span key={t} className="text-xs bg-blue-50 text-blue-700 px-3 py-1.5 rounded-full font-medium">
                    {t}
                  </span>
                ))}
              </div>
            </section>
          )}

          {/* Languages */}
          {org.languages && org.languages.length > 0 && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Languages className="w-4 h-4 text-gray-400" /> Sprachen
              </h2>
              <div className="flex flex-wrap gap-2">
                {org.languages.map(l => (
                  <span key={l} className="text-xs bg-purple-50 text-purple-700 px-3 py-1.5 rounded-full font-medium">
                    {l}
                  </span>
                ))}
              </div>
            </section>
          )}

          {/* Accessibility */}
          {accessibilityFeatures.length > 0 && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Accessibility className="w-4 h-4 text-gray-400" /> Barrierefreiheit
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {accessibilityFeatures.map(feat => (
                  <div key={feat.key} className="flex items-center gap-2 text-sm text-gray-700">
                    <span className="text-lg">{feat.icon}</span>
                    <span>{feat.label}</span>
                  </div>
                ))}
              </div>
              {org.accessibility?.notes && (
                <p className="text-xs text-gray-500 mt-2 italic">{org.accessibility.notes}</p>
              )}
            </section>
          )}
        </div>

        {/* Sidebar (1 col) */}
        <div className="space-y-4">
          {/* Contact */}
          <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
            <h2 className="font-semibold text-gray-900 mb-3">Kontakt</h2>
            <div className="space-y-3">
              {(org.address || org.city) && (
                <a
                  href={mapsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-start gap-2 text-sm text-gray-600 hover:text-primary-600 transition-colors group"
                >
                  <MapPin className="w-4 h-4 mt-0.5 text-gray-400 group-hover:text-primary-500 flex-shrink-0" />
                  <div>
                    {org.address && <p>{org.address}</p>}
                    <p>{org.zip_code} {org.city}</p>
                    <p className="text-xs text-primary-600 flex items-center gap-0.5 mt-0.5">
                      <Navigation className="w-3 h-3" /> In Maps öffnen
                    </p>
                  </div>
                </a>
              )}
              {org.phone && (
                <a href={`tel:${org.phone.replace(/\s/g, '')}`}
                   className="flex items-center gap-2 text-sm text-gray-600 hover:text-blue-600 transition-colors">
                  <Phone className="w-4 h-4 text-gray-400" />
                  {org.phone}
                </a>
              )}
              {org.fax && (
                <div className="flex items-center gap-2 text-sm text-gray-500">
                  <Printer className="w-4 h-4 text-gray-400" />
                  Fax: {org.fax}
                </div>
              )}
              {org.email && (
                <a href={`mailto:${org.email}`}
                   className="flex items-center gap-2 text-sm text-gray-600 hover:text-blue-600 transition-colors">
                  <Mail className="w-4 h-4 text-gray-400" />
                  {org.email}
                </a>
              )}
              {org.website && (
                <a href={org.website} target="_blank" rel="noopener noreferrer"
                   className="flex items-center gap-2 text-sm text-gray-600 hover:text-primary-600 transition-colors">
                  <Globe className="w-4 h-4 text-gray-400" />
                  Website besuchen
                  <ExternalLink className="w-3 h-3" />
                </a>
              )}
            </div>
          </section>

          {/* Opening hours */}
          {org.opening_hours && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                <Clock className="w-4 h-4 text-gray-400" /> Öffnungszeiten
              </h2>
              <OpeningHoursTable hours={org.opening_hours} />
              {org.opening_hours_text && (
                <p className="text-xs text-gray-500 mt-2">{org.opening_hours_text}</p>
              )}
            </section>
          )}

          {/* Tags */}
          {org.tags && org.tags.length > 0 && (
            <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
              <h2 className="font-semibold text-gray-900 mb-3">Schlagwoerter</h2>
              <div className="flex flex-wrap gap-1.5">
                {org.tags.map(tag => (
                  <span key={tag} className="text-xs bg-gray-100 text-gray-600 px-2.5 py-1 rounded-full">{tag}</span>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>
    </div>
  )
}
