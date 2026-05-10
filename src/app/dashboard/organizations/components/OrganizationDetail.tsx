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
            <tr key={day} className={cn(isToday && 'bg-mn-amber/5 font-semibold')}>
              <td className="py-1.5 pr-4 text-mn-ink-soft">{DAYS_MAP[day]}</td>
              <td className="py-1.5 text-mn-ink">
                {d?.closed ? (
                  <span className="text-mn-herzrot">Geschlossen</span>
                ) : d?.open && d?.close ? (
                  `${d.open} – ${d.close} Uhr`
                ) : (
                  <span className="text-mn-mute">–</span>
                )}
              </td>
            </tr>
          )
        })}
        {hours.notes && (
          <tr>
            <td colSpan={2} className="py-1.5 text-mn-mute italic">{hours.notes}</td>
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
        className="inline-flex items-center gap-1.5 text-sm text-mn-mute hover:text-mn-amber mb-4 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zur Übersicht
      </Link>

      {/* Header */}
      <div className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm overflow-hidden mb-4">
        {org.cover_image_url && (
          <div className="h-48 bg-gradient-to-br from-mn-amber/10 to-primary-50 overflow-hidden">
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
                <h1 className="text-xl font-bold text-mn-ink">{org.name}</h1>
                {org.is_verified && (
                  <span className="inline-flex items-center gap-1 text-xs bg-mn-elevated text-mn-leben px-2 py-1 rounded-full font-medium">
                    <ShieldCheck className="w-3.5 h-3.5" /> Verifiziert
                  </span>
                )}
                {org.is_emergency && (
                  <span className="inline-flex items-center gap-1 text-xs bg-mn-elevated text-mn-herzrot px-2 py-1 rounded-full font-medium">
                    <AlertTriangle className="w-3.5 h-3.5" /> Notfalldienst
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2 mt-2 flex-wrap">
                <OrganizationCategoryBadge category={org.category} size="md" />
                <span className="text-sm text-mn-mute">
                  {COUNTRY_FLAGS[org.country]} {COUNTRY_LABELS[org.country] || org.country}
                </span>
                {openStatus !== 'unknown' && (
                  <span className={cn(
                    'inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full',
                    openStatus === 'open' ? 'bg-mn-elevated text-mn-leben' : 'bg-mn-elevated text-mn-herzrot'
                  )}>
                    <Clock className="w-3 h-3" />
                    {openStatus === 'open' ? 'Jetzt geöffnet' : 'Momentan geschlossen'}
                  </span>
                )}
              </div>
              {org.rating_count > 0 && (
                <div className="flex items-center gap-1 mt-2" aria-label={`Bewertung: ${org.rating_avg} von 5`}>
                  {[1, 2, 3, 4, 5].map(star => (
                    <Star key={star} className={cn('w-4 h-4', star <= Math.round(org.rating_avg) ? 'text-mn-amber fill-yellow-400' : 'text-mn-ghost')} />
                  ))}
                  <span className="text-sm text-mn-ink-soft ml-1">{org.rating_avg} ({org.rating_count} Bewertungen)</span>
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
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-2">Über die Organisation</h2>
              <p className="text-sm text-mn-ink-soft leading-relaxed whitespace-pre-line">{org.description}</p>
            </section>
          )}

          {/* Services */}
          {serviceLabels.length > 0 && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3">Angebote & Leistungen</h2>
              <div className="flex flex-wrap gap-2">
                {(showAllServices ? serviceLabels : serviceLabels.slice(0, 8)).map(s => (
                  <span key={s} className="text-xs bg-mn-amber/5 text-mn-amber px-3 py-1.5 rounded-full font-medium">
                    {s}
                  </span>
                ))}
                {serviceLabels.length > 8 && !showAllServices && (
                  <button
                    onClick={() => setShowAllServices(true)}
                    className="text-xs text-mn-amber hover:text-primary-800 px-2 py-1"
                  >
                    +{serviceLabels.length - 8} weitere
                  </button>
                )}
              </div>
            </section>
          )}

          {/* Target groups */}
          {targetLabels.length > 0 && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3 flex items-center gap-2">
                <Users className="w-4 h-4 text-mn-mute" /> Zielgruppen
              </h2>
              <div className="flex flex-wrap gap-2">
                {targetLabels.map(t => (
                  <span key={t} className="text-xs bg-mn-surface text-mn-teal-soft px-3 py-1.5 rounded-full font-medium">
                    {t}
                  </span>
                ))}
              </div>
            </section>
          )}

          {/* Languages */}
          {org.languages && org.languages.length > 0 && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3 flex items-center gap-2">
                <Languages className="w-4 h-4 text-mn-mute" /> Sprachen
              </h2>
              <div className="flex flex-wrap gap-2">
                {org.languages.map(l => (
                  <span key={l} className="text-xs bg-mn-surface text-mn-amber px-3 py-1.5 rounded-full font-medium">
                    {l}
                  </span>
                ))}
              </div>
            </section>
          )}

          {/* Accessibility */}
          {accessibilityFeatures.length > 0 && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3 flex items-center gap-2">
                <Accessibility className="w-4 h-4 text-mn-mute" /> Barrierefreiheit
              </h2>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {accessibilityFeatures.map(feat => (
                  <div key={feat.key} className="flex items-center gap-2 text-sm text-mn-ink-soft">
                    <span className="text-lg">{feat.icon}</span>
                    <span>{feat.label}</span>
                  </div>
                ))}
              </div>
              {org.accessibility?.notes && (
                <p className="text-xs text-mn-mute mt-2 italic">{org.accessibility.notes}</p>
              )}
            </section>
          )}
        </div>

        {/* Sidebar (1 col) */}
        <div className="space-y-4">
          {/* Contact */}
          <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
            <h2 className="font-semibold text-mn-ink mb-3">Kontakt</h2>
            <div className="space-y-3">
              {(org.address || org.city) && (
                <a
                  href={mapsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-start gap-2 text-sm text-mn-ink-soft hover:text-mn-amber transition-colors group"
                >
                  <MapPin className="w-4 h-4 mt-0.5 text-mn-mute group-hover:text-mn-amber flex-shrink-0" />
                  <div>
                    {org.address && <p>{org.address}</p>}
                    <p>{org.zip_code} {org.city}</p>
                    <p className="text-xs text-mn-amber flex items-center gap-0.5 mt-0.5">
                      <Navigation className="w-3 h-3" /> In Maps öffnen
                    </p>
                  </div>
                </a>
              )}
              {org.phone && (
                <a href={`tel:${org.phone.replace(/\s/g, '')}`}
                   className="flex items-center gap-2 text-sm text-mn-ink-soft hover:text-mn-teal-soft transition-colors">
                  <Phone className="w-4 h-4 text-mn-mute" />
                  {org.phone}
                </a>
              )}
              {org.fax && (
                <div className="flex items-center gap-2 text-sm text-mn-mute">
                  <Printer className="w-4 h-4 text-mn-mute" />
                  Fax: {org.fax}
                </div>
              )}
              {org.email && (
                <a href={`mailto:${org.email}`}
                   className="flex items-center gap-2 text-sm text-mn-ink-soft hover:text-mn-teal-soft transition-colors">
                  <Mail className="w-4 h-4 text-mn-mute" />
                  {org.email}
                </a>
              )}
              {org.website && (
                <a href={org.website} target="_blank" rel="noopener noreferrer"
                   className="flex items-center gap-2 text-sm text-mn-ink-soft hover:text-mn-amber transition-colors">
                  <Globe className="w-4 h-4 text-mn-mute" />
                  Website besuchen
                  <ExternalLink className="w-3 h-3" />
                </a>
              )}
            </div>
          </section>

          {/* Opening hours */}
          {org.opening_hours && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3 flex items-center gap-2">
                <Clock className="w-4 h-4 text-mn-mute" /> Öffnungszeiten
              </h2>
              <OpeningHoursTable hours={org.opening_hours} />
              {org.opening_hours_text && (
                <p className="text-xs text-mn-mute mt-2">{org.opening_hours_text}</p>
              )}
            </section>
          )}

          {/* Tags */}
          {org.tags && org.tags.length > 0 && (
            <section className="bg-mn-elevated rounded-2xl border border-white/5 shadow-sm p-5">
              <h2 className="font-semibold text-mn-ink mb-3">Schlagwoerter</h2>
              <div className="flex flex-wrap gap-1.5">
                {org.tags.map(tag => (
                  <span key={tag} className="text-xs bg-mn-elevated text-mn-ink-soft px-2.5 py-1 rounded-full">{tag}</span>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>
    </div>
  )
}
