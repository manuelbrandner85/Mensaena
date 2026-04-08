'use client'

import { useEffect, useRef } from 'react'
import type { Organization } from '../types'
import { getCategoryConfig, COUNTRY_FLAGS } from '../types'

interface Props {
  organizations: Organization[]
  selectedOrg: Organization | null
  onOrgSelect: (org: Organization) => void
}

const CATEGORY_COLORS: Record<string, string> = {
  tierheim: '#EA580C', tierschutz: '#EF4444', suppenkueche: '#CA8A04',
  obdachlosenhilfe: '#2563EB', tafel: '#16A34A', kleiderkammer: '#9333EA',
  sozialkaufhaus: '#4F46E5', krisentelefon: '#E11D48', notschlafstelle: '#475569',
  jugend: '#0284C7', senioren: '#EC4899', behinderung: '#0891B2',
  sucht: '#D97706', fluechtlingshilfe: '#0D9488', allgemein: '#4B5563',
}

function getColor(category: string): string {
  return CATEGORY_COLORS[category] ?? '#4B5563'
}

function createSvgMarker(color: string, selected: boolean): string {
  const size = selected ? 36 : 28
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 30" width="${size}" height="${Math.round(size * 1.25)}">
    <path d="M12 0C5.373 0 0 5.373 0 12c0 9 12 18 12 18S24 21 24 12C24 5.373 18.627 0 12 0z"
      fill="${color}" stroke="white" stroke-width="${selected ? 2.5 : 1.5}" opacity="${selected ? 1 : 0.9}"/>
    <circle cx="12" cy="12" r="5" fill="white" opacity="0.9"/>
  </svg>`
}

export default function OrganizationMap({ organizations, selectedOrg, onOrgSelect }: Props) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstance = useRef<any>(null)
  const markersRef = useRef<any>(null)

  useEffect(() => {
    if (!mapRef.current) return

    const initMap = async () => {
      const L = (await import('leaflet')).default
      await import('leaflet/dist/leaflet.css')

      try {
        await import('leaflet.markercluster')
        await import('leaflet.markercluster/dist/MarkerCluster.css')
        await import('leaflet.markercluster/dist/MarkerCluster.Default.css')
      } catch {}

      if (mapInstance.current) return

      mapInstance.current = L.map(mapRef.current!, {
        center: [51.1657, 10.4515],
        zoom: 6,
        zoomControl: true,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 18,
      }).addTo(mapInstance.current)

      markersRef.current = (L as any).markerClusterGroup
        ? (L as any).markerClusterGroup({ maxClusterRadius: 50, spiderfyOnMaxZoom: true })
        : L.layerGroup()

      mapInstance.current.addLayer(markersRef.current)
    }

    initMap()

    return () => {
      if (mapInstance.current) {
        mapInstance.current.remove()
        mapInstance.current = null
      }
    }
  }, [])

  // Update markers
  useEffect(() => {
    if (!mapInstance.current || !markersRef.current) return

    const updateMarkers = async () => {
      const L = (await import('leaflet')).default
      markersRef.current.clearLayers()

      const bounds: [number, number][] = []

      organizations.forEach(org => {
        if (!org.latitude || !org.longitude) return
        const color = getColor(org.category)
        const isSelected = selectedOrg?.id === org.id
        const cat = getCategoryConfig(org.category)

        const icon = L.divIcon({
          html: createSvgMarker(color, isSelected),
          className: 'custom-marker',
          iconSize: isSelected ? [36, 45] : [28, 35],
          iconAnchor: isSelected ? [18, 45] : [14, 35],
          popupAnchor: [0, isSelected ? -45 : -35],
        })

        const marker = L.marker([org.latitude!, org.longitude!], { icon })

        marker.bindPopup(`
          <div style="min-width:180px;font-family:system-ui;">
            <p style="font-weight:600;margin:0 0 4px">${org.name}</p>
            <p style="color:#666;font-size:12px;margin:0">${cat.label} ${COUNTRY_FLAGS[org.country] || ''}</p>
            ${org.city ? `<p style="color:#888;font-size:11px;margin:2px 0 0">${org.address ? org.address + ', ' : ''}${org.city}</p>` : ''}
            ${org.phone ? `<a href="tel:${org.phone.replace(/\s/g, '')}" style="color:#059669;font-size:12px;text-decoration:none;display:block;margin-top:4px">📞 ${org.phone}</a>` : ''}
          </div>
        `)

        marker.on('click', () => onOrgSelect(org))
        markersRef.current.addLayer(marker)
        bounds.push([org.latitude!, org.longitude!])
      })

      if (bounds.length > 0 && !selectedOrg) {
        mapInstance.current.fitBounds(bounds, { padding: [40, 40], maxZoom: 12 })
      }
    }

    updateMarkers()
  }, [organizations, selectedOrg, onOrgSelect])

  // Fly to selected
  useEffect(() => {
    if (!mapInstance.current || !selectedOrg?.latitude || !selectedOrg?.longitude) return
    mapInstance.current.flyTo([selectedOrg.latitude, selectedOrg.longitude], 14, { duration: 0.8 })
  }, [selectedOrg])

  return <div ref={mapRef} className="w-full h-full" role="application" aria-label="Karte der Hilfsorganisationen" />
}
