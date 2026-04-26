'use client'

// ── LocationDisplay ───────────────────────────────────────────────────────────
// Zeigt eine lesbare Adresse statt nackter Koordinaten. In Compact-Mode nur
// Stadt/Stadtteil. Skeleton beim Laden, Klick öffnet OSM in neuem Tab.

import { MapPin, ExternalLink } from 'lucide-react'
import { useReverseGeocode } from '@/hooks/useReverseGeocode'
import { formatAddressShort, formatAddressPrivacy } from '@/lib/api/nominatim'
import { formatLatLng } from '@/lib/geo/format'

export interface LocationDisplayProps {
  lat: number
  lng: number
  /** Compact: nur Stadt / Stadtteil */
  compact?: boolean
  /** Zusätzlich Koordinaten anzeigen */
  showCoords?: boolean
  /** Klick öffnet OSM-Karte in neuem Tab */
  linkable?: boolean
  className?: string
  /** Privatsphäre-Modus: nur Stadtteil/Stadt, ohne Hausnummer */
  privacy?: boolean
}

export function LocationDisplay({
  lat,
  lng,
  compact = false,
  showCoords = false,
  linkable = false,
  className = '',
  privacy = false,
}: LocationDisplayProps) {
  const { address, isLoading, error } = useReverseGeocode(lat, lng)

  if (isLoading) {
    return (
      <span
        role="status"
        aria-label="Adresse wird geladen"
        className={`inline-flex items-center gap-1.5 ${className}`}
      >
        <MapPin aria-hidden className="h-3 w-3 text-gray-400" />
        <span className="inline-block h-3 w-24 animate-pulse rounded bg-gray-200 dark:bg-gray-700" />
      </span>
    )
  }

  let label: string
  if (error || !address) {
    label = formatLatLng(lat, lng)
  } else if (privacy) {
    label = formatAddressPrivacy(address)
  } else if (compact) {
    label = address.city ?? address.suburb ?? formatAddressShort(address)
  } else {
    label = formatAddressShort(address)
  }

  const coordsText = showCoords ? ` (${formatLatLng(lat, lng)})` : ''
  const osmUrl = `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=15/${lat}/${lng}`

  const content = (
    <>
      <MapPin aria-hidden className="h-3.5 w-3.5 flex-shrink-0 text-gray-400" />
      <span className="truncate">{label}{coordsText}</span>
      {linkable && <ExternalLink aria-hidden className="h-3 w-3 flex-shrink-0 text-gray-400" />}
    </>
  )

  if (linkable) {
    return (
      <a
        href={osmUrl}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={`Adresse auf Karte öffnen: ${label}`}
        className={`inline-flex items-center gap-1.5 text-sm text-gray-700 hover:text-primary-600 dark:text-gray-200 dark:hover:text-primary-400 ${className}`}
      >
        {content}
      </a>
    )
  }

  return (
    <span
      aria-label={`Adresse: ${label}`}
      className={`inline-flex items-center gap-1.5 text-sm text-gray-700 dark:text-gray-200 ${className}`}
    >
      {content}
    </span>
  )
}

export default LocationDisplay
