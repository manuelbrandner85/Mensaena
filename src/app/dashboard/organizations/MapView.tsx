'use client'

import { useEffect, useRef } from 'react'
import type { Organization } from './types'
import { getCategoryConfig, COUNTRY_FLAGS } from './types'

interface MapViewProps {
  orgs: Organization[]
  selectedOrg: Organization | null
  onOrgSelect: (org: Organization) => void
}

// Kategorie → Marker-Farbe
const CATEGORY_COLORS: Record<string, string> = {
  tierheim:         '#EA580C',
  tierschutz:       '#EF4444',
  suppenkueche:     '#CA8A04',
  obdachlosenhilfe: '#2563EB',
  tafel:            '#16A34A',
  kleiderkammer:    '#9333EA',
  sozialkaufhaus:   '#4F46E5',
  krisentelefon:    '#E11D48',
  notschlafstelle:  '#475569',
  jugend:           '#0284C7',
  senioren:         '#EC4899',
  fluechtlingshilfe:'#0D9488',
  allgemein:        '#4B5563',
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

export default function MapView({ orgs, selectedOrg, onOrgSelect }: MapViewProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef  = useRef<any>(null)
  const markersRef      = useRef<Map<string, any>>(new Map())

  // Karte initialisieren und Marker setzen
  useEffect(() => {
    if (!mapContainerRef.current) return

    import('leaflet').then(L => {
      // Leaflet default-icon fix
      delete (L.Icon.Default.prototype as any)._getIconUrl
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
        iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
        shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
      })

      // Karte nur einmal erstellen
      if (!mapInstanceRef.current) {
        const map = L.map(mapContainerRef.current!, {
          center: [48.5, 12.5],
          zoom: 6,
          zoomControl: true,
          scrollWheelZoom: true,
        })

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>',
          maxZoom: 19,
        }).addTo(map)

        mapInstanceRef.current = map
      }

      const map = mapInstanceRef.current

      // Alle alten Marker entfernen
      markersRef.current.forEach(m => map.removeLayer(m))
      markersRef.current.clear()

      // Neue Marker
      orgs.forEach(org => {
        if (!org.latitude || !org.longitude) return

        const isSelected = selectedOrg?.id === org.id
        const color = getColor(org.category)
        const svgHtml = createSvgMarker(color, isSelected)
        const iconW = isSelected ? 36 : 28
        const iconH = isSelected ? 45 : 35

        const icon = L.divIcon({
          html: svgHtml,
          className: '',
          iconSize:   [iconW, iconH],
          iconAnchor: [iconW / 2, iconH],
          popupAnchor: [0, -iconH],
        })

        const cat = getCategoryConfig(org.category)
        const mapsUrl = `https://www.google.com/maps?q=${org.latitude},${org.longitude}`
        const osmUrl  = `https://www.openstreetmap.org/?mlat=${org.latitude}&mlon=${org.longitude}&zoom=16`

        const popupHtml = `
          <div style="min-width:220px;max-width:280px;font-family:system-ui,sans-serif;line-height:1.4">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
              <span style="background:${color};color:white;border-radius:8px;padding:3px 8px;font-size:11px;font-weight:600">${cat.label}</span>
              <span style="font-size:15px">${COUNTRY_FLAGS[org.country] ?? ''}</span>
            </div>
            <h3 style="font-weight:700;font-size:13px;margin:0 0 4px;color:#111">${org.name}</h3>
            ${org.description
              ? `<p style="font-size:11px;color:#555;margin:0 0 6px">${org.description.substring(0, 120)}${org.description.length > 120 ? '…' : ''}</p>`
              : ''}
            <div style="font-size:11px;color:#666;display:flex;flex-direction:column;gap:3px">
              <span>📍 ${org.address ? `${org.address}, ` : ''}${org.zip_code ? org.zip_code + ' ' : ''}${org.city}</span>
              ${org.phone
                ? `<a href="tel:${org.phone.replace(/\s/g,'')}" style="color:#0D9488;font-weight:600;text-decoration:none">📞 ${org.phone}</a>`
                : ''}
              ${org.opening_hours ? `<span>🕒 ${org.opening_hours}</span>` : ''}
            </div>
            <div style="margin-top:8px;display:flex;gap:6px;flex-wrap:wrap">
              ${org.website
                ? `<a href="${org.website}" target="_blank" rel="noopener" style="font-size:11px;background:#f3f4f6;color:#374151;padding:3px 9px;border-radius:20px;text-decoration:none">🌐 Website</a>`
                : ''}
              <a href="${mapsUrl}" target="_blank" rel="noopener" style="font-size:11px;background:#e0f2fe;color:#0369a1;padding:3px 9px;border-radius:20px;text-decoration:none">🗺 Google Maps</a>
              <a href="${osmUrl}" target="_blank" rel="noopener" style="font-size:11px;background:#f0fdf4;color:#166534;padding:3px 9px;border-radius:20px;text-decoration:none">🌿 OSM</a>
            </div>
          </div>`

        const marker = L.marker([org.latitude, org.longitude], { icon })
          .bindPopup(popupHtml, { maxWidth: 300, className: 'org-popup' })
          .addTo(map)

        marker.on('click', () => onOrgSelect(org))

        markersRef.current.set(org.id, marker)
      })

      // Zu ausgewählter Organisation zoomen
      if (selectedOrg?.latitude && selectedOrg?.longitude) {
        const marker = markersRef.current.get(selectedOrg.id)
        map.setView([selectedOrg.latitude, selectedOrg.longitude], 14, { animate: true })
        marker?.openPopup()
      } else if (orgs.length > 0) {
        const points = orgs
          .filter(o => o.latitude && o.longitude)
          .map(o => [o.latitude!, o.longitude!] as [number, number])
        if (points.length > 0) {
          try { map.fitBounds(points, { padding: [40, 40], maxZoom: 10 }) } catch { /* ignore */ }
        }
      }
    })
  }, [orgs, selectedOrg, onOrgSelect])

  // Karte beim Unmount aufräumen
  useEffect(() => {
    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [])

  return (
    <>
      {/* Leaflet CSS */}
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style>{`
        .org-popup .leaflet-popup-content-wrapper {
          border-radius: 12px;
          box-shadow: 0 4px 20px rgba(0,0,0,0.12);
          padding: 0;
        }
        .org-popup .leaflet-popup-content {
          margin: 12px;
        }
        .org-popup .leaflet-popup-tip {
          background: white;
        }
      `}</style>
      <div
        ref={mapContainerRef}
        style={{ width: '100%', height: '100%', background: '#e5e7eb' }}
      />
    </>
  )
}
